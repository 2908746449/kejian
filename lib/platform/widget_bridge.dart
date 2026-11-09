import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../domain/models.dart';
import '../domain/widget_snapshot.dart';

export '../domain/widget_snapshot.dart' show widgetSnapshot;

class AndroidWidgetStatus {
  final bool registered, pinSupported;
  final int installedCount;
  const AndroidWidgetStatus({
    required this.registered,
    required this.pinSupported,
    required this.installedCount,
  });
}

class WidgetBridge {
  static const channel = MethodChannel('dev.kejian/widgets');
  static bool get isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  static bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static Future<void> sync(ScheduleData data) async {
    if (!supported) return;
    await channel.invokeMethod<void>('sync', jsonEncode(widgetSnapshot(data)));
  }

  static Future<AndroidWidgetStatus?> androidStatus() async {
    if (!isAndroid) return null;
    final value = await channel.invokeMapMethod<String, dynamic>('status');
    if (value == null) return null;
    return AndroidWidgetStatus(
      registered: value['registered'] == true,
      pinSupported: value['pinSupported'] == true,
      installedCount: value['installedCount'] as int,
    );
  }

  /// True means the launcher accepted the request, not that a widget was added.
  static Future<bool> requestPin({bool wide = false}) async =>
      isAndroid &&
      await channel.invokeMethod<bool>('requestPin', {
            'style': wide ? 'wide' : 'compact',
          }) ==
          true;
}
