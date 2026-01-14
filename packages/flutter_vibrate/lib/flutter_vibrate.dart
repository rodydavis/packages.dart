import 'dart:async';

import 'src/messages.g.dart';

export 'src/messages.g.dart' show VibrateApi;

/// A set of feedback types that can be used to provide haptic feedback.
enum FeedbackType {
  /// Indicates a task has completed successfully.
  success,

  /// Indicates a task has failed or an error occurred.
  error,

  /// Indicates a warning or caution.
  warning,

  /// Indicates a selection change (e.g., scrolling through a list).
  selection,

  /// Provides a heavy physical impact.
  impact,

  /// Provides a heavy vibration.
  heavy,

  /// Provides a medium vibration.
  medium,

  /// Provides a light vibration.
  light,
}

/// A class that provides access to the device's vibration hardware.
class Vibrate {
  static final VibrateApi _api = VibrateApi();
  static const Duration _defaultVibrationDuration = Duration(milliseconds: 500);

  /// Vibrates the device for 500ms on Android, and for the default system vibration duration on iOS.
  static Future<void> vibrate() async {
    await _api.vibrate(500);
  }

  /// Checks if the device has vibration hardware.
  ///
  /// Returns `true` if the device can vibrate, `false` otherwise.
  static Future<bool> get canVibrate async {
    return _api.canVibrate();
  }

  /// Vibrates the device with a specific pattern of pauses.
  ///
  /// The [pauses] iterable defines the duration of silence in between vibrations.
  /// The pattern will always start with a vibration, followed by the first pause,
  /// then another vibration, and so on, ending with a final vibration.
  ///
  /// For example, if [pauses] is `[Duration(seconds: 1)]`, the device will:
  /// 1. Vibrate (default duration)
  /// 2. Wait for 1 second
  /// 3. Vibrate (default duration)
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

  /// Provides haptic feedback corresponding to the specified [type].
  ///
  /// This uses the platform's native haptic feedback mechanisms (e.g., `UINotificationFeedbackGenerator` on iOS,
  /// `View.performHapticFeedback` on Android).
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
