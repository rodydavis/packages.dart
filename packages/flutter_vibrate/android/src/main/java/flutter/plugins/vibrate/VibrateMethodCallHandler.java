package flutter.plugins.vibrate;

import android.os.Build;
import android.os.Vibrator;
import android.os.VibrationEffect;
import android.view.HapticFeedbackConstants;

public class VibrateMethodCallHandler implements Messages.VibrateApi {
    private final Vibrator vibrator;
    private final boolean hasVibrator;
    private final boolean legacyVibrator;
    private android.app.Activity activity;

    VibrateMethodCallHandler(Vibrator vibrator) {
        assert (vibrator != null);
        this.vibrator = vibrator;
        this.hasVibrator = vibrator.hasVibrator();
        this.legacyVibrator = Build.VERSION.SDK_INT < 26;
    }

    public void setActivity(android.app.Activity activity) {
        this.activity = activity;
    }

    @SuppressWarnings("deprecation")
    @Override
    public void vibrate(Long duration) {
        if (hasVibrator) {
            if (legacyVibrator) {
                vibrator.vibrate(duration.intValue()); // Deprecated method takes int
            } else {
                vibrator.vibrate(VibrationEffect.createOneShot(duration, VibrationEffect.DEFAULT_AMPLITUDE));
            }
        }
    }

    @Override
    public Boolean canVibrate() {
        return hasVibrator;
    }

    private void feedback(int feedbackConstant) {
        if (activity != null) {
            activity.getWindow().getDecorView().performHapticFeedback(feedbackConstant);
        }
    }

    @Override
    public void impact() {
        feedback(HapticFeedbackConstants.VIRTUAL_KEY);
    }

    @Override
    public void selection() {
        feedback(HapticFeedbackConstants.KEYBOARD_TAP);
    }

    @Override
    public void success() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            feedback(HapticFeedbackConstants.CONFIRM);
        } else {
            vibrate(50L);
        }
    }

    @Override
    public void warning() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            feedback(HapticFeedbackConstants.REJECT);
        } else {
            vibrate(250L);
        }
    }

    @Override
    public void error() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            feedback(HapticFeedbackConstants.REJECT);
        } else {
            vibrate(500L);
        }
    }

    @Override
    public void heavy() {
        feedback(HapticFeedbackConstants.LONG_PRESS);
    }

    @Override
    public void medium() {
        feedback(HapticFeedbackConstants.VIRTUAL_KEY);
    }

    @Override
    public void light() {
        feedback(HapticFeedbackConstants.CLOCK_TICK);
    }
}
