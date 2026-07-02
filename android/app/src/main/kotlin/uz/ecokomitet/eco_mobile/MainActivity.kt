package uz.ecokomitet.eco_mobile

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Build
import android.os.Handler
import android.os.HandlerThread
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

/**
 * Independent pedometer bridge — exposes the proven StepSamples engine
 * (hardware TYPE_STEP_COUNTER + WorkManager checkpoints + BootReceiver,
 * ported from the Capacitor app) to Flutter.
 *
 * Deliberately NO "max realistic delta" cap (a StepsShare bug): a large
 * counter jump after the app slept is real steps recorded by the chip, and
 * the checkpoint-replay model attributes it to the correct day.
 */
class MainActivity : FlutterActivity() {

    private val permissionRequestCode = 7311
    private var pendingPermissionResult: MethodChannel.Result? = null

    // Reused for every off-UI method-channel job (was re-created per call).
    private val ioExecutor: ExecutorService = Executors.newSingleThreadExecutor()

    private var liveListener: SensorEventListener? = null
    private var liveThread: HandlerThread? = null
    // In-memory baseline so the live UI value avoids a JSON parse per event:
    // last persisted todaySteps plus the raw-counter delta since that persist.
    private var lastLivePersist = 0L
    private var liveBaseCounter = -1L
    private var liveBaseToday = 0L

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        StepSampleWorker.schedule(applicationContext)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "eco/steps")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isAvailable" -> result.success(StepSamples.hasSensor(applicationContext))
                    "checkPermission" -> result.success(hasActivityPermission())
                    "requestPermission" -> requestActivityPermission(result)
                    "getTodaySteps" -> getTodaySteps(result)
                    "getStepsForDay" -> getStepsForDay(call.arguments, result)
                    // Dart mirrors notification config here on every replan so
                    // StepNotifier works with the Flutter engine dead.
                    "configureStepNotifications" -> {
                        configureStepNotifications(call.arguments as? Map<*, *>)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "eco/steps/live")
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(args: Any?, events: EventChannel.EventSink) {
                    startLive(events)
                }

                override fun onCancel(args: Any?) {
                    stopLive()
                }
            })
    }

    private fun configureStepNotifications(args: Map<*, *>?) {
        if (args == null) return
        StepNotifier.configure(
            applicationContext,
            args["enabled"] as? Boolean ?: false,
            (args["goal"] as? Number)?.toLong() ?: 0L,
            args["channelName"] as? String ?: "",
            args["channelDesc"] as? String ?: "",
            args["celebrationTitle"] as? String ?: "",
            args["celebrationBody"] as? String ?: "",
            args["nudgeTitle"] as? String ?: "",
            args["nudgeBody"] as? String ?: "",
        )
    }

    private fun hasActivityPermission(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return true
        return ContextCompat.checkSelfPermission(
            this, Manifest.permission.ACTIVITY_RECOGNITION
        ) == PackageManager.PERMISSION_GRANTED
    }

    private fun requestActivityPermission(result: MethodChannel.Result) {
        if (hasActivityPermission()) {
            result.success(true)
            return
        }
        // A system dialog from an earlier call is still open: overwriting the
        // pending Result would strand its Dart Future forever. Answer this new
        // call with the current status and leave the first one to complete.
        if (pendingPermissionResult != null) {
            result.success(hasActivityPermission())
            return
        }
        pendingPermissionResult = result
        ActivityCompat.requestPermissions(
            this, arrayOf(Manifest.permission.ACTIVITY_RECOGNITION), permissionRequestCode
        )
    }

    override fun onRequestPermissionsResult(
        requestCode: Int, permissions: Array<out String>, grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == permissionRequestCode) {
            pendingPermissionResult?.success(hasActivityPermission())
            pendingPermissionResult = null
        }
    }

    private fun getTodaySteps(result: MethodChannel.Result) {
        if (!hasActivityPermission()) {
            result.success(null)
            return
        }
        ioExecutor.execute {
            val counter = StepSamples.readCounter(applicationContext, 5000)
            if (counter != null) {
                StepSamples.add(applicationContext, System.currentTimeMillis(), counter)
            }
            val today = StepSamples.todaySteps(applicationContext)
            runOnUiThread { result.success(today) }
        }
    }

    /** Backfill bridge: steps recorded on the local day starting at [args] ms. */
    private fun getStepsForDay(args: Any?, result: MethodChannel.Result) {
        val dayStart = (args as? Number)?.toLong()
        if (dayStart == null || !hasActivityPermission()) {
            result.success(null)
            return
        }
        ioExecutor.execute {
            val dayEnd = dayStart + 24L * 60 * 60 * 1000
            val steps = StepSamples.stepsForRange(applicationContext, dayStart, dayEnd)
            runOnUiThread { result.success(steps) }
        }
    }

    // ── Live updates while the Dart side listens ──

    // Persist a checkpoint no more than once per this window; between
    // checkpoints the UI value is derived in memory from the counter delta.
    private val livePersistMs = 30_000L

    private fun startLive(events: EventChannel.EventSink) {
        stopLive()
        if (!hasActivityPermission()) return
        val sm = getSystemService(Context.SENSOR_SERVICE) as? SensorManager ?: return
        val sensor = sm.getDefaultSensor(Sensor.TYPE_STEP_COUNTER) ?: return
        // First event seeds the baseline; force it with a zeroed state.
        lastLivePersist = 0L
        liveBaseCounter = -1L
        liveBaseToday = 0L
        val thread = HandlerThread("eco-step-live").apply { start() }
        val listener = object : SensorEventListener {
            // Runs on the HandlerThread — the JSON work stays off the UI thread.
            override fun onSensorChanged(event: SensorEvent) {
                val now = System.currentTimeMillis()
                val counter = event.values[0].toLong()
                val today: Long
                if (liveBaseCounter < 0 || now - lastLivePersist >= livePersistMs) {
                    // Checkpoint: persist and recompute the authoritative total
                    // (handles midnight/reboot), then reset the in-memory base.
                    StepSamples.add(applicationContext, now, counter)
                    today = StepSamples.todaySteps(applicationContext)
                    lastLivePersist = now
                    liveBaseCounter = counter
                    liveBaseToday = today
                } else {
                    // Between checkpoints: cheap delta, no SharedPreferences read.
                    val delta = if (counter >= liveBaseCounter) counter - liveBaseCounter else 0
                    today = liveBaseToday + delta
                }
                runOnUiThread { events.success(today) }
            }

            override fun onAccuracyChanged(s: Sensor?, accuracy: Int) {}
        }
        try {
            sm.registerListener(
                listener, sensor, SensorManager.SENSOR_DELAY_NORMAL, Handler(thread.looper)
            )
            liveListener = listener
            liveThread = thread
        } catch (_: Exception) {
            // SecurityException if permission revoked mid-session
            thread.quitSafely()
        }
    }

    private fun stopLive() {
        val l = liveListener
        if (l != null) {
            val sm = getSystemService(Context.SENSOR_SERVICE) as? SensorManager
            try {
                sm?.unregisterListener(l)
            } catch (_: Exception) {}
            liveListener = null
        }
        liveThread?.quitSafely()
        liveThread = null
    }

    override fun onDestroy() {
        stopLive()
        ioExecutor.shutdown()
        super.onDestroy()
    }
}
