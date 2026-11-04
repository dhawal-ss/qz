package org.cagnulen.qdomyoszwift;

import android.app.Notification;
import android.app.NotificationManager;
import android.content.Context;
import android.content.Intent;
import android.app.PendingIntent;
import android.graphics.Color;
import android.graphics.BitmapFactory;
import android.app.NotificationChannel;

public class NotificationClient
{
	 private static NotificationManager m_notificationManager;
	 private static Notification.Builder m_builder;
         private static Context _context;
         private static Intent serviceIntent = null;

         private static final String EXTRA_FOREGROUND_SERVICE_TYPE = "FOREGROUND_SERVICE_TYPE";
         private static final int FOREGROUND_SERVICE_TYPE_CONNECTED_DEVICE = 0x10;

	 public NotificationClient() {}

	 public static void notify(Context context, String message) {
                  _context = context;
                  serviceIntent = new Intent(context, ForegroundService.class);
		  serviceIntent.putExtra("inputExtra", message);
                  serviceIntent.putExtra(EXTRA_FOREGROUND_SERVICE_TYPE,
                                         FOREGROUND_SERVICE_TYPE_CONNECTED_DEVICE);

		  if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
			   context.startForegroundService(serviceIntent);
		  } else {
		      context.startService(serviceIntent);
		  }
	 }

         public static void hide() {
             if(serviceIntent != null)
                _context.stopService(serviceIntent);
         }

         // The ride while it runs: the clock (Android counts it while the ride moves), a line of
         // numbers, and Pause or Resume and Lap. It takes the place of the "ready" notification of
         // the service (the same id), on a quiet channel of its own. The buttons leave their tap in
         // pendingAction, which the app takes with takeAction() once a second.
         private static final int RIDE_ID = 1;
         private static final String RIDE_CHANNEL_ID = "BikemodoRideChannel";
         private static volatile int pendingAction = 0;
         private static android.content.BroadcastReceiver actionReceiver = null;
         private static boolean rideShown = false;

         private static String actionName(Context context, String what) {
             return context.getPackageName() + ".RIDE_" + what;
         }

         private static PendingIntent actionIntent(Context context, String what, int code) {
             Intent intent = new Intent(actionName(context, what)).setPackage(context.getPackageName());
             return PendingIntent.getBroadcast(context, code, intent,
                                               PendingIntent.FLAG_IMMUTABLE | PendingIntent.FLAG_UPDATE_CURRENT);
         }

         private static void listen(Context context) {
             if (actionReceiver != null)
                 return;
             actionReceiver = new android.content.BroadcastReceiver() {
                 @Override
                 public void onReceive(Context c, Intent intent) {
                     String action = intent.getAction();
                     if (action == null)
                         return;
                     if (action.equals(actionName(c, "TOGGLE")))
                         pendingAction = 1;
                     else if (action.equals(actionName(c, "LAP")))
                         pendingAction = 2;
                 }
             };
             android.content.IntentFilter filter = new android.content.IntentFilter();
             filter.addAction(actionName(context, "TOGGLE"));
             filter.addAction(actionName(context, "LAP"));
             Context app = context.getApplicationContext();
             if (android.os.Build.VERSION.SDK_INT >= 33)
                 app.registerReceiver(actionReceiver, filter, 4 /* Context.RECEIVER_NOT_EXPORTED */);
             else
                 app.registerReceiver(actionReceiver, filter);
         }

         public static void showRide(Context context, String title, String text, long startedAtMs, boolean paused,
                                     String toggleLabel, String lapLabel) {
             try {
                 listen(context);
                 NotificationManager manager = (NotificationManager) context.getSystemService(Context.NOTIFICATION_SERVICE);
                 if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                     NotificationChannel channel = new NotificationChannel(RIDE_CHANNEL_ID, "Bikemodo ride",
                                                                           NotificationManager.IMPORTANCE_LOW);
                     channel.setLockscreenVisibility(Notification.VISIBILITY_PUBLIC);
                     manager.createNotificationChannel(channel);
                 }
                 Intent open = new Intent(context, CustomQtActivity.class)
                         .setAction(Intent.ACTION_MAIN)
                         .addCategory(Intent.CATEGORY_LAUNCHER)
                         .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                 PendingIntent openIntent = PendingIntent.getActivity(context, 0, open, PendingIntent.FLAG_IMMUTABLE);
                 androidx.core.app.NotificationCompat.Builder builder =
                         new androidx.core.app.NotificationCompat.Builder(context, RIDE_CHANNEL_ID)
                         .setSmallIcon(R.drawable.icon)
                         .setContentTitle(title)
                         .setContentText(text)
                         .setContentIntent(openIntent)
                         .setOnlyAlertOnce(true)
                         .setOngoing(true)
                         .setSilent(true)
                         .setVisibility(androidx.core.app.NotificationCompat.VISIBILITY_PUBLIC)
                         .addAction(0, toggleLabel, actionIntent(context, "TOGGLE", 11))
                         .addAction(0, lapLabel, actionIntent(context, "LAP", 12));
                 if (paused) {
                     builder.setShowWhen(false);
                 } else {
                     builder.setShowWhen(true).setUsesChronometer(true).setWhen(startedAtMs);
                 }
                 manager.notify(RIDE_ID, builder.build());
                 rideShown = true;
             } catch (Exception e) {
                 QLog.e("NotificationClient", "Cannot show the ride notification", e);
             }
         }

         // the ride is over: the service shows its "ready" notification again, or there is none
         public static void hideRide(Context context, String readyMessage) {
             if (!rideShown)
                 return;
             rideShown = false;
             pendingAction = 0;
             try {
                 NotificationManager manager = (NotificationManager) context.getSystemService(Context.NOTIFICATION_SERVICE);
                 if (serviceIntent != null) {
                     // the service's own notification again, posted here: starting the service
                     // again is not allowed while the app is in the background
                     Intent open = new Intent(context, CustomQtActivity.class)
                             .setAction(Intent.ACTION_MAIN)
                             .addCategory(Intent.CATEGORY_LAUNCHER)
                             .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                     PendingIntent openIntent = PendingIntent.getActivity(context, 0, open, PendingIntent.FLAG_IMMUTABLE);
                     Notification ready = new androidx.core.app.NotificationCompat.Builder(context, ForegroundService.CHANNEL_ID)
                             .setContentTitle(readyMessage)
                             .setContentText(readyMessage)
                             .setSmallIcon(R.drawable.icon)
                             .setContentIntent(openIntent)
                             .setOnlyAlertOnce(true)
                             .setSilent(true)
                             .build();
                     manager.notify(RIDE_ID, ready);
                 } else {
                     manager.cancel(RIDE_ID);
                 }
             } catch (Exception e) {
                 QLog.e("NotificationClient", "Cannot hide the ride notification", e);
             }
         }

         // 0 nothing, 1 pause or resume, 2 lap; each tap is taken once
         public static int takeAction() {
             int action = pendingAction;
             pendingAction = 0;
             return action;
         }
}
