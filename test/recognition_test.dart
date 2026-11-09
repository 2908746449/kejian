import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kejian/data/demo.dart';
import 'package:kejian/data/table_grid.dart';
import 'package:kejian/data/timetable_recognition.dart';
import 'package:kejian/domain/engine.dart';
import 'package:kejian/domain/models.dart';
import 'package:kejian/ui/recognition_review.dart';

RecognizedPage fixture({
  bool missingLabels = false,
  bool invalidWeek = false,
  bool ocr = false,
  String firstWeeks = '1-16周',
  String lastSchedule = '(9-10节)1-15周(单)',
  String otherHeader = '其他课程',
  String startDate = '2026-08-31',
}) {
  final boxes = <TextBox>[];
  void line(String text, double x, double y, {double size = 6}) {
    for (var i = 0; i < text.length; i++) {
      final punctuation = ',;'.contains(text[i]);
      boxes.add(
        TextBox(
          text[i],
          x + i * size,
          y + (punctuation ? 4 : 0),
          size - 1,
          punctuation ? 2 : 8,
        ),
      );
    }
  }

  line('2026-2027年第1学期', 5, 6);
  for (var d = 1; d <= 7; d++) {
    if (missingLabels && d == 1) continue;
    line('星期${"一二三四五六日"[d - 1]}', 90 + (d - 1) * 120, 28);
  }
  const labels = ['第一二节', '第三四节', '第五六节', '第七八节', '第九十十一节'];
  for (var r = 0; r < 5; r++) {
    if (missingLabels && (r == 0 || r == 4)) continue;
    for (var i = 0; i < labels[r].length; i++) {
      line(labels[r][i], 35, 70 + r * 80 + i * 9);
    }
  }
  line('课程甲/$firstWeeks/北101/教师甲,教师乙', 51, 65, size: 3);
  line('课程甲/$lastSchedule/北202/教师甲,教师乙', 411, 385, size: 2.5);
  line('课程乙/${invalidWeek ? "1-X周" : "2-16周(双)"}/南101/教师丙', 171, 225, size: 3);
  line('$otherHeader：课程丙★教师丁(共16周)/1-16周/无;', 5, 455, size: 4);
  line('注--本学期$startDate正式上课至2027-01-17结束，共20周.', 5, 478, size: 4);
  return RecognizedPage(
    number: 1,
    width: 900,
    height: 510,
    boxes: boxes,
    isOcr: missingLabels || ocr,
    horizontalLines: missingLabels ? [50, 130, 210, 290, 370, 450] : const [],
  );
}

void main() {
  test('spatial extraction merges courses and preserves rooms, parity and explicit periods', () {
    final result = parseTimetable([fixture()]);
    expect(result.courses.length, 3);
    expect(result.meetingCount, 3);
    expect(result.firstMonday, DateTime(2026, 8, 31));
    expect(result.weekCount, 20);
    final course = result.courses.firstWhere((c) => c.name == '课程甲');
    expect(course.teacher, '教师甲,教师乙');
    expect(course.meetings.map((m) => m.room), ['北101', '北202']);
    expect(course.meetings.last.startPeriod, 9);
    expect(course.meetings.last.endPeriod, 10);
    expect(course.meetings.last.weeks, [1, 3, 5, 7, 9, 11, 13, 15]);
    expect(
      result.courses.firstWhere((c) => c.name == '课程乙').meetings.single.weeks,
      [2, 4, 6, 8, 10, 12, 14, 16],
    );
    expect(result.unparsed, isEmpty);
  });
  test(
    'missing OCR labels are anchored to grid and inference is disclosed',
    () {
      final result = parseTimetable([fixture(missingLabels: true)]);
      expect(result.meetingCount, 3);
      final course = result.entries.firstWhere((e) => e.course.name == '课程甲');
      expect(course.course.meetings.first.weekday, 1);
      expect(course.course.meetings.first.startPeriod, 1);
      expect(course.warnings.any((s) => s.contains('推算')), true);
      expect(result.warnings.any((s) => s.contains('星期')), true);
    },
  );
  test('invalid weeks remain unresolved rather than acquiring a fabricated schedule', () {
    final result = parseTimetable([fixture(invalidWeek: true)]);
    expect(result.courses.any((c) => c.name == '课程乙'), false);
    expect(result.unparsed.single, contains('1-X周'));
  });
  test('OCR repairs unique numeric ranges and discloses each repair', () {
    final result = parseTimetable([
      fixture(ocr: true, firstWeeks: '216周', lastSchedule: '(910节)1一15周(单)'),
    ]);
    final entry = result.entries.singleWhere((e) => e.course.name == '课程甲');
    expect(entry.course.meetings.first.weeks, List.generate(15, (i) => i + 2));
    expect(entry.course.meetings.last.startPeriod, 9);
    expect(entry.course.meetings.last.endPeriod, 10);
    expect(entry.warnings.any((w) => w.contains('分隔符')), true);
    expect(entry.source, contains('216周'));
    final textOnly = parseTimetable([fixture(firstWeeks: '216周')]);
    expect(textOnly.unparsed.any((s) => s.contains('216周')), true);
  });
  test('OCR does not infer ranges from leading zeros', () {
    final result = parseTimetable([fixture(ocr: true, firstWeeks: '0116周')]);
    expect(result.unparsed.any((s) => s.contains('0116周')), true);
    expect(result.meetingCount, 2);
  });
  test(
    'OCR footer heading errors keep unscheduled courses outside the grid',
    () {
      final result = parseTimetable([fixture(ocr: true, otherHeader: '其作课程')]);
      expect(result.meetingCount, 3);
      expect(result.courses.singleWhere((c) => c.meetings.isEmpty).name, '课程丙');
      expect(result.unparsed, isEmpty);
    },
  );
  test('invalid calendar dates do not roll over to another month', () {
    final result = parseTimetable([fixture(startDate: '2026-02-31')]);
    expect(result.firstMonday, isNull);
    expect(result.warnings.any((s) => s.contains('不是有效日期')), true);
  });
  test('suspect OCR semester dates require manual correction', () {
    final result = parseTimetable([
      fixture(ocr: true, startDate: '2026-03-31'),
    ]);
    expect(result.firstMonday, isNull);
    expect(result.warnings.any((s) => s.contains('2026-03-31')), true);
    expect(
      parseTimetable([fixture(ocr: true)]).firstMonday,
      DateTime(2026, 8, 31),
    );
  });
  test(
    'duplicate pages do not duplicate meetings; pending courses survive backup',
    () {
      final result = parseTimetable([fixture(), fixture()]);
      expect(result.meetingCount, 3);
      final pending = result.courses.singleWhere((c) => c.meetings.isEmpty);
      final base = demoData(DateTime(2026, 11, 9));
      final data = base.copyWith(
        courses: [pending],
        exceptions: [],
        isDemo: false,
      );
      final restored = ScheduleData.decode(data.encode());
      expect(restored.courses.single.name, '课程丙');
      expect(lessonsInWeek(restored, 1), isEmpty);
    },
  );
  test('unknown layout retains source for correction', () {
    final result = parseTimetable([
      const RecognizedPage(
        number: 1,
        width: 200,
        height: 200,
        boxes: [TextBox('无法匹配布局', 2, 2, 60, 10)],
      ),
    ]);
    expect(result.courses, isEmpty);
    expect(result.unparsed.single, contains('无法匹配布局'));
  });
  test('grid detection ignores short text strokes', () {
    const width = 100, height = 100;
    final pixels = Uint8List(width * height * 4)
      ..fillRange(0, width * height * 4, 255);
    void dark(int x, int y) {
      final i = (y * width + x) * 4;
      pixels[i] = pixels[i + 1] = pixels[i + 2] = 0;
    }

    for (final y in [10, 30, 50, 80]) {
      for (var x = 5; x < 95; x++) {
        dark(x, y);
      }
    }
    for (final x in [5, 25, 50, 75, 94]) {
      for (var y = 10; y <= 80; y++) {
        dark(x, y);
      }
    }
    for (var x = 10; x < 20; x++) {
      dark(x, 60);
    }
    final grid = detectTableGrid(pixels, width, height, erase: true);
    expect(grid.horizontal, [10, 30, 50, 80]);
    expect(grid.vertical, [5, 25, 50, 75, 94]);
    expect(pixels[(60 * width + 15) * 4], 0);
    expect(pixels[(30 * width + 40) * 4], 255);
  });
  testWidgets(
    'review cancellation returns no import; preview is editable before save',
    (tester) async {
      final term = demoData(DateTime(2026, 11, 9)).semester;
      DocumentImportSelection? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  selected = await Navigator.of(context)
                      .push<DocumentImportSelection>(
                        MaterialPageRoute(
                          builder: (_) => RecognitionReview(
                            result: parseTimetable([fixture()]),
                            currentSemester: term,
                            fileName: 'example.pdf',
                          ),
                        ),
                      );
                },
                child: const Text('导入'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('导入'));
      await tester.pumpAndSettle();
      expect(find.text('识别结果核对'), findsOneWidget);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(selected, isNull);
      await tester.tap(find.text('导入'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('确认替换课表'));
      await tester.pumpAndSettle();
      expect(selected!.data.courses.length, 3);
      expect(selected!.data.semester.firstMonday, DateTime(2026, 8, 31));
    },
  );
}
