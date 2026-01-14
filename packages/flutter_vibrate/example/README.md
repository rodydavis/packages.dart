# flutter_vibrate Example

This example app demonstrates how to use the `flutter_vibrate` plugin to trigger device vibrations and haptic feedback.

## API Reference & Usage

Below is an exhaustive list of all exposed methods and haptic feedback types available in the `flutter_vibrate` package.

### 1. Check Capabilities

Check if the current device has the hardware to support vibration.

```dart
bool canVibrate = await Vibrate.canVibrate;
```

### 2. Standard Vibration

Trigger a standard vibration (500ms on Android; system default on iOS).

```dart
Vibrate.vibrate();
```

### 3. Vibration Patterns (Android)

Trigger a custom vibration pattern by specifying durations for [vibrate, wait, vibrate...].
*On iOS, this will vibrate once for each duration provided, as fine-grained patterns are not supported.*

```dart
final Iterable<Duration> pauses = [
    const Duration(milliseconds: 500), // Vibrate
    const Duration(milliseconds: 1000), // Wait
    const Duration(milliseconds: 500), // Vibrate
];

Vibrate.vibrateWithPauses(pauses);
```

### 4. Haptic Feedback

Trigger specific haptic feedback to enhance user interactions.

#### Success
Indicates that a task has completed successfully.
```dart
Vibrate.feedback(FeedbackType.success);
```

#### Error
Indicates that a task has failed.
```dart
Vibrate.feedback(FeedbackType.error);
```

#### Warning
Indicates a warning or potential issue.
```dart
Vibrate.feedback(FeedbackType.warning);
```

#### Selection
Indicates a selection change (e.g., snapping to a value, scrolling through a list).
```dart
Vibrate.feedback(FeedbackType.selection);
```

#### Impact
Provides a physical impact feedback (e.g., a collision or thud).
```dart
Vibrate.feedback(FeedbackType.impact);
```

#### Heavy
Provides a heavy mass impact.
```dart
Vibrate.feedback(FeedbackType.heavy);
```

#### Medium
Provides a medium mass impact.
```dart
Vibrate.feedback(FeedbackType.medium);
```

#### Light
Provides a light mass impact.
```dart
Vibrate.feedback(FeedbackType.light);
```

## Getting Started

1.  **Run the app**:
    ```bash
    flutter run
    ```
2.  **Explore**: Tap the tiles in the app to feel each of the vibrations and feedbacks listed above.

## Android Permissions

The example app includes the necessary permission in [`android/app/src/main/AndroidManifest.xml`](android/app/src/main/AndroidManifest.xml):

```xml
<uses-permission android:name="android.permission.VIBRATE"/>
```
