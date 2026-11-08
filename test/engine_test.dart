import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kejian/domain/models.dart';
import 'package:kejian/domain/engine.dart';
import 'package:kejian/data/demo.dart';
import 'package:kejian/data/importer.dart';

void main() {
  final now = DateTime(2026, 11, 8, 12);
  late ScheduleData data;
  setUp(() => data = demoData(now));
  test('week arithmetic is date based and respects both boundaries', () {
    final s = data.semester;
    expect(s.weekOf(s.firstMonday), 1);
    expect(s.weekOf(addDays(s.firstMonday, -1)), 0);
    expect(s.weekOf(addDays(s.firstMonday, 6)), 1);
    expect(s.weekOf(addDays(s.firstMonday, 7)), 2);
    expect(s.weekOf(s.dateAt(20, 7)), 20);
    expect(s.weekOf(s.dateAt(21, 1)), 21);
  });
  test('odd-week classes are absent in even weeks', () {
    expect(
      lessonsInWeek(data, 9).where((l) => l.course.id == 'sport').length,
      1,
    );
    expect(
      lessonsInWeek(data, 10).where((l) => l.course.id == 'sport'),
      isEmpty,
    );
  });
  test(
    'cancel affects only one occurrence; removing exception restores it',
    () {
      final original = lessonsInWeek(data, 9).first;
      final changed = data.copyWith(
        exceptions: [
          LessonException(
            meetingId: original.meeting.id,
            originalDate: original.originalDate,
            cancelled: true,
          ),
        ],
      );
      changed.validate();
      expect(
        lessonsInWeek(changed, 9).length,
        lessonsInWeek(data, 9).length - 1,
      );
      expect(lessonsInWeek(changed, 10).length, lessonsInWeek(data, 10).length);
      expect(
        lessonsInWeek(changed.copyWith(exceptions: []), 9).length,
        lessonsInWeek(data, 9).length,
      );
    },
  );
  test(
    'moving across weeks removes original and adds exactly one destination',
    () {
      final original = lessonsInWeek(data, 9).first;
      final target = data.semester.dateAt(10, 7);
      final changed = data.copyWith(
        exceptions: [
          LessonException(
            meetingId: original.meeting.id,
            originalDate: original.originalDate,
            targetDate: target,
            startPeriod: 9,
            endPeriod: 10,
            room: '新教室',
          ),
        ],
      );
      changed.validate();
      expect(
        lessonsInWeek(changed, 9).where((l) => l.key == original.key),
        isEmpty,
      );
      final moved = lessonsInWeek(
        changed,
        10,
      ).singleWhere((l) => l.key == original.key);
      expect(moved.date, target);
      expect(moved.room, '新教室');
      expect(moved.startPeriod, 9);
      expect(moved.changed, isTrue);
      expect(
        lessonsInWeek(
          changed,
          10,
        ).where((l) => l.meeting.id == original.meeting.id).length,
        2,
      );
    },
  );
  test('next lesson includes active course, then skips ended lessons', () {
    final lesson = lessonsInWeek(data, 9).first;
    expect(
      nextLesson(
        data,
        lesson.start(data.semester).add(const Duration(minutes: 5)),
      )?.key,
      lesson.key,
    );
    expect(nextLesson(data, lesson.end(data.semester))?.key, isNot(lesson.key));
    expect(nextLesson(data, data.semester.dateAt(21, 1)), isNull);
  });
  test('time conflicts include intersecting periods only on the same date', () {
    final original = lessonsInWeek(data, 9).first;
    final overlapCourse = Course(
      id: 'new',
      name: '冲突课程',
      teacher: '',
      note: '',
      color: 1,
      meetings: [
        Meeting(
          id: 'new-m',
          weekday: 1,
          startPeriod: 2,
          endPeriod: 3,
          weeks: [9],
          room: '',
        ),
      ],
    );
    final combined = data.copyWith(courses: [...data.courses, overlapCourse]);
    expect(
      conflictKeys(lessonsInWeek(combined, 9)).contains(original.key),
      isTrue,
    );
    expect(conflictKeys(lessonsInWeek(combined, 10)), isEmpty);
  });
  test('backup restores every field including exceptions and preferences', () {
    final original = lessonsInWeek(data, 9).first;
    data = data.copyWith(
      showWeekends: false,
      exceptions: [
        LessonException(
          meetingId: original.meeting.id,
          originalDate: original.originalDate,
          cancelled: true,
        ),
      ],
    );
    final restored = ScheduleData.decode(data.encode());
    expect(restored.toJson(), data.toJson());
  });
  test('reject corrupt, unknown-version and orphaned backups', () {
    expect(
      () => ScheduleData.decode('{"schemaVersion":2}'),
      throwsFormatException,
    );
    expect(() => ScheduleData.decode('not json'), throwsFormatException);
    final json = data.toJson();
    json['exceptions'] = [
      LessonException(
        meetingId: 'missing',
        originalDate: now,
        cancelled: true,
      ).toJson(),
    ];
    expect(() => ScheduleData.decode(jsonEncode(json)), throwsFormatException);
  });
  test(
    'malformed times, duplicate IDs and invalid custom weeks are rejected',
    () {
      expect(() => timeMinutes('24:10'), throwsFormatException);
      expect(() => timeMinutes('08:60'), throwsFormatException);
      expect(() => parseWeeks('16-1', 20), throwsFormatException);
      expect(() => parseWeeks('0,1', 20), throwsFormatException);
      expect(parseWeeks('1-3,3,5，7', 20), [1, 2, 3, 5, 7]);
      expect(
        () => data
            .copyWith(courses: [data.courses.first, data.courses.first])
            .validate(),
        throwsFormatException,
      );
    },
  );
  test('CSV template groups same course and preserves odd weeks', () {
    final imported = coursesFromCsv(csvExample, data.semester);
    expect(imported.length, 2);
    expect(imported.first.meetings.length, 2);
    expect(imported.first.meetings.last.weeks, [1, 3, 5, 7, 9, 11, 13, 15]);
  });
  test('CSV handles BOM, quoted commas, escaped quotes and embedded newlines', () {
    final text =
        '\uFEFF$csvHeader\r\n"设计,实践",林老师,203,1,1,2,"1,3,5",2,"带""纸""\n和笔"\r\n';
    final imported = coursesFromCsv(text, data.semester);
    expect(imported.single.name, '设计,实践');
    expect(imported.single.note, '带"纸"\n和笔');
    expect(() => readCsv('"未闭合'), throwsFormatException);
  });
  test('CSV errors include source row and are not partially applied', () {
    expect(
      () => coursesFromCsv('$csvHeader\n课程,教师,教室,8,1,2,1-16,1,', data.semester),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('第 2 行'),
        ),
      ),
    );
    expect(data.courses.length, 7);
  });
}
