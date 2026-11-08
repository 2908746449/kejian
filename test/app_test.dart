import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kejian/main.dart';
import 'package:kejian/data/demo.dart';
import 'package:kejian/data/repository.dart';
import 'package:kejian/domain/models.dart';

void main() {
  final now = DateTime(2026, 11, 8, 12);
  Future<void> start(
    WidgetTester tester,
    ScheduleRepository repository, {
    Size size = const Size(390, 844),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      KejianApp(repository: repository, clock: () => now),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('mobile layout opens, switches weeks and navigates all tabs', (
    tester,
  ) async {
    await start(tester, MemoryRepository(demoData(now)));
    expect(find.text('课间'), findsOneWidget);
    expect(find.text('第 9 周'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('下一周'));
    await tester.pumpAndSettle();
    expect(find.text('第 10 周'), findsOneWidget);
    await tester.tap(find.text('课程').last);
    await tester.pumpAndSettle();
    expect(find.text('导入课表'), findsOneWidget);
    await tester.tap(find.text('设置').last);
    await tester.pumpAndSettle();
    expect(find.text('导出完整备份'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('course form saves data that survives a fresh app instance', (
    tester,
  ) async {
    final repository = MemoryRepository(
      demoData(now).copyWith(courses: [], isDemo: false),
    );
    await start(tester, repository);
    await tester.tap(find.byTooltip('添加课程'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '课程名称'), '离散数学');
    await tester.tap(find.text('保存课程'));
    await tester.pumpAndSettle();
    expect(repository.value!.courses.single.name, '离散数学');
    await tester.pumpWidget(const SizedBox());
    await start(tester, repository);
    expect(find.text('离散数学'), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('desktop layout is usable and uses the sidebar', (tester) async {
    await start(
      tester,
      MemoryRepository(demoData(now)),
      size: const Size(1440, 1000),
    );
    expect(find.text('我的课表'), findsOneWidget);
    await tester.tap(find.text('课程管理'));
    await tester.pumpAndSettle();
    expect(find.text('下载 CSV 模板'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('storage failure leaves the previous document intact', (
    tester,
  ) async {
    final repository = _FailingRepository(
      demoData(now).copyWith(courses: [], isDemo: false),
    );
    await start(tester, repository);
    await tester.tap(find.byTooltip('添加课程'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '课程名称'), '无法保存的课');
    await tester.tap(find.text('保存课程'));
    await tester.pumpAndSettle();
    expect(repository.value!.courses, isEmpty);
    expect(find.textContaining('保存失败'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}

class _FailingRepository extends MemoryRepository {
  _FailingRepository(super.value);
  @override
  Future<void> save(ScheduleData data) async => throw Exception('disk full');
}
