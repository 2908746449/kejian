import 'package:flutter/services.dart';

import '../data/timetable_recognition.dart';

const _channel = MethodChannel('dev.kejian/recognition');

Future<List<TextBox>> recognizeImage(Uint8List bytes) async {
  try {
    final result = await _channel.invokeListMethod<dynamic>('recognize', bytes);
    return (result ?? [])
        .map((b) => TextBox.fromJson(Map<String, dynamic>.from(b)))
        .toList();
  } on MissingPluginException {
    throw const FormatException('此平台暂不支持图片识别，请使用 Android、iOS 或网页版。');
  } on PlatformException catch (e) {
    throw FormatException(e.message ?? '图片识别失败，请换一张清晰完整的课表。');
  }
}

Future<void> releaseRecognizer() async {}
