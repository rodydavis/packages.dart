# Flutter WhatsNew

A Flutter package to display a "What's New" or "Changelog" dialog to users. Perfect for informing users about new features, updates, or important announcements after an app update.

## Features

*   **Changelog Parsing:** Automatically parse your `CHANGELOG.md` file and display the latest changes.
*   **Customizable UI:** Fully customizable text, colors, buttons, and layout.
*   **Scheduled Display:** Show the dialog after a delay or only when the app version changes.
*   **Adaptive Design:** Works on Android, iOS, Web, and Desktop.
*   **Material 3 Ready:** Modern design defaults.

## Installation

Add `flutter_whatsnew` to your `pubspec.yaml`:

```yaml
dependencies:
  flutter_whatsnew: ^1.1.0
```

## Usage

### 1. Show Changelog from File

Ensure your `CHANGELOG.md` is included in your `pubspec.yaml` assets:

```yaml
flutter:
  assets:
    - CHANGELOG.md
```

Then, navigate to the `WhatsNewPage.changelog`:

```dart
import 'package:flutter_whatsnew/flutter_whatsnew.dart';

// Check documentation for method parameters
WhatsNewPage.changelog(
  title: Text("What's New"),
  buttonText: Text("Continue"),
  // path: 'assets/CHANGELOG.md', // Optional, defaults to CHANGELOG.md
);
```

### 2. Manual List of Items

You can pass a list of widgets (e.g., `ListTile`) to display specific features:

```dart
WhatsNewPage(
  title: Text("What's New"),
  items: [
    ListTile(
      leading: Icon(Icons.star),
      title: Text('New Feature'),
      subtitle: Text('Description of the new feature.'),
    ),
    ListTile(
      leading: Icon(Icons.bug_report),
      title: Text('Bug Fixes'),
      subtitle: Text('Fixed various issues.'),
    ),
  ],
  buttonText: Text("Let's Go"),
  onButtonPressed: () {
    Navigator.pop(context);
  },
);
```

### 3. Scheduled / Delayed Display

Use `ScheduledWhatsNewPage` to show the dialog only after a delay or based on version checks.

```dart
ScheduledWhatsNewPage(
  details: WhatsNewPage.changelog(
    title: Text("Update Available"),
    buttonText: Text("Okay"),
  ),
  delay: Duration(seconds: 3), // Show after 3 seconds
  // appVersion: '1.0.1', // Only show if the saved version differs
  child: HomeScreen(),
);
```

## detailed Documentation

### WhatsNewPage

| Parameter | Type | Description |
|---|---|---|
| `items` | `List<Widget>` | The list of widgets to display in the scrollable area. |
| `title` | `Widget` | The title widget at the top of the dialog. |
| `buttonText` | `Widget` | The text widget inside the bottom button. |
| `onButtonPressed` | `VoidCallback?` | Callback when the button is pressed. Defaults to `Navigator.pop`. |
| `backgroundColor` | `Color?` | Background color of the page. |
| `buttonColor` | `Color?` | Color of the bottom button. |

### WhatsNewPage.changelog

| Parameter | Type | Description |
|---|---|---|
| `path` | `String` | Path to the markdown file. Defaults to `CHANGELOG.md`. |
| `textScaler` | `TextScaler?` | Scaler for the markdown text. |
| `title` | `Widget` | The title widget. |
| ... | ... | See `WhatsNewPage` for other shared parameters. |
