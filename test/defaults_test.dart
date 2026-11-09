import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kejian/data/defaults.dart';
import 'package:kejian/data/demo.dart';
import 'package:kejian/data/repository.dart';
import 'package:kejian/domain/engine.dart';
import 'package:kejian/domain/models.dart';
import 'package:kejian/main.dart';
import 'package:kejian/platform/widget_bridge.dart';

ScheduleData legacyData() {
  final data = demoData(DateTime(2026, 11, 9));
  final json = data.toJson()..remove('defaultsVersion');
  (json['semester'] as Map)['periods'] = [
    for (final (index, start, end) in [
      (1, '08:00', '08:45'),
      (2, '08:55', '09:40'),
      (3, '10:00', '10:45'),
      (4, '10:55', '11:40'),
      (5, '14:00', '14:45'),
      (6, '14:55', '15:40'),
      (7, '16:00', '16:45'),
      (8, '16:55', '17:40'),
      (9, '19:00', '19:45'),
      (10, '19:55', '20:40'),
    ])
      Period(index, start, end).toJson(),
  ];
  return ScheduleData.decode(jsonEncode(json)).copyWith(
    isDemo: false,
    showWeekends: false,
    exceptions: [
      LessonException(
        meetingId: 'math-1',
        originalDate: data.semester.dateAt(1, 1),
        cancelled: true,
      ),
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Kaili defaults drive lesson boundaries and the native snapshot', () {
    final data = demoData(DateTime(2026, 11, 9));
    data.validate();
    final periods = data.semester.periods;
    expect(periods.length, 10);
    expect(periods.first.start, '08:20');
    expect(periods[3].end, '11:45');
    expect(periods[4].start, '14:00');
    expect(periods[7].end, '17:25');
    expect(periods[8].start, '19:00');
    expect(periods.last.end, '20:35');
    for (final period in periods) {
      expect(timeMinutes(period.end) - timeMinutes(period.start), 45);
    }
    for (final first in [0, 2, 4, 6, 8]) {
      expect(
        timeMinutes(periods[first + 1].start) - timeMinutes(periods[first].end),
        5,
      );
    }
    for (final first in [1, 5]) {
      expect(
        timeMinutes(periods[first + 1].start) - timeMinutes(periods[first].end),
        15,
      );
    }
    final monday = data.semester.dateAt(9, 1);
    final beforeEnd = DateTime(monday.year, monday.month, monday.day, 9, 54);
    final atEnd = DateTime(monday.year, monday.month, monday.day, 9, 55);
    expect(nextLesson(data, beforeEnd)!.course.id, 'math');
    expect(nextLesson(data, atEnd)!.course.id, 'design');
    final lessons = widgetSnapshot(data)['lessons'] as List;
    final morning = lessons.first;
    expect(morning['start'], '08:20');
    expect(morning['end'], '09:55');
    final afternoon = lessons.firstWhere((l) => l['name'] == '程序设计');
    expect(afternoon['start'], '14:00');
    expect(afternoon['end'], '15:35');
  });

  test(
    'old backups upgrade once and preserve courses, exceptions and settings',
    () {
      final old = legacyData();
      expect(old.defaultsVersion, 1);
      final updated = upgradeScheduleDefaults(old);
      updated.validate();
      expect(usesKailiUniversityPeriods(updated.semester.periods), isTrue);
      final expected = old.toJson();
      expected['defaultsVersion'] = currentDefaultsVersion;
      (expected['semester'] as Map)['periods'] = kailiUniversityPeriods
          .map((p) => p.toJson())
          .toList();
      expect(updated.toJson(), expected);
      final restored = ScheduleData.decode(updated.encode());
      expect(upgradeScheduleDefaults(restored), same(restored));
      expect(old.semester.periods.first.start, '08:00');
    },
  );

  test(
    'upgrade respects customized times and a manually restored old timetable',
    () {
      final old = legacyData();
      final custom = old.copyWith(
        semester: Semester(
          name: old.semester.name,
          firstMonday: old.semester.firstMonday,
          weekCount: old.semester.weekCount,
          periods: [
            const Period(1, '08:10', '08:45'),
            ...old.semester.periods.skip(1),
          ],
        ),
      );
      final updated = upgradeScheduleDefaults(custom);
      expect(updated.semester, same(custom.semester));
      expect(updated.defaultsVersion, currentDefaultsVersion);
      final manual = updated.copyWith(semester: old.semester);
      expect(upgradeScheduleDefaults(manual), same(manual));
    },
  );

  testWidgets(
    'opening an old document saves new defaults and syncs widget times',
    (tester) async {
      final repository = MemoryRepository(legacyData());
      final payloads = <Map<String, dynamic>>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(WidgetBridge.channel, (call) async {
        if (call.method == 'sync') {
          payloads.add(
            jsonDecode(call.arguments as String) as Map<String, dynamic>,
          );
        }
        return null;
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(WidgetBridge.channel, null),
      );
      await tester.pumpWidget(
        KejianApp(repository: repository, clock: () => DateTime(2026, 11, 9)),
      );
      await tester.pumpAndSettle();
      expect(repository.value!.semester.periods.first.start, '08:20');
      expect(repository.value!.defaultsVersion, currentDefaultsVersion);
      expect(repository.value!.courses.length, 7);
      expect(repository.value!.exceptions.single.cancelled, isTrue);
      final lesson = (payloads.single['lessons'] as List).firstWhere(
        (l) => (l['id'] as String).startsWith('math-1@'),
      );
      expect(lesson['start'], '08:20');
      expect(lesson['end'], '09:55');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('Kaili preset is editable and takes effect only after saving', (
    tester,
  ) async {
    final repository = MemoryRepository(
      legacyData().copyWith(defaultsVersion: currentDefaultsVersion),
    );
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(WidgetBridge.channel, (_) async => null);
    addTearDown(
      () => messenger.setMockMethodCallHandler(WidgetBridge.channel, null),
    );
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      KejianApp(repository: repository, clock: () => DateTime(2026, 11, 9)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('设置').last);
    await tester.pumpAndSettle();
    Future<void> selectPreset() async {
      final term = find.text(repository.value!.semester.name);
      await tester.ensureVisible(term);
      await tester.tap(term);
      await tester.pumpAndSettle();
      final preset = find.text('使用凯里学院作息');
      await tester.ensureVisible(preset);
      await tester.tap(preset);
      await tester.pumpAndSettle();
    }

    await selectPreset();
    expect(repository.value!.semester.periods.first.start, '08:00');
    await tester.tap(find.byTooltip('关闭'));
    await tester.pumpAndSettle();
    expect(repository.value!.semester.periods.first.start, '08:00');
    await selectPreset();
    await tester.tap(find.text('保存设置'));
    await tester.pumpAndSettle();
    expect(
      usesKailiUniversityPeriods(repository.value!.semester.periods),
      isTrue,
    );
    expect(find.textContaining('凯里学院作息'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
