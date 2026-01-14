abstract class FlutterSmsPlatform {
  const FlutterSmsPlatform();

  Future<String> sendSMS({
    required String message,
    required List<String> recipients,
  });

  Future<bool> canSendSMS();

  Future<bool> launchSmsMulti(List<String> numbers, [String? body]);

  Future<bool> launchSms(String? number, [String? body]);
}
