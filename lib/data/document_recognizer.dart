import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:pdfrx/pdfrx.dart';
import 'package:flutter/foundation.dart';

import '../platform/ocr.dart';
import 'timetable_recognition.dart';
import 'table_grid.dart';

typedef RecognitionProgress = void Function(String stage);

/// All bytes are processed locally; PDF text is preferred to OCR.
Future<RecognitionResult> recognizeTimetableDocument(
  Uint8List bytes,
  String name, {
  RecognitionProgress? onProgress,
}) async {
  final pages = <RecognizedPage>[];
  try {
    if (name.toLowerCase().endsWith('.pdf')) {
      onProgress?.call('正在读取 PDF…');
      await pdfrxFlutterInitialize();
      final doc = await PdfDocument.openData(
        bytes,
        passwordProvider: () async => null,
      );
      try {
        if (doc.pages.length > 5) {
          throw const FormatException('每次最多识别 5 页 PDF，请先选取课表页面。');
        }
        for (final page in doc.pages) {
          onProgress?.call('正在识别第 ${page.pageNumber}/${doc.pages.length} 页…');
          final text = await page.loadText();
          final boxes = <TextBox>[];
          if (text != null) {
            for (
              var i = 0;
              i < math.min(text.fullText.length, text.charRects.length);
              i++
            ) {
              final r = text.charRects[i];
              if (text.fullText[i].trim().isEmpty || r.isEmpty) continue;
              final rect = r.rotate(page.rotation.index, page);
              boxes.add(
                TextBox(
                  text.fullText[i],
                  rect.left,
                  page.height - rect.top,
                  rect.width,
                  rect.height,
                ),
              );
            }
          }
          final textPage = RecognizedPage(
            number: page.pageNumber,
            width: page.width,
            height: page.height,
            boxes: boxes,
          );
          // Watermarks alone are not a useful text layer. Require table anchors.
          if (boxes.length >= 40 &&
              parseTimetable([textPage]).entries.isNotEmpty) {
            pages.add(textPage);
          } else {
            onProgress?.call('第 ${page.pageNumber} 页正在进行本地图片识别…');
            final scale = 3200 / math.max(page.width, page.height);
            final raster = await page.render(
              fullWidth: page.width * scale,
              fullHeight: page.height * scale,
            );
            if (raster == null) {
              throw const FormatException('无法渲染 PDF 页面，请检查文件是否损坏。');
            }
            try {
              final image = await raster.createImage();
              try {
                pages.add(await _recognizeRaster(image, page.pageNumber));
              } finally {
                image.dispose();
              }
            } finally {
              raster.dispose();
            }
          }
        }
      } finally {
        await doc.dispose();
      }
    } else {
      onProgress?.call('正在本地识别图片，可能需要片刻…');
      final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      // ImageDescriptor.width is unavailable on Flutter Web. The codec callback
      // exposes intrinsic dimensions on every platform and owns the buffer.
      final codec = await ui.instantiateImageCodecWithSize(
        buffer,
        getTargetSize: (width, height) {
          if (width * height > 48000000) {
            throw const FormatException('图片分辨率过大，请缩小到 4800 万像素以内。');
          }
          final ratio = 3200 / math.max(width, height);
          final scale = kIsWeb ? math.min(1.0, ratio) : ratio;
          return ui.TargetImageSize(
            width: (width * scale).round(),
            height: (height * scale).round(),
          );
        },
      );
      try {
        final frame = await codec.getNextFrame();
        try {
          if (math.max(frame.image.width, frame.image.height) >= 3200) {
            pages.add(await _recognizeRaster(frame.image, 1));
          } else {
            // Enlarge small screenshots consistently; Web codecs disallow
            // upscaling while decoding, so draw to the target size explicitly.
            final scale =
                3200 / math.max(frame.image.width, frame.image.height);
            final width = (frame.image.width * scale).round();
            final height = (frame.image.height * scale).round();
            final recorder = ui.PictureRecorder();
            ui.Canvas(recorder).drawImageRect(
              frame.image,
              ui.Rect.fromLTWH(
                0,
                0,
                frame.image.width.toDouble(),
                frame.image.height.toDouble(),
              ),
              ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
              ui.Paint()..filterQuality = ui.FilterQuality.high,
            );
            final picture = recorder.endRecording();
            try {
              final scaled = await picture.toImage(width, height);
              try {
                pages.add(await _recognizeRaster(scaled, 1));
              } finally {
                scaled.dispose();
              }
            } finally {
              picture.dispose();
            }
          }
        } finally {
          frame.image.dispose();
        }
      } finally {
        codec.dispose();
      }
    }
    onProgress?.call('正在整理课程与周次…');
    if (pages.fold<int>(0, (n, p) => n + p.boxes.length) > 80000) {
      throw const FormatException('文字过多，请仅选择课表页面。');
    }
    return parseTimetable(pages);
  } on FormatException {
    rethrow;
  } catch (error, stack) {
    if (kDebugMode) {
      debugPrint('Document recognition failed: $error\n$stack');
    }
    throw const FormatException('无法识别文件，请使用未加密的 PDF 或清晰的 PNG/JPG 课表图片。');
  } finally {
    try {
      await releaseRecognizer();
    } catch (_) {
      /* Preserve the original read/recognition error. */
    }
  }
}

Future<RecognizedPage> _recognizeRaster(ui.Image image, int number) async {
  final raw = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  if (raw == null) throw const FormatException('无法读取图片像素。');
  final pixels = Uint8List.fromList(raw.buffer.asUint8List());
  final grid = detectTableGrid(pixels, image.width, image.height, erase: true);
  final completer = Completer<ui.Image>();
  ui.decodeImageFromPixels(
    pixels,
    image.width,
    image.height,
    ui.PixelFormat.rgba8888,
    completer.complete,
  );
  final clean = await completer.future;
  try {
    final png = await clean.toByteData(format: ui.ImageByteFormat.png);
    if (png == null) throw const FormatException('图片转换失败。');
    return RecognizedPage(
      number: number,
      width: image.width.toDouble(),
      height: image.height.toDouble(),
      boxes: await recognizeImage(png.buffer.asUint8List()).timeout(
        const Duration(seconds: 90),
        onTimeout: () => throw const FormatException('识别超时，请换一张更清晰的课表重试。'),
      ),
      isOcr: true,
      horizontalLines: grid.horizontal,
    );
  } finally {
    clean.dispose();
  }
}
