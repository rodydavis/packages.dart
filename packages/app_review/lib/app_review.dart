import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';

import 'src/exceptions.dart';
import 'src/messages.g.dart';

class AppReview {
  static const Duration kDefaultDuration = Duration(minutes: 5);
  static AppReviewApi _api = AppReviewApi();

  //----------------------------------------------------------------------------
  // Public Interface
  //----------------------------------------------------------------------------

  /// Returns package name for application.
  static Future<String?> getAppId() => getBundleName();

  /// Returns package name for application.
  static Future<String?> getBundleName() async {
    if (_appBundle != null) {
      return _appBundle;
    }
    try {
      _appBundle = await _api.getBundleId();
      return _appBundle;
    } catch (e) {
      return null;
    }
  }

  /// Returns Apple ID for iOS application.
  ///
  /// If there is no such application in App Store - returns empty string.
  static Future<String?> getIosAppId({
    String? countryCode,
    String? bundleId,
  }) async {
    // If bundle name is not provided
    // then fetch and return the app ID from cache (if available)
    if (bundleId == null) {
      _appId ??= await getIosAppId(
        bundleId: await getBundleName(),
        countryCode: countryCode,
      );

      return _appId;
    }

    // Else fetch from AppStore
    final String id = bundleId;
    final String country = countryCode ?? _appCountry ?? '';
    String? appId;

    if (id.isNotEmpty) {
      try {
        appId = await _api.lookupAppId(id, country);
      } catch (e) {
        debugPrint('Error fetching app ID: $e');
      } finally {
        if (appId?.isNotEmpty == true) {
          debugPrint('Track ID: $appId');
        } else {
          debugPrint('Application with bundle $id is not found on App Store');
        }
      }
    }

    return appId ?? '';
  }

  /// Request review.
  ///
  /// Tells StoreKit / Play Store to ask the user to rate or review your app, if appropriate.
  /// Supported only in iOS 10.3+ and Android with Play Services installed (see [isRequestReviewAvailable]).
  ///
  /// Throws [AppReviewException] if request fails.
  static Future<void> requestReview({
    bool useAndroidTestMode = false,
  }) async {
    final result = await _api.requestReview(useAndroidTestMode);
    if (result != null && result.toLowerCase().contains("not available")) {
      throw AppReviewUnavailableException(result);
    }
  }

  /// Check if [requestReview] feature available.
  static Future<bool> isRequestReviewAvailable() async {
    if (Platform.isIOS || Platform.isAndroid || Platform.isMacOS) {
      try {
        return await _api.isRequestReviewAvailable();
      } catch (e) {
        return false;
      }
    }

    return false;
  }

  /// Open store page with action write review.
  ///
  /// Supported only for iOS, on Android [storeListing] will be executed.
  ///
  /// [appStoreId] - App ID for iOS App Store (e.g. 1234567890)
  /// [playStoreId] - Package name for Google Play Store (e.g. com.example.app) on Android.
  static Future<void> writeReview({
    String? appStoreId,
    String? playStoreId,
    bool useAndroidTestMode = false,
  }) async {
    if (Platform.isIOS || Platform.isMacOS) {
      await _openIosReview(
        appId: appStoreId,
        compose: true,
      );
      return;
    }

    if (Platform.isAndroid) {
      await _openAndroidReview(
        appId: playStoreId,
        useAndroidTestMode: useAndroidTestMode,
      );
      return;
    }
  }

  /// Navigates to Store Listing in Google Play/App Store.
  ///
  /// [appStoreId] - App ID for iOS App Store (e.g. 1234567890)
  /// [playStoreId] - Package name for Google Play Store (e.g. com.example.app) on Android.
  static Future<void> storeListing({
    String? appStoreId,
    String? playStoreId,
  }) async {
    if (Platform.isIOS || Platform.isMacOS) {
      await openAppStore(appId: appStoreId);
      return;
    }

    if (Platform.isAndroid) {
      await openGooglePlay(appId: playStoreId);
      return;
    }
  }

  //----------------------------------------------------------------------------
  // Helper methods
  //----------------------------------------------------------------------------

  static String? _appCountry;
  static String? _appBundle;
  static String? _appId;

  /// It would be great if I could add country code into AppStore lookup URL.
  /// Eg: AppReview.setCountryCode('jp');
  static void setCountryCode(String code) =>
      _appCountry = code.isEmpty ? null : code;

  /// Require app review for iOS
  static Future<void> _openIosReview({
    String? appId,
    bool compose = false,
  }) async {
    if (compose) {
      final id = appId ?? (await getIosAppId()) ?? '';
      try {
        await _api.openAppStoreReview(id);
      } catch (e) {
        throw AppReviewStoreListingFailedException(e.toString());
      }
      return;
    }

    try {
      final result = await _api.requestReview(false);
      if (result != null && result.toLowerCase().contains("not available")) {
        throw AppReviewUnavailableException(result);
      }
    } catch (e) {
      if (e is AppReviewException) rethrow;
      throw AppReviewRequestFailedException(e.toString());
    }
  }

  /// Require app review for Android
  static Future<void> _openAndroidReview(
      {String? appId, bool useAndroidTestMode = false}) async {
    try {
      final result = await _api.requestReview(useAndroidTestMode);
      if (result != null && result.toLowerCase().contains("not available")) {
        throw AppReviewUnavailableException(result);
      }
    } catch (e) {
      if (e is AppReviewException) rethrow;
      // If request fails, try opening store
      await openGooglePlay(appId: appId);
    }
  }

  /// Open in AppStore
  static Future<void> openAppStore({
    String? fallbackUrl,
    String? appId,
  }) async {
    final id = appId ?? await getIosAppId() ?? '';
    try {
      await _api.openStoreListing(id);
    } catch (e) {
      throw AppReviewStoreListingFailedException(e.toString());
    }
  }

  /// Open in GooglePlay
  static Future<void> openGooglePlay({
    String? fallbackUrl,
    String? appId,
  }) async {
    final bundle = appId ?? await getBundleName() ?? '';
    try {
      await _api.openStoreListing(bundle);
    } catch (e) {
      throw AppReviewStoreListingFailedException(e.toString());
    }
  }
}
