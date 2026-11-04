package org.cagnulen.qdomyoszwift;

import android.content.Context;
import android.provider.Settings;

// The phone's own display choices Bikemodo follows: the font size and "Remove animations".
public class BikemodoSystem {
    public static float fontScale(Context context) {
        try {
            return context.getResources().getConfiguration().fontScale;
        } catch (Exception e) {
            return 1f;
        }
    }

    // true when the phone uses its dark theme (Display > Dark theme)
    public static boolean nightMode(Context context) {
        try {
            int night = context.getResources().getConfiguration().uiMode & android.content.res.Configuration.UI_MODE_NIGHT_MASK;
            return night == android.content.res.Configuration.UI_MODE_NIGHT_YES;
        } catch (Exception e) {
            return true;
        }
    }

    // true when Android's animations are off (Accessibility > Remove animations, or the animator
    // duration scale at 0 in the developer options)
    public static boolean animationsOff(Context context) {
        try {
            return Settings.Global.getFloat(context.getContentResolver(), Settings.Global.ANIMATOR_DURATION_SCALE, 1f) == 0f;
        } catch (Exception e) {
            return false;
        }
    }
}
