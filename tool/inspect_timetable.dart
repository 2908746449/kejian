// Local diagnostic tool. Input files and extracted data are never bundled.
// dart run tool/inspect_timetable.dart input.pdf result.json [boxes.json]
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:pdfrx_engine/pdfrx_engine.dart';

import 'package:kejian/data/timetable_recognition.dart';
import 'package:kejian/data/demo.dart';
import 'package:kejian/domain/models.dart';

Future<void> main(List<String> args) async {
  if (args.length < 2) {
    throw ArgumentError('Provide an input PDF and an output JSON path.');
  }
  final pages = <RecognizedPage>[];
  if (args[0].endsWith('.json')) {
    final values = jsonDecode(await File(args[0]).readAsString()) as List;
    for (final value in values) {
      final v = Map<String, dynamic>.from(value);
      pages.add(
        RecognizedPage(
          number: v['number'] as int,
          width: (v['width'] as num).toDouble(),
          height: (v['height'] as num).toDouble(),
          boxes: (v['boxes'] as List)
              .map((b) => TextBox.fromJson(Map<String, dynamic>.from(b)))
              .toList(),
          isOcr: v['isOcr'] == true,
          horizontalLines: (v['horizontalLines'] as List? ?? [])
              .map((n) => (n as num).toDouble())
              .toList(),
        ),
      );
    }
  } else {
    await pdfrxInitialize(tmpPath: Directory.systemTemp.path);
    final doc = await PdfDocument.openFile(
      args[0],
      passwordProvider: () async => null,
    );
    try {
      for (final page in doc.pages) {
        final text = await page.loadText();
        final boxes = <TextBox>[];
        if (text != null) {
          for (
            var i = 0;
            i < math.min(text.fullText.length, text.charRects.length);
            i++
          ) {
            final rect = text.charRects[i].rotate(page.rotation.index, page);
            if (rect.isEmpty || text.fullText[i].trim().isEmpty) continue;
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
        pages.add(
          RecognizedPage(
            number: page.pageNumber,
            width: page.width,
            height: page.height,
            boxes: boxes,
          ),
        );
      }
    } finally {
      await doc.dispose();
    }
  }
  final result = parseTimetable(pages);
  final base = demoData(DateTime(2026, 11, 9)).semester;
  final data = ScheduleData(
    semester: Semester(
      name: result.semesterName ?? base.name,
      firstMonday: result.firstMonday ?? base.firstMonday,
      weekCount: result.weekCount ?? base.weekCount,
      periods: base.periods,
    ),
    courses: result.courses,
  );
  data.validate();
  await File(args[1]).writeAsString(data.encode());
  if (args.length > 2) {
    await File(args[2]).writeAsString(
      jsonEncode([
        for (final p in pages)
          {
            'number': p.number,
            'width': p.width,
            'height': p.height,
            'boxes': [
              for (final b in p.boxes)
                {
                  'text': b.text,
                  'x': b.x,
                  'y': b.y,
                  'width': b.width,
                  'height': b.height,
                },
            ],
          },
      ]),
    );
  }
  stdout.writeln(
    '${result.courses.length} courses, ${result.meetingCount} meetings, ${result.unparsed.length} unparsed',
  );
  for (final c in result.courses) {
    stdout.writeln(
      '${c.name} / ${c.teacher}: ${c.meetings.map((m) => 'D${m.weekday} ${m.startPeriod}-${m.endPeriod} W${formatWeeks(m.weeks)} ${m.room}').join('; ')}',
    );
  }
  for (final item in result.unparsed) {
    stdout.writeln('UNPARSED: $item');
  }
}
