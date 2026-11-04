package org.cagnulen.qdomyoszwift;

import android.app.AlarmManager;
import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.os.Build;
import java.util.Calendar;

// The weekly recap: on Monday morning, one quiet notification with the week before, as the app last
// worked it out (BikemodoWidget.update keeps it with the week it belongs to). Nothing is posted for a
// week the app did not see, or twice for the same week.
public class BikemodoRecap extends BroadcastReceiver {
    private static final String CHANNEL = "BikemodoRecapChannel";
    private static final int ID = 7;

    // Monday at 9, then every 7 days; scheduling again replaces the alarm before it
    public static void schedule(Context context) {
        try {
            AlarmManager alarms = (AlarmManager) context.getSystemService(Context.ALARM_SERVICE);
            Intent intent = new Intent(context, BikemodoRecap.class);
            PendingIntent pending = PendingIntent.getBroadcast(context, 31, intent,
                    PendingIntent.FLAG_IMMUTABLE | PendingIntent.FLAG_UPDATE_CURRENT);
            Calendar next = Calendar.getInstance();
            next.set(Calendar.HOUR_OF_DAY, 9);
            next.set(Calendar.MINUTE, 0);
            next.set(Calendar.SECOND, 0);
            next.set(Calendar.MILLISECOND, 0);
            while (next.get(Calendar.DAY_OF_WEEK) != Calendar.MONDAY || next.getTimeInMillis() <= System.currentTimeMillis())
                next.add(Calendar.DAY_OF_MONTH, 1);
            alarms.setInexactRepeating(AlarmManager.RTC, next.getTimeInMillis(), AlarmManager.INTERVAL_DAY * 7, pending);
        } catch (Exception e) {
            QLog.e("BikemodoRecap", "Cannot schedule the weekly recap", e);
        }
    }

    // the Monday of the week before, as the app writes week keys: yyyy-MM-dd
    private static String lastWeekKey() {
        Calendar c = Calendar.getInstance();
        while (c.get(Calendar.DAY_OF_WEEK) != Calendar.MONDAY)
            c.add(Calendar.DAY_OF_MONTH, -1);
        c.add(Calendar.DAY_OF_MONTH, -7);
        return String.format("%04d-%02d-%02d", c.get(Calendar.YEAR), c.get(Calendar.MONTH) + 1, c.get(Calendar.DAY_OF_MONTH));
    }

    @Override
    public void onReceive(Context context, Intent intent) {
        try {
            SharedPreferences prefs = context.getSharedPreferences(BikemodoWidget.PREFS, Context.MODE_PRIVATE);
            String week = prefs.getString("recapWeek", "");
            String title = prefs.getString("recapTitle", "");
            String text = prefs.getString("recapText", "");
            if (title.isEmpty() || !week.equals(lastWeekKey()) || week.equals(prefs.getString("recapPosted", "")))
                return;
            NotificationManager manager = (NotificationManager) context.getSystemService(Context.NOTIFICATION_SERVICE);
            if (Build.VERSION.SDK_INT >= 26) {
                NotificationChannel channel = new NotificationChannel(CHANNEL, "Bikemodo weekly recap", NotificationManager.IMPORTANCE_LOW);
                manager.createNotificationChannel(channel);
            }
            Intent open = new Intent(context, CustomQtActivity.class)
                    .setAction(Intent.ACTION_MAIN)
                    .addCategory(Intent.CATEGORY_LAUNCHER)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            PendingIntent tap = PendingIntent.getActivity(context, 32, open, PendingIntent.FLAG_IMMUTABLE);
            Notification n = new androidx.core.app.NotificationCompat.Builder(context, CHANNEL)
                    .setSmallIcon(R.drawable.icon)
                    .setContentTitle(title)
                    .setContentText(text)
                    .setStyle(new androidx.core.app.NotificationCompat.BigTextStyle().bigText(text))
                    .setContentIntent(tap)
                    .setAutoCancel(true)
                    .build();
            manager.notify(ID, n);
            prefs.edit().putString("recapPosted", week).apply();
        } catch (Exception e) {
            QLog.e("BikemodoRecap", "Cannot post the weekly recap", e);
        }
    }
}
