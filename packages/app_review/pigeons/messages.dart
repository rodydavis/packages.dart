import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(PigeonOptions(
  dartOut: 'lib/src/messages.g.dart',
  dartOptions: DartOptions(),
  kotlinOut: 'android/src/main/java/com/appleeducate/appreview/Messages.g.kt',
  kotlinOptions: KotlinOptions(package: 'com.appleeducate.appreview'),
  javaOut: 'android/src/main/java/com/appleeducate/appreview/Messages.java',
  javaOptions: JavaOptions(package: 'com.appleeducate.appreview'),
  swiftOut: 'ios/Classes/Messages.g.swift',
  swiftOptions: SwiftOptions(),
))
@HostApi()
abstract class AppReviewApi {
  /// Request review.
  ///
  /// Tells StoreKit / Play Store to ask the user to rate or review your app, if appropriate.
  /// Supported only in iOS 10.3+ and Android with Play Services installed (see [isRequestReviewAvailable]).
  ///
  /// Returns string with details message.
  @async
  String? requestReview(bool testMode);

  /// Check if [requestReview] feature available.
  @async
  bool isRequestReviewAvailable();

  /// Opens the store listing for the specified app.
  ///
  /// [storeId] is the package name (Android) or App ID (iOS/macOS).
  @async
  void openStoreListing(String? storeId);

  /// Opens the App Store review page (iOS/macOS only).
  ///
  /// [storeId] is the App ID.
  @async
  void openAppStoreReview(String? storeId);

  /// Returns package name for application.
  @async
  String getBundleId();

  /// Requests the App ID from the App Store (via iTunes Lookup API).
  ///
  /// [bundleId] is the bundle identifier to look up.
  /// [countryCode] is the optional country code.
  @async
  String? lookupAppId(String bundleId, String? countryCode);
}
