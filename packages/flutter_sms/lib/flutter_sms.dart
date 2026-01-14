import 'dart:async';

import 'src/flutter_sms_io.dart'
    if (dart.library.js_interop) 'src/flutter_sms_web.dart';

final FlutterSms _flutterSms = FlutterSms();

/// Open SMS Dialog on iOS/Android/Web
Future<String> sendSMS({
  required String message,
  required List<String> recipients,
}) {
  return _flutterSms.sendSMS(
    message: message,
    recipients: recipients,
  );
}

/// Launch SMS Url Scheme on all platforms
Future<bool> launchSms({
  String? message,
  String? number,
}) {
  return _flutterSms.launchSms(number, message);
}

/// Launch SMS Url Scheme on all platforms
Future<bool> launchSmsMulti({
  required String message,
  required List<String> numbers,
}) {
  return _flutterSms.launchSmsMulti(numbers, message);
}

/// Check if you can send SMS on this platform
Future<bool> canSendSMS() {
  return _flutterSms.canSendSMS();
}
