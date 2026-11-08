import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kejian/data/repository.dart';
import 'package:kejian/domain/agenda.dart';
import 'package:kejian/domain/engine.dart';
import 'package:kejian/domain/models.dart';
import 'package:kejian/main.dart';
import 'package:kejian/platform/widget_bridge.dart';

ScheduleData fixture() => ScheduleData(
  semester: Semester(
    name: '测试学期',
    firstMonday: DateTime(2026, 11, 9),
    weekCount: 2,
    periods: const [
      Period(1, '08:00', '09:00'),
      Period(2, '10:00', '11:00'),
      Period(3, '14:00', '15:00'),
      Period(4, '16:00', '17:00'),
    ],
  ),
  courses: [
    for (var day = 1; day <= 2; day++)
      for (var slot = 1; slot <= (day == 1 ? 4 : 3); slot++)
        Course(
          id: '$day-$slot',
          name: '课程$day-$slot',
          teacher: '',
          note: '',
          color: 0,
          meetings: [
            Meeting(
              id: 'm$day-$slot',
              weekday: day,
              startPeriod: slot,
              endPeriod: slot,
              weeks: [1, 2],
              room: 'A$slot',
            ),
          ],
        ),
  ],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final data = fixture();
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(WidgetBridge.channel, (_) async => null);
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(WidgetBridge.channel, null);
  });

  test('four courses become three then two then one following card', () {
    expect(agendaPreview(data, DateTime(2026, 11, 9, 7)).following.length, 3);
    expect(agendaPreview(data, DateTime(2026, 11, 9, 9)).following.length, 2);
    final one = agendaPreview(data, DateTime(2026, 11, 9, 11));
    expect(one.following.single.course.name, '课程1-4');
    expect(one.tomorrow, isFalse);
  });
  test(
    'last course previews tomorrow; after the day ends main is not duplicated',
    () {
      final last = agendaPreview(data, DateTime(2026, 11, 9, 15));
      expect(last.next!.course.name, '课程1-4');
      expect(last.following.length, 3);
      expect(last.tomorrow, isTrue);
      final ended = agendaPreview(data, DateTime(2026, 11, 9, 17));
      expect(ended.next!.course.name, '课程2-1');
      expect(
        ended.following.map((l) => l.key),
        isNot(contains(ended.next!.key)),
      );
      expect(ended.following.length, 2);
      expect(
        agendaPreview(data, DateTime(2026, 11, 10, 15)).following,
        isEmpty,
      );
    },
  );
  test('snapshot exports complete semester with cancellations and moved room/time resolved', () {
    final original = lessonsInWeek(data, 1).first;
    final moved = data.copyWith(
      exceptions: [
        LessonException(
          meetingId: original.meeting.id,
          originalDate: original.date,
          targetDate: DateTime(2026, 11, 22),
          startPeriod: 4,
          endPeriod: 4,
          room: '新教室',
        ),
        LessonException(
          meetingId: 'm1-2',
          originalDate: DateTime(2026, 11, 9),
          cancelled: true,
        ),
      ],
    );
    moved.validate();
    final payload = widgetSnapshot(moved);
    final lessons = payload['lessons'] as List;
    expect(lessons.length, 13);
    final override = lessons.singleWhere((l) => l['id'] == original.key);
    expect(override['date'], '2026-11-22');
    expect(override['start'], '16:00');
    expect(override['room'], '新教室');
    expect(override['changed'], isTrue);
    expect(lessons.any((l) => l['id'] == 'm1-2@2026-11-09'), isFalse);
    expect(lessons.where((l) => l['date'] == '2026-11-16').length, 4);
    expect(
      (widgetSnapshot(data.copyWith(courses: []))['lessons'] as List),
      isEmpty,
    );
  });
  test('native bridge sends versioned JSON', () async {
    MethodCall? received;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(WidgetBridge.channel, (call) async {
          received = call;
          return null;
        });
    await WidgetBridge.sync(data);
    expect(received?.method, 'sync');
    expect(jsonDecode(received!.arguments as String)['lessons'].length, 14);
  });
  test(
    'custom weeks accept spaces, commas, ranges, tabs and reject bad weeks',
    () {
      expect(parseWeeks('1 3 5 8-12', 20), [1, 3, 5, 8, 9, 10, 11, 12]);
      expect(parseWeeks(' 1 - 3, 5，7\t9 ', 20), [1, 2, 3, 5, 7, 9]);
      for (final source in ['', '0 3', '1 21', '5-2', '1 x']) {
        expect(() => parseWeeks(source, 20), throwsFormatException);
      }
    },
  );
  testWidgets(
    'single following class expands and last class switches to tomorrow',
    (tester) async {
      tester.view.physicalSize = const Size(390, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        KejianApp(
          repository: MemoryRepository(data),
          clock: () => DateTime(2026, 11, 9, 11),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('今日后续'), findsOneWidget);
      expect(find.text('今天还有 1 门课'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        KejianApp(
          repository: MemoryRepository(data),
          clock: () => DateTime(2026, 11, 9, 15),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('明天的安排'), findsOneWidget);
      expect(find.byType(ListView), findsWidgets);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('widget sync failure does not roll back a saved course', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          WidgetBridge.channel,
          (_) async => throw PlatformException(code: 'APP_GROUP'),
        );
    final repository = MemoryRepository(data.copyWith(courses: []));
    await tester.pumpWidget(
      KejianApp(repository: repository, clock: () => DateTime(2026, 11, 9, 7)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('添加课程'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '课程名称'), '已保存的课程');
    await tester.tap(find.text('保存课程'));
    await tester.pumpAndSettle();
    expect(repository.value!.courses.single.name, '已保存的课程');
    expect(find.textContaining('小组件同步失败'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
