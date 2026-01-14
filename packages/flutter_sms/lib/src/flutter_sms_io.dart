import 'dart:async';

import 'package:flutter_sms/src/messages.g.dart';
import 'package:url_launcher/url_launcher.dart';

import 'flutter_sms_interface.dart';
import 'user_agent/io.dart';

class FlutterSms extends FlutterSmsPlatform {
  final SmsHostApi _api = SmsHostApi();

  ///
  ///
  Future<String> sendSMS({
    required String message,
    required List<String> recipients,
  }) {
    return _api.sendSms(message, recipients);
  }

  Future<bool> canSendSMS() {
    return _api.canSendSms();
  }

  Future<bool> launchSmsMulti(List<String> numbers, [String? body]) {
    if (numbers.length == 1) {
      return launchSms(numbers.first, body);
    }
    String _phones = numbers.join(';');
    if (body != null) {
      final _body = Uri.encodeComponent(body);
      return launchUrl(
          Uri.parse('sms:/open?addresses=$_phones${separator}body=$_body'));
    }
    return launchUrl(Uri.parse('sms:/open?addresses=$_phones'));
  }

  Future<bool> launchSms(String? number, [String? body]) {
    // ignore: parameter_assignments
    number ??= '';
    if (body != null) {
      final _body = Uri.encodeComponent(body);
      return launchUrl(Uri.parse('sms:/$number${separator}body=$_body'));
    }
    return launchUrl(Uri.parse('sms:/$number'));
  }

  String get separator => isCupertino() ? '&' : '?';
}
