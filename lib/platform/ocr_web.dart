import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import '../data/timetable_recognition.dart';

@JS('kejianRecognizeImage')
external JSPromise<JSString> _recognize(JSUint8Array bytes);
@JS('kejianReleaseRecognizer')
external JSPromise<JSAny?> _release();

Future<List<TextBox>> recognizeImage(Uint8List bytes) async {
  try {
    final result =
        jsonDecode((await _recognize(bytes.toJS).toDart).toDart) as List;
    return result
        .map((b) => TextBox.fromJson(Map<String, dynamic>.from(b)))
        .toList();
  } catch (_) {
    throw const FormatException('图片识别失败，请保持页面打开，或换一张清晰完整的课表重试。');
  }
}

Future<void> releaseRecognizer() async {
  await _release().toDart;
}
