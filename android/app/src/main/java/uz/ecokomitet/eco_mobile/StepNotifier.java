package uz.ecokomitet.eco_mobile;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.os.Build;

import java.util.Calendar;
import java.util.Locale;

/**
 * Step-goal notifications evaluated fully natively — the only reminder that
 * works with the Flutter side dead, because StepSamples can compute today's
 * total from SharedPreferences checkpoints alone.
 *
 * Two rules, each at most once per day:
 *  - celebration when today's steps cross the goal;
 *  - evening nudge (18:00–21:00) when progress is below 60% of the goal.
 *
 * Config (enabled flag, goal, pre-localized strings) is mirrored from Dart via
 * the 'eco/steps' channel on every notification replan, so language/goal
 * changes propagate without the worker touching Hive. Notification ids 900/901
 * stay clear of the Dart-side ranges (100–350).
 */
final class StepNotifier {

    private static final String PREFS = "eco_step_notify";
    private static final String CHANNEL_ID = "eco_steps";
    private static final int ID_GOAL = 900;
    private static final int ID_NUDGE = 901;

    private StepNotifier() {}

    /** Persist config pushed from Dart (NotificationService). */
    static void configure(Context ctx, boolean enabled, long goal,
                          String channelName, String channelDesc,
                          String celebrationTitle, String celebrationBody,
                          String nudgeTitle, String nudgeBody) {
        ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putBoolean("enabled", enabled)
            .putLong("goal", goal)
            .putString("channelName", channelName)
            .putString("channelDesc", channelDesc)
            .putString("celebrationTitle", celebrationTitle)
            .putString("celebrationBody", celebrationBody)
            .putString("nudgeTitle", nudgeTitle)
            .putString("nudgeBody", nudgeBody)
            .apply();
    }

    /** Evaluate the rules; called from StepSampleWorker after each sample. */
    static void maybeNotify(Context ctx) {
        SharedPreferences sp = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE);
        if (!sp.getBoolean("enabled", false)) return;
        long goal = sp.getLong("goal", 0);
        if (goal <= 0) return;

        NotificationManager nm =
            (NotificationManager) ctx.getSystemService(Context.NOTIFICATION_SERVICE);
        if (nm == null || !nm.areNotificationsEnabled()) return;

        long steps = StepSamples.todaySteps(ctx);
        String today = todayKey();

        if (steps >= goal && !today.equals(sp.getString("celebratedOn", ""))) {
            show(ctx, nm, sp, ID_GOAL,
                sp.getString("celebrationTitle", ""),
                sp.getString("celebrationBody", ""));
            sp.edit().putString("celebratedOn", today).apply();
            return;
        }

        int hour = Calendar.getInstance().get(Calendar.HOUR_OF_DAY);
        if (hour >= 18 && hour < 21
                && steps > 0 && steps < goal * 6 / 10
                && !today.equals(sp.getString("nudgedOn", ""))) {
            String body = sp.getString("nudgeBody", "");
            body = body == null ? "" : body.replace("{left}", String.valueOf(goal - steps));
            show(ctx, nm, sp, ID_NUDGE, sp.getString("nudgeTitle", ""), body);
            sp.edit().putString("nudgedOn", today).apply();
        }
    }

    private static void show(Context ctx, NotificationManager nm, SharedPreferences sp,
                             int id, String title, String body) {
        if (title == null || title.isEmpty()) return;
        if (!ensureChannel(ctx, nm, sp)) return;
        PendingIntent pi = null;
        Intent launch = ctx.getPackageManager().getLaunchIntentForPackage(ctx.getPackageName());
        if (launch != null) {
            launch.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TOP);
            pi = PendingIntent.getActivity(ctx, id, launch,
                PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
        }
        Notification.Builder b = Build.VERSION.SDK_INT >= Build.VERSION_CODES.O
            ? new Notification.Builder(ctx, CHANNEL_ID)
            : new Notification.Builder(ctx);
        b.setSmallIcon(R.drawable.ic_stat_eco)
            .setContentTitle(title)
            .setContentText(body)
            .setAutoCancel(true);
        if (pi != null) b.setContentIntent(pi);
        try {
            nm.notify(id, b.build());
        } catch (Exception ignored) {
            // Missing POST_NOTIFICATIONS on 13+ — silently skip.
        }
    }

    /** @return true once the channel exists (or isn't needed on pre-O). */
    private static boolean ensureChannel(Context ctx, NotificationManager nm, SharedPreferences sp) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return true;
        String name = sp.getString("channelName", null);
        // No localized name mirrored yet — skip rather than invent a channel
        // under a placeholder label (same stance as the empty-title guard).
        if (name == null || name.isEmpty()) return false;
        NotificationChannel ch =
            new NotificationChannel(CHANNEL_ID, name, NotificationManager.IMPORTANCE_DEFAULT);
        ch.setDescription(sp.getString("channelDesc", ""));
        nm.createNotificationChannel(ch);
        return true;
    }

    private static String todayKey() {
        Calendar c = Calendar.getInstance();
        return String.format(Locale.US, "%04d-%02d-%02d",
            c.get(Calendar.YEAR), c.get(Calendar.MONTH) + 1, c.get(Calendar.DAY_OF_MONTH));
    }
}
