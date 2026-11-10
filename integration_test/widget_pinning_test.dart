import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kejian/data/demo.dart';
import 'package:kejian/data/repository.dart';
import 'package:kejian/main.dart';
import 'package:kejian/platform/widget_bridge.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Android registers the provider and accepts a pin request', (
    tester,
  ) async {
    final status = await WidgetBridge.androidStatus();
    expect(status, isNotNull);
    expect(status!.registered, isTrue);
    expect(status.pinSupported, isTrue);
    final now = DateTime.now();
    await tester.pumpWidget(
      KejianApp(repository: MemoryRepository(demoData(now))),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('设置').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('添加 2×2'));
    await tester.tap(find.text('添加 2×2'));
    await tester.pumpAndSettle();
    expect(find.textContaining('已向桌面请求添加'), findsOneWidget);
    debugPrint(
      'WIDGET_PIN_REQUEST_ACCEPTED: provider registered, awaiting launcher confirmation',
    );
    // Leave the real launcher confirmation available for device inspection.
    await Future<void>.delayed(const Duration(seconds: 20));
    await tester.pumpWidget(const SizedBox());
  });
}
