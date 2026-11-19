import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';

import 'runtime_platform.dart';

const _harmonyFiles = MethodChannel('dev.kejian/files');

class ScheduleFile {
  final String name;
  final Uint8List bytes;

  const ScheduleFile(this.name, this.bytes);
}

Future<ScheduleFile?> pickScheduleFile({
  required List<String> allowedExtensions,
  String dialogTitle = '选择课表文件',
}) async {
  if (isHarmonyOS) {
    final result = await _harmonyFiles.invokeMapMethod<String, dynamic>(
      'pick',
      allowedExtensions,
    );
    if (result == null) return null;
    return ScheduleFile(result['name'] as String, result['bytes'] as Uint8List);
  }

  final file = await FilePicker.pickFile(
    type: FileType.custom,
    allowedExtensions: allowedExtensions,
    dialogTitle: dialogTitle,
  );
  if (file == null) return null;
  final bytes = await _readFile(file);
  return ScheduleFile(file.name, bytes);
}

Future<Uint8List> _readFile(PlatformFile file) async {
  final builder = BytesBuilder();
  await for (final chunk in file.readAsByteStream()) {
    builder.add(chunk);
    if (builder.length > 20 * 1024 * 1024) {
      throw const FormatException('请选择 20 MB 以内的课表文件');
    }
  }
  return builder.takeBytes();
}

Future<Uri?> saveScheduleFile({
  required String fileName,
  required Uint8List bytes,
  required String mimeType,
  String dialogTitle = '保存文件',
}) async {
  if (isHarmonyOS) {
    final value = await _harmonyFiles.invokeMethod<String>('save', {
      'name': fileName,
      'bytes': bytes,
    });
    return value == null ? null : Uri.parse(value);
  }
  return FilePicker.saveFile(
    fileName: fileName,
    bytes: bytes,
    mimeType: mimeType,
    dialogTitle: dialogTitle,
  );
}
