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
