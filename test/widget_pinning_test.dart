import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kejian/data/demo.dart';
import 'package:kejian/data/repository.dart';
import 'package:kejian/main.dart';
import 'package:kejian/platform/widget_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final calls = <String>[];
  final styles = <String>[];
  Object pinResult = true;
  setUp(() {
    calls.clear();
    styles.clear();
    pinResult = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(WidgetBridge.channel, (call) async {
          calls.add(call.method);
          if (call.method == 'status') {
            return {
              'registered': true,
              'pinSupported': true,
              'installedCount': 0,
            };
          }
          if (call.method == 'requestPin') {
            styles.add((call.arguments as Map)['style'] as String);
            if (pinResult is PlatformException) throw pinResult;
            return pinResult;
          }
          return null;
        });
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(WidgetBridge.channel, null);
  });

  Future<MemoryRepository> openSettings(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final now = DateTime(2026, 11, 9, 7);
    final repository = MemoryRepository(demoData(now));
    await tester.pumpWidget(
      KejianApp(repository: repository, clock: () => now),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('设置').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('添加 2×2'));
    await tester.pumpAndSettle();
    return repository;
  }

  testWidgets('pin request syncs first and waits for launcher confirmation', (
    tester,
  ) async {
    final repository = await openSettings(tester);
    final original = repository.value;
    calls.clear();
    await tester.tap(find.text('添加 2×2'));
    await tester.pumpAndSettle();
    expect(calls, ['sync', 'requestPin', 'status']);
    expect(styles, ['compact']);
    expect(find.textContaining('请在系统弹窗中确认'), findsOneWidget);
    expect(find.textContaining('桌面已添加'), findsNothing);
    expect(identical(repository.value, original), isTrue);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'wide widget requests its own provider after syncing the schedule',
    (tester) async {
      final repository = await openSettings(tester);
      final original = repository.value;
      final button = find.text('添加 4×2');
      await tester.ensureVisible(button);
      calls.clear();
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(calls, ['sync', 'requestPin', 'status']);
      expect(styles, ['wide']);
      expect(find.textContaining('已向桌面请求添加 4×2'), findsOneWidget);
      expect(repository.value, same(original));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('unsupported launcher shows Xiaomi manual instructions', (
    tester,
  ) async {
    pinResult = false;
    await openSettings(tester);
    await tester.tap(find.text('添加 2×2'));
    await tester.pumpAndSettle();
    expect(find.textContaining('当前桌面不支持直接添加'), findsOneWidget);
    final guide = find.text('找不到课间？查看手动添加步骤');
    await tester.ensureVisible(guide);
    await tester.tap(guide);
    await tester.pumpAndSettle();
    expect(find.textContaining('应用列表底部 → 安卓小部件 → 课间'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('failed request stays retryable without changing the schedule', (
    tester,
  ) async {
    pinResult = PlatformException(code: 'WIDGET_PIN');
    final repository = await openSettings(tester);
    final original = repository.value;
    await tester.tap(find.text('添加 2×2'));
    await tester.pumpAndSettle();
    expect(find.textContaining('暂时无法请求添加'), findsOneWidget);
    expect(identical(repository.value, original), isTrue);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '添加 2×2'))
          .onPressed,
      isNotNull,
    );
    pinResult = true;
    await tester.tap(find.text('添加 2×2'));
    await tester.pumpAndSettle();
    expect(find.textContaining('已向桌面请求添加'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  test(
    'iOS keeps manual WidgetKit addition and makes no Android calls',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(await WidgetBridge.androidStatus(), isNull);
      expect(await WidgetBridge.requestPin(), isFalse);
      expect(calls, isEmpty);
      expect(WidgetBridge.supported, isTrue);
    },
  );
}
