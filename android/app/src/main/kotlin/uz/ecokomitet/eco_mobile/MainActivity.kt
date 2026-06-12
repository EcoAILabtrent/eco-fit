package uz.ecokomitet.eco_mobile

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
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

    private var liveListener: SensorEventListener? = null
    private var lastLivePersist = 0L

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
        Executors.newSingleThreadExecutor().execute {
            val counter = StepSamples.readCounter(applicationContext, 5000)
            if (counter != null) {
                StepSamples.add(applicationContext, System.currentTimeMillis(), counter)
            }
            val today = StepSamples.todaySteps(applicationContext)
            runOnUiThread { result.success(today) }
        }
    }

    // ── Live updates while the Dart side listens (debounced to 1/s) ──

    private fun startLive(events: EventChannel.EventSink) {
        stopLive()
        if (!hasActivityPermission()) return
        val sm = getSystemService(Context.SENSOR_SERVICE) as? SensorManager ?: return
        val sensor = sm.getDefaultSensor(Sensor.TYPE_STEP_COUNTER) ?: return
        val listener = object : SensorEventListener {
            override fun onSensorChanged(event: SensorEvent) {
                val now = System.currentTimeMillis()
                if (now - lastLivePersist < 1000) return
                lastLivePersist = now
                StepSamples.add(applicationContext, now, event.values[0].toLong())
                val today = StepSamples.todaySteps(applicationContext)
                runOnUiThread { events.success(today) }
            }

            override fun onAccuracyChanged(s: Sensor?, accuracy: Int) {}
        }
        try {
            sm.registerListener(listener, sensor, SensorManager.SENSOR_DELAY_NORMAL)
            liveListener = listener
        } catch (_: Exception) {
            // SecurityException if permission revoked mid-session
        }
    }

    private fun stopLive() {
        val l = liveListener ?: return
        val sm = getSystemService(Context.SENSOR_SERVICE) as? SensorManager
        try {
            sm?.unregisterListener(l)
        } catch (_: Exception) {}
        liveListener = null
    }

    override fun onDestroy() {
        stopLive()
        super.onDestroy()
    }
}
