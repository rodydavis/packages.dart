import 'dart:async';

import 'package:url_launcher/url_launcher.dart';

import 'flutter_sms_interface.dart';
import 'user_agent/web.dart';

class FlutterSms extends FlutterSmsPlatform {
  @override
  Future<String> sendSMS({
    required String message,
    required List<String> recipients,
  }) async {
    bool messageSent = await launchSmsMulti(recipients, message);
    if (messageSent) return 'Message Sent!';
    return 'Error Sending Message!';
  }

  @override
  Future<bool> canSendSMS() => Future.value(true);

  @override
  Future<bool> launchSmsMulti(List<String> numbers, [String? body]) {
    if (numbers.length == 1) {
      return launchSms(numbers.first, body);
    }
    String phones = numbers.join(';');
    if (body != null) {
      final encodedBody = Uri.encodeComponent(body);
      return launchUrl(
          Uri.parse('sms:/open?addresses=$phones$separator}body=$encodedBody'));
    }
    return launchUrl(Uri.parse('sms:/open?addresses=$phones'));
  }

  @override
  Future<bool> launchSms(String? number, [String? body]) {
    // ignore: parameter_assignments
    number ??= '';
    if (body != null) {
      final encodedBody = Uri.encodeComponent(body);
      return launchUrl(Uri.parse('sms:/$number$separator}body=$encodedBody'));
    }
    return launchUrl(Uri.parse('sms:/$number'));
  }

  String get separator => isCupertino() ? '&' : '?';
}
