# Flutter Vibrate
[![Pub Version](https://img.shields.io/pub/v/flutter_vibrate?style=flat-square&color=blue)](https://pub.dev/packages/flutter_vibrate)

A Flutter plugin to provide haptic feedback on iOS and Android. This package unifies the haptic feedback APIs, allowing for consistent vibration patterns and feedback types across both platforms.

| Platform | Support |
| :--- | :---: |
| Android | ✅ |
| iOS | ✅ |
| macOS | ❌ |
| Web | ❌ |
| Linux | ❌ |
| Windows | ❌ |

## Features

- **Device Vibration**: Trigger standard vibrations or custom patterns (Android).
- **Haptic Feedback**: Access platform-specific haptic feedback constants (Impact, Selection, Success, Warning, Error, etc.).
- **Type Safety**: Built with Pigeon for type-safe communication between Flutter and native platforms.
- **Modern Android Support**: Uses `View.performHapticFeedback` for broad compatibility and adheres to modern Android haptic standards.
- **iOS Haptics**: Uses `UIImpactFeedbackGenerator` and `UINotificationFeedbackGenerator` for rich haptic experiences on iOS 10+.

## Getting Started

### Installation

Add `flutter_vibrate` to your `pubspec.yaml`:

```yaml
dependencies:
  flutter_vibrate: ^1.4.0
```

### Android Setup

Add the vibration permission to your `AndroidManifest.xml` (`android/app/src/main/AndroidManifest.xml`):

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.VIBRATE"/>
</manifest>
```

> **Note**: While `vibrate()` requires this permission, many haptic feedback types (like selection, impact) may work without it on some Android versions using the View-based API. However, it is recommended to include it for full functionality.

### iOS Setup

No additional configuration is required. The plugin uses `AudioServicesPlaySystemSound` and `UIFeedbackGenerator` which are available by default.

## Usage

Import the package:

```dart
import 'package:flutter_vibrate/flutter_vibrate.dart';
```

### Basic Vibration

Check for device capabilities and vibrate:

```dart
// Check if the device can vibrate
bool canVibrate = await Vibrate.canVibrate;

if (canVibrate) {
  // Vibrate for 500ms
  Vibrate.vibrate();
}
```

### Vibration Patterns

You can create custom patterns by specifying a list of pauses. The pattern alternates between vibrating and pausing.

> **Android**: Supports custom patterns with variable pauses.
>
> **iOS**: The OS does not support fine-grained custom patterns. This method will vibrate once for each interval in the list.

```dart
final Iterable<Duration> pauses = const [
    Duration(milliseconds: 500), // Vibrate
    Duration(milliseconds: 1000), // Wait
    Duration(milliseconds: 500), // Vibrate
];

Vibrate.vibrateWithPauses(pauses);
```

### Haptic Feedback

Trigger specific haptic feedback types to enhance user interaction:

```dart
// Impact (light collision)
Vibrate.feedback(FeedbackType.impact);

// Selection (scroll tick)
Vibrate.feedback(FeedbackType.selection);

// Success (task completion)
Vibrate.feedback(FeedbackType.success);

// Warning (potential issue)
Vibrate.feedback(FeedbackType.warning);

// Error (task failure)
Vibrate.feedback(FeedbackType.error);

// Heavy Impact
Vibrate.feedback(FeedbackType.heavy);

// Medium Impact
Vibrate.feedback(FeedbackType.medium);

// Light Impact
Vibrate.feedback(FeedbackType.light);
```

## Contributing

Contributions are welcome! If you find a bug or want to add a feature, please file an issue or submit a pull request.
