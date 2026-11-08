import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../domain/models.dart';
import '../domain/widget_snapshot.dart';

export '../domain/widget_snapshot.dart' show widgetSnapshot;

class WidgetBridge {
  static const channel = MethodChannel('dev.kejian/widgets');
  static bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static Future<void> sync(ScheduleData data) async {
    if (!supported) return;
    await channel.invokeMethod<void>('sync', jsonEncode(widgetSnapshot(data)));
  }
}
