import 'package:flutter/foundation.dart';

// The community SDK adds this enum value; using its name also compiles with
// the upstream Flutter SDK used for the Android, iOS and web builds.
bool get isHarmonyOS => !kIsWeb && defaultTargetPlatform.name == 'ohos';
