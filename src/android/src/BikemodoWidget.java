package org.cagnulen.qdomyoszwift;

import android.app.PendingIntent;
import android.appwidget.AppWidgetManager;
import android.appwidget.AppWidgetProvider;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.widget.RemoteViews;

// The home screen widget: the week against the weekly goal and the streak, as the app last worked
// them out (it writes them each time Today refreshes). A tap opens the app.
public class BikemodoWidget extends AppWidgetProvider {
    static final String PREFS = "bikemodo_widget";

    @Override
    public void onUpdate(Context context, AppWidgetManager manager, int[] ids) {
        render(context, manager, ids);
    }

    static void render(Context context, AppWidgetManager manager, int[] ids) {
        SharedPreferences prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE);
        Intent open = new Intent(context, CustomQtActivity.class)
                .setAction(Intent.ACTION_MAIN)
                .addCategory(Intent.CATEGORY_LAUNCHER)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        PendingIntent tap = PendingIntent.getActivity(context, 21, open, PendingIntent.FLAG_IMMUTABLE);
        for (int id : ids) {
            RemoteViews views = new RemoteViews(context.getPackageName(), R.layout.bikemodo_widget);
            views.setTextViewText(R.id.bikemodo_widget_value, prefs.getString("value", "Open Bikemodo"));
            views.setTextViewText(R.id.bikemodo_widget_detail, prefs.getString("detail", ""));
            // the body line of Today, only on the day Health Connect was read
            String streak = prefs.getString("streak", "");
            String body = today().equals(prefs.getString("bodyDay", "")) ? prefs.getString("body", "") : "";
            String line = streak.isEmpty() ? body : (body.isEmpty() ? streak : streak + " · " + body);
            views.setTextViewText(R.id.bikemodo_widget_streak, line);
            views.setOnClickPendingIntent(R.id.bikemodo_widget_root, tap);
            manager.updateAppWidget(id, views);
        }
    }

    static String today() {
        return new java.text.SimpleDateFormat("yyyy-MM-dd", java.util.Locale.US).format(new java.util.Date());
    }

    // from Today: how the body is this morning (Health Connect), "" when there is nothing to say
    public static void updateBody(Context context, String words) {
        try {
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
                    .putString("body", words).putString("bodyDay", today()).apply();
            AppWidgetManager manager = AppWidgetManager.getInstance(context);
            int[] ids = manager.getAppWidgetIds(new ComponentName(context, BikemodoWidget.class));
            if (ids.length > 0)
                render(context, manager, ids);
        } catch (Exception e) {
            QLog.e("BikemodoWidget", "Cannot update the widget's body line", e);
        }
    }

    // from the app: the new numbers, the widgets redrawn, and the week's recap kept for Monday
    public static void update(Context context, String value, String detail, String streak,
                              String weekKey, String recapTitle, String recapText) {
        try {
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
                    .putString("value", value).putString("detail", detail).putString("streak", streak)
                    .putString("recapWeek", weekKey).putString("recapTitle", recapTitle).putString("recapText", recapText)
                    .apply();
            AppWidgetManager manager = AppWidgetManager.getInstance(context);
            int[] ids = manager.getAppWidgetIds(new ComponentName(context, BikemodoWidget.class));
            if (ids.length > 0)
                render(context, manager, ids);
            BikemodoRecap.schedule(context);
        } catch (Exception e) {
            QLog.e("BikemodoWidget", "Cannot update the widget", e);
        }
    }
}
