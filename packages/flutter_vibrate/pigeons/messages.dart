import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/messages.g.dart',
    dartPackageName: 'flutter_vibrate',
    dartOptions: DartOptions(),
    kotlinOut: 'android/src/main/kotlin/flutter/plugins/vibrate/Messages.g.kt',
    kotlinOptions: KotlinOptions(package: 'flutter.plugins.vibrate'),
    // We're keeping the Java implementation as per plan, but Pigeon prefers Kotlin by default
    // or specific Java options. The plan said Java. Let's configure for Java since existing code is Java.
    javaOut: 'android/src/main/java/flutter/plugins/vibrate/Messages.java',
    javaOptions: JavaOptions(package: 'flutter.plugins.vibrate'),
    swiftOut: 'ios/Classes/Messages.g.swift',
    swiftOptions: SwiftOptions(),
  ),
)
@HostApi()
abstract class VibrateApi {
  bool canVibrate();
  void vibrate(int duration);
  void impact();
  void selection();
  void success();
  void warning();
  void error();
  void heavy();
  void medium();
  void light();
}
