
import 'package:flutter/foundation.dart';

void setTargetPlatformForDesktop({TargetPlatform platform}) {
  TargetPlatform targetPlatform;
  targetPlatform = platform;
  debugDefaultTargetPlatformOverride = targetPlatform;
}
