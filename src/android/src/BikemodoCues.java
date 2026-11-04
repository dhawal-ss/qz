package org.cagnulen.qdomyoszwift;

import android.content.Context;
import android.media.AudioManager;
import android.media.ToneGenerator;
import android.os.Build;
import android.os.VibrationEffect;
import android.os.Vibrator;
import android.provider.Settings;

// The cues of a ride: a beep on the notification volume and a short buzz. Nothing sounds or
// buzzes with the phone on silent, and the buzz follows the phone's own touch vibration setting.
public class BikemodoCues {
    private static final String TAG = "BikemodoCues";
    private static ToneGenerator tone = null;

    // kind 0 a tick, 1 a count, 2 a change
    public static void cue(Context context, int kind) {
        try {
            AudioManager audio = (AudioManager) context.getSystemService(Context.AUDIO_SERVICE);
            if (audio != null && audio.getRingerMode() == AudioManager.RINGER_MODE_SILENT)
                return;
            boolean ringing = audio == null || audio.getRingerMode() == AudioManager.RINGER_MODE_NORMAL;
            if (ringing) {
                if (tone == null)
                    tone = new ToneGenerator(AudioManager.STREAM_NOTIFICATION, 80);
                if (kind == 2)
                    tone.startTone(ToneGenerator.TONE_PROP_BEEP2, 350);
                else if (kind == 1)
                    tone.startTone(ToneGenerator.TONE_PROP_BEEP, 120);
                else
                    tone.startTone(ToneGenerator.TONE_PROP_BEEP, 40);
            }
            boolean touchVibration = Settings.System.getInt(context.getContentResolver(),
                                                            Settings.System.HAPTIC_FEEDBACK_ENABLED, 1) != 0;
            if (!touchVibration)
                return;
            Vibrator vibrator = (Vibrator) context.getSystemService(Context.VIBRATOR_SERVICE);
            if (vibrator == null || !vibrator.hasVibrator())
                return;
            int ms = kind == 2 ? 220 : (kind == 1 ? 60 : 25);
            if (Build.VERSION.SDK_INT >= 26)
                vibrator.vibrate(VibrationEffect.createOneShot(ms, VibrationEffect.DEFAULT_AMPLITUDE));
            else
                vibrator.vibrate(ms);
        } catch (Exception e) {
            QLog.e(TAG, "Cannot play the cue", e);
        }
    }
}
