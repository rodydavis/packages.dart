package flutter.plugins.vibrate;

import android.content.Context;
import android.os.Vibrator;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.MethodChannel;

public class VibratePlugin implements FlutterPlugin, io.flutter.embedding.engine.plugins.activity.ActivityAware {
    private VibrateMethodCallHandler methodCallHandler;

    @Override
    public void onAttachedToEngine(FlutterPluginBinding binding) {
        final Context context = binding.getApplicationContext();
        final BinaryMessenger messenger = binding.getBinaryMessenger();
        final Vibrator vibrator = (Vibrator) context.getSystemService(Context.VIBRATOR_SERVICE);
        methodCallHandler = new VibrateMethodCallHandler(vibrator);

        Messages.VibrateApi.setUp(messenger, methodCallHandler);
    }

    @Override
    public void onDetachedFromEngine(FlutterPluginBinding binding) {
        Messages.VibrateApi.setUp(binding.getBinaryMessenger(), null);
        this.methodCallHandler = null;
    }

    @Override
    public void onAttachedToActivity(io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding binding) {
        methodCallHandler.setActivity(binding.getActivity());
    }

    @Override
    public void onDetachedFromActivityForConfigChanges() {
        methodCallHandler.setActivity(null);
    }

    @Override
    public void onReattachedToActivityForConfigChanges(io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding binding) {
        methodCallHandler.setActivity(binding.getActivity());
    }

    @Override
    public void onDetachedFromActivity() {
        methodCallHandler.setActivity(null);
    }
}
