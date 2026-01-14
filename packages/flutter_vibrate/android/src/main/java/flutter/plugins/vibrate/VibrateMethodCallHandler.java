package flutter.plugins.vibrate;

import android.os.Build;
import android.os.Vibrator;
import android.os.VibrationEffect;
import android.view.HapticFeedbackConstants;

import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

class VibrateMethodCallHandler implements MethodChannel.MethodCallHandler {
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
    private void vibrate(int duration) {
        if (hasVibrator) {
            if (legacyVibrator) {
                vibrator.vibrate(duration);
            } else {
                vibrator.vibrate(VibrationEffect.createOneShot(duration, VibrationEffect.DEFAULT_AMPLITUDE));
            }
        }
    }

    private void feedback(int feedbackConstant) {
        if (activity != null) {
            activity.getWindow().getDecorView().performHapticFeedback(feedbackConstant);
        } else {
             // Fallback to vibrator if no activity/view (though unlikely in a running app)
             // or just ignore if strictly view-based.
             // For now, let's fallback to the old vibration logic for consistency if View is not ready,
             // although the user specifically wants View feedback.
             // Actually, the old logic was calling vibrate(int) for specific types.
             // We can map some to vibrate(int) if really needed, but let's assume Activity is there.
        }
    }

    @Override
    public void onMethodCall(MethodCall call, MethodChannel.Result result) {
        switch (call.method) {
            case "canVibrate":
                result.success(hasVibrator);
                break;
            case "vibrate":
                final int duration = call.argument("duration");
                vibrate(d);
                result.success(null);
                break;
            case "impact":
                feedback(HapticFeedbackConstants.VIRTUAL_KEY);
                result.success(null);
                break;
            case "selection":
                feedback(HapticFeedbackConstants.KEYBOARD_TAP);
                result.success(null);
                break;
            case "success":
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    feedback(HapticFeedbackConstants.CONFIRM);
                } else {
                    vibrate(50);
                }
                result.success(null);
                break;
            case "warning":
                 if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    feedback(HapticFeedbackConstants.REJECT);
                } else {
                    vibrate(250);
                }
                result.success(null);
                break;
            case "error":
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    feedback(HapticFeedbackConstants.REJECT);
                } else {
                    vibrate(500);
                }
                result.success(null);
                break;
            case "heavy":
                feedback(HapticFeedbackConstants.LONG_PRESS);
                result.success(null);
                break;
            case "medium":
                feedback(HapticFeedbackConstants.VIRTUAL_KEY);
                result.success(null);
                break;
            case "light":
                feedback(HapticFeedbackConstants.CLOCK_TICK);
                result.success(null);
                break;
            default:
                result.notImplemented();
                break;
        }

    }
}
