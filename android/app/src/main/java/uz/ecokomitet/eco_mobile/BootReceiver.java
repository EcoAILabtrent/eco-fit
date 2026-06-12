package uz.ecokomitet.eco_mobile;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;

/**
 * After a reboot the hardware step counter restarts from zero. Re-register the
 * periodic sampler and take one immediate sample so the new baseline is
 * captured right away — without waiting for the user to open the app.
 * (Pattern borrowed from the StepsShare OSS pedometer.)
 */
public class BootReceiver extends BroadcastReceiver {

    @Override
    public void onReceive(Context context, Intent intent) {
        if (intent == null || !Intent.ACTION_BOOT_COMPLETED.equals(intent.getAction())) return;
        StepSampleWorker.schedule(context);
        StepSampleWorker.scheduleOnce(context);
    }
}
