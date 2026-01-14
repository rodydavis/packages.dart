
# flutter_sms

[![pub package](https://img.shields.io/pub/v/flutter_sms.svg)](https://pub.dev/packages/flutter_sms)

Flutter Plugin for sending SMS and MMS on Android and iOS. If you send to more than one person, it will send as MMS. On iOS, if the number is an iPhone and iMessage is enabled, it will send as an iMessage.

## Features

- Send SMS/MMS to one or multiple recipients.
- Check if the device is capable of sending SMS.

- Catch errors when sending fails.

## Usage

### Install

Add `flutter_sms` as a dependency in your `pubspec.yaml` file.

```yaml
dependencies:
  flutter_sms: ^3.0.0
```

### Import

```dart
import 'package:flutter_sms/flutter_sms.dart';
```

### Example

```dart
void _sendSMS() async {
  List<String> recipients = ["1234567890", "5556787676"];
  String message = "This is a test message!";
  
  try {
     String result = await sendSMS(message: message, recipients: recipients);
     print(result);
  } catch (error) {
     print(error);
  }
}
```

### Check Capability

You can check if the current device is capable of sending SMS.

```dart
bool canSend = await canSendSMS();
if (!canSend) {
  print("Device cannot send SMS.");
}
```

### Launch SMS URL

Launch the SMS URL scheme directly.

```dart
await launchSms(message: "This is a test message!", number: "1234567890");
```

### Launch SMS URL (Multiple Recipients)

Launch the SMS URL scheme with multiple recipients.

```dart
await launchSmsMulti(message: "This is a test message!", numbers: ["1234567890", "5556787676"]);
```
