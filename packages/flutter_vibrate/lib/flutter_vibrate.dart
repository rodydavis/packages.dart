import 'dart:async';

import 'src/messages.g.dart';

export 'src/messages.g.dart' show VibrateApi;

enum FeedbackType {
  success,
  error,
  warning,
  selection,
  impact,
  heavy,
  medium,
  light,
}

class Vibrate {
  static final VibrateApi _api = VibrateApi();
  static const Duration _defaultVibrationDuration = Duration(milliseconds: 500);

  /// Vibrate for 500ms on Android, and for the default time on iOS (about 500ms as well)
  static Future<void> vibrate() async {
    await _api.vibrate(500);
  }

  /// Whether the device can actually vibrate or not
  static Future<bool> get canVibrate async {
    return _api.canVibrate();
  }

  /// Vibrates with [pauses] in between each vibration
  /// Will always vibrate once before the first pause
  /// and once after the last pause
  static Future<void> vibrateWithPauses(Iterable<Duration> pauses) async {
    for (final Duration d in pauses) {
      await vibrate();
      // Because the native vibration is not awaited (fire-and-forget in some impls,
      // though Pigeon calls are async, the vibration itself happens on hardware),
      // we need to wait for the vibration to end before launching another one.
      await Future.delayed(_defaultVibrationDuration);
      await Future.delayed(d);
    }
    await vibrate();
  }

  static Future<void> feedback(FeedbackType type) async {
    switch (type) {
      case FeedbackType.impact:
        await _api.impact();
        break;
      case FeedbackType.selection:
        await _api.selection();
        break;
      case FeedbackType.success:
        await _api.success();
        break;
      case FeedbackType.warning:
        await _api.warning();
        break;
      case FeedbackType.error:
        await _api.error();
        break;
      case FeedbackType.heavy:
        await _api.heavy();
        break;
      case FeedbackType.medium:
        await _api.medium();
        break;
      case FeedbackType.light:
        await _api.light();
        break;
    }
  }
}
