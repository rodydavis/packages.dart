import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(PigeonOptions(
  dartOut: 'lib/src/messages.g.dart',
  kotlinOut: 'android/src/main/kotlin/com/example/flutter_sms/Messages.g.kt',
  kotlinOptions: KotlinOptions(package: 'com.example.flutter_sms'),
  swiftOut: 'ios/flutter_sms/Sources/flutter_sms/Messages.g.swift',
))
@HostApi()
abstract class SmsHostApi {
  @async
  String sendSms(String message, List<String> recipients);

  @async
  bool canSendSms();
}
