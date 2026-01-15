# App Review

A Flutter plugin for Requesting and Writing Reviews and Opening Store Listings for Android, iOS, and macOS.

This plugin allows you to prompt users to rate your app without leaving the application (In-App Review) or to deep-link users directly to your store listing or review page.

---

## Operations

| Feature | Android | iOS | macOS | Windows | Linux | Web | Description |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :--- |
| **Request Review** | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | Native In-App Review prompt. |
| **Open Store Listing** | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | Opens the app's page on Play Store / App Store. |
| **Open Write Review** | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | Directs user to the "Write a Review" section. |
| **Lookup App ID** | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | Fetches App ID/Track ID from iTunes Lookup API. |

---

## Setup

### Android

1.  **Requirement**: Uses the [Google Play In-App Review API](https://developer.android.com/guide/playcore/in-app-review).
2.  **Usage**: Ensure your app is published on the Play Store for the real review flow to work.
    *   **Test Mode**: You can enable `testMode: true` when calling `requestReview()` to use the `FakeReviewManager`, which simulates the review flow without requiring a published app.

### iOS

1.  **Requirement**: Uses `SKStoreReviewController`.
2.  **Usage**: 
    *   Development/TestFlight: The prompt may not always appear or may do nothing.
    *   Production: Apple limits the prompt to display only **3 times per year**.
    *   iOS 16+ Support: Uses `SwiftUI` environment value for requesting reviews if running in a SwiftUI context, otherwise falls back to `SKStoreReviewController`.

### macOS

1.  **Requirement**: Uses `SKStoreReviewController` (macOS 10.14+) or `SwiftUI` requestReview (macOS 14+).
2.  **Sandboxing**: Ensure `com.apple.security.network.client` entitlement is active for API lookups if needed.

---

## Usage

### 1. Request In-App Review

Prompts the user to rate the app.

```dart
import 'package:app_review/app_review.dart';

// ...

try {
  // Pass testMode: true to simulate review on Android (uses FakeReviewManager)
  await AppReview.requestReview(testMode: kDebugMode);
} catch (e) {
  print('Request review failed: $e');
}
```

### 2. Open Store Listing

Opens the App Store or Google Play Store page for the app.

```dart
// Open for current app
await AppReview.openStoreListing();

// OR open for a specific app ID/package name
await AppReview.openStoreListing(storeId: "com.example.otherapp");
```

### 3. Open Write Review Page

Attempts to open the store directly to the "Write a Review" screen.

```dart
// For current app
await AppReview.openAppStoreReview(); // iOS/macOS only
// Android typically handles this via openStoreListing but we provide a unified API
```

### 4. Lookup App ID (iOS/macOS)

Useful if you need to find your Apple App ID (Track ID) dynamically using your Bundle ID.

```dart
String? appID = await AppReview.getIosAppId(
  bundleId: "com.example.app", 
  countryCode: "US" // optional
);
print("App ID: $appID");
```

---

## Example

Check out the `example` directory for a complete sample application.
