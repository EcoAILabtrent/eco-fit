package uz.ecokomitet.eco_mobile;

import android.content.Context;
import android.content.SharedPreferences;
import android.hardware.Sensor;
import android.hardware.SensorEvent;
import android.hardware.SensorEventListener;
import android.hardware.SensorManager;
import android.os.Handler;
import android.os.HandlerThread;

import org.json.JSONArray;

import java.util.Calendar;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;

/**
 * Storage and math for the hardware step counter.
 *
 * TYPE_STEP_COUNTER reports a cumulative count since boot; the chip counts
 * around the clock in hardware, regardless of apps. We persist (time, counter)
 * samples and derive per-day totals from the deltas. A counter value lower
 * than the previous sample means the device rebooted — the delta after a
 * reboot is the new counter value itself.
 */
final class StepSamples {

    private static final String PREFS = "fit_step_samples";
    private static final String KEY = "samples";
    private static final long KEEP_MS = 8L * 24 * 60 * 60 * 1000;

    private StepSamples() {}

    static synchronized void add(Context ctx, long timeMs, long counter) {
        SharedPreferences sp = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE);
        JSONArray arr = load(sp);
        JSONArray out = new JSONArray();
        long cutoff = System.currentTimeMillis() - KEEP_MS;
        try {
            for (int i = 0; i < arr.length(); i++) {
                JSONArray s = arr.getJSONArray(i);
                if (s.getLong(0) >= cutoff) out.put(s);
            }
            JSONArray entry = new JSONArray();
            entry.put(timeMs);
            entry.put(counter);
            out.put(entry);
            sp.edit().putString(KEY, out.toString()).apply();
        } catch (Exception ignored) {
            // best-effort storage; a lost sample only costs a little precision
        }
    }

    /** Steps accumulated since local midnight, computed from stored samples. */
    static synchronized long todaySteps(Context ctx) {
        SharedPreferences sp = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE);
        JSONArray arr = load(sp);

        Calendar c = Calendar.getInstance();
        c.set(Calendar.HOUR_OF_DAY, 0);
        c.set(Calendar.MINUTE, 0);
        c.set(Calendar.SECOND, 0);
        c.set(Calendar.MILLISECOND, 0);
        long midnight = c.getTimeInMillis();

        long total = 0;
        long prevCounter = -1;
        long prevT = 0;
        try {
            for (int i = 0; i < arr.length(); i++) {
                JSONArray s = arr.getJSONArray(i);
                long t = s.getLong(0);
                long v = s.getLong(1);
                if (prevCounter >= 0 && t >= midnight) {
                    long d = v >= prevCounter ? v - prevCounter : v;
                    if (prevT < midnight && t > prevT && d > 0) {
                        // The delta spans midnight (Doze can block sampling for
                        // hours overnight): pro-rate it by time so yesterday's
                        // late-evening steps don't all land on today.
                        double frac = (double) (t - midnight) / (double) (t - prevT);
                        total += Math.round(d * frac);
                    } else {
                        total += d;
                    }
                }
                prevCounter = v;
                prevT = t;
            }
        } catch (Exception ignored) {}
        return total;
    }

    private static JSONArray load(SharedPreferences sp) {
        try {
            return new JSONArray(sp.getString(KEY, "[]"));
        } catch (Exception e) {
            return new JSONArray();
        }
    }

    /** One-shot blocking read of the cumulative counter (waits ≤ timeoutMs). */
    static Long readCounter(Context ctx, long timeoutMs) {
        SensorManager sm = (SensorManager) ctx.getSystemService(Context.SENSOR_SERVICE);
        if (sm == null) return null;
        Sensor sensor = sm.getDefaultSensor(Sensor.TYPE_STEP_COUNTER);
        if (sensor == null) return null;

        final long[] result = { -1 };
        final CountDownLatch latch = new CountDownLatch(1);
        SensorEventListener listener = new SensorEventListener() {
            @Override
            public void onSensorChanged(SensorEvent event) {
                result[0] = (long) event.values[0];
                latch.countDown();
            }

            @Override
            public void onAccuracyChanged(Sensor s, int accuracy) {}
        };

        HandlerThread thread = new HandlerThread("fit-step-read");
        thread.start();
        try {
            sm.registerListener(listener, sensor, SensorManager.SENSOR_DELAY_NORMAL,
                    new Handler(thread.getLooper()));
            latch.await(timeoutMs, TimeUnit.MILLISECONDS);
        } catch (Exception ignored) {
            // SecurityException when ACTIVITY_RECOGNITION is not granted (API 29+)
        } finally {
            try {
                sm.unregisterListener(listener);
            } catch (Exception ignored) {}
            thread.quitSafely();
        }
        return result[0] >= 0 ? result[0] : null;
    }

    static boolean hasSensor(Context ctx) {
        SensorManager sm = (SensorManager) ctx.getSystemService(Context.SENSOR_SERVICE);
        return sm != null && sm.getDefaultSensor(Sensor.TYPE_STEP_COUNTER) != null;
    }
}
