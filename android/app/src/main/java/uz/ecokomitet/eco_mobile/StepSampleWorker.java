package uz.ecokomitet.eco_mobile;

import android.content.Context;

import androidx.annotation.NonNull;
import androidx.work.ExistingPeriodicWorkPolicy;
import androidx.work.ExistingWorkPolicy;
import androidx.work.OneTimeWorkRequest;
import androidx.work.PeriodicWorkRequest;
import androidx.work.WorkManager;
import androidx.work.Worker;
import androidx.work.WorkerParameters;

import java.util.concurrent.TimeUnit;

/**
 * Background sampler — records the cumulative hardware step counter so day
 * boundaries stay accurate even while the app is closed. The hardware chip
 * itself counts continuously; we only need checkpoints to split its
 * cumulative value into days.
 *
 * Scheduled periodically (15 min) from the plugin, and once immediately after
 * boot (see BootReceiver) so the post-reboot baseline is captured early.
 */
public  class StepSampleWorker extends Worker {

    public StepSampleWorker(@NonNull Context context, @NonNull WorkerParameters params) {
        super(context, params);
    }

    @NonNull
    @Override
    public Result doWork() {
        Long counter = StepSamples.readCounter(getApplicationContext(), 5000);
        if (counter != null) {
            StepSamples.add(getApplicationContext(), System.currentTimeMillis(), counter);
        }
        // Piggyback the step-goal notification rules on the same 15-min tick —
        // the only reminder evaluated with the app fully closed.
        StepNotifier.maybeNotify(getApplicationContext());
        return Result.success();
    }

    /** Keep the periodic 15-minute sampling registered. */
    public static void schedule(Context context) {
        PeriodicWorkRequest req =
            new PeriodicWorkRequest.Builder(StepSampleWorker.class, 15, TimeUnit.MINUTES).build();
        WorkManager.getInstance(context)
            .enqueueUniquePeriodicWork("fit-step-sampler", ExistingPeriodicWorkPolicy.KEEP, req);
    }

    /** Take a single sample as soon as possible (e.g. right after boot). */
    public static void scheduleOnce(Context context) {
        OneTimeWorkRequest req = new OneTimeWorkRequest.Builder(StepSampleWorker.class).build();
        WorkManager.getInstance(context)
            .enqueueUniqueWork("fit-step-sample-once", ExistingWorkPolicy.REPLACE, req);
    }
}
