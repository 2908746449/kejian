import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kejian/data/demo.dart';
import 'package:kejian/data/repository.dart';
import 'package:kejian/main.dart';
import 'package:kejian/platform/file_access.dart';
import 'package:kejian/platform/ocr.dart';
import 'package:kejian/platform/widget_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final platforms = TargetPlatform.values.where((p) => p.name == 'ohos');
  const storage = MethodChannel('dev.kejian/storage');
  const files = MethodChannel('dev.kejian/files');
  const ocr = MethodChannel('dev.kejian/recognition');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final data = demoData(DateTime(2026, 11, 9));

  group('HarmonyOS native channels', skip: platforms.isEmpty, () {
    setUp(() {
      debugDefaultTargetPlatformOverride = platforms.first;
    });
    tearDown(() {
      debugDefaultTargetPlatformOverride = null;
      for (final channel in [storage, files, ocr, WidgetBridge.channel]) {
        messenger.setMockMethodCallHandler(channel, null);
      }
    });

    test(
      'private storage roundtrips the complete versioned document',
      () async {
        String? source;
        messenger.setMockMethodCallHandler(storage, (call) async {
          if (call.method == 'load') return source;
          expect(call.method, 'save');
          source = call.arguments as String;
          return null;
        });
        final repository = LocalScheduleRepository();
        expect(await repository.load(), isNull);
        await repository.save(data);
        expect(source, data.encode());
        expect(
          (await LocalScheduleRepository().load())!.encode(),
          data.encode(),
        );
      },
    );

    testWidgets('a storage read error never overwrites data with a demo', (
      tester,
    ) async {
      final calls = <String>[];
      messenger.setMockMethodCallHandler(storage, (call) async {
        calls.add(call.method);
        throw PlatformException(code: 'STORAGE_FAILED');
      });
      await tester.pumpWidget(KejianApp(repository: LocalScheduleRepository()));
      await tester.pumpAndSettle();
      expect(calls, ['load']);
      expect(find.textContaining('原始数据已保留'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      debugDefaultTargetPlatformOverride = null;
    });

    test('corrupt stored JSON is rejected without a save', () async {
      final calls = <String>[];
      messenger.setMockMethodCallHandler(storage, (call) async {
        calls.add(call.method);
        return '{broken';
      });
      await expectLater(
        LocalScheduleRepository().load(),
        throwsA(isA<FormatException>()),
      );
      expect(calls, ['load']);
    });

    test(
      'picker passes filters and receives bytes, including cancellation',
      () async {
        final bytes = Uint8List.fromList([1, 2, 3]);
        var cancelled = false;
        messenger.setMockMethodCallHandler(files, (call) async {
          expect(call.method, 'pick');
          expect(call.arguments, ['pdf', 'png']);
          return cancelled ? null : {'name': 'sample.pdf', 'bytes': bytes};
        });
        final file = await pickScheduleFile(allowedExtensions: ['pdf', 'png']);
        expect(file!.name, 'sample.pdf');
        expect(file.bytes, bytes);
        cancelled = true;
        expect(
          await pickScheduleFile(allowedExtensions: ['pdf', 'png']),
          isNull,
        );
      },
    );

    test(
      'export sends complete UTF-8 bytes and handles a cancelled save',
      () async {
        final bytes = Uint8List.fromList(utf8.encode(data.encode()));
        var cancelled = false;
        messenger.setMockMethodCallHandler(files, (call) async {
          expect(call.method, 'save');
          final arguments = call.arguments as Map;
          expect(arguments['name'], 'backup.json');
          expect(arguments['bytes'], bytes);
          return cancelled ? null : 'file://docs/backup.json';
        });
        Future<Uri?> save() => saveScheduleFile(
          fileName: 'backup.json',
          bytes: bytes,
          mimeType: 'application/json',
        );
        expect((await save()).toString(), 'file://docs/backup.json');
        cancelled = true;
        expect(await save(), isNull);
      },
    );

    test(
      'system OCR returns character boxes through the shared channel',
      () async {
        messenger.setMockMethodCallHandler(ocr, (call) async {
          expect(call.method, 'recognize');
          expect(call.arguments, Uint8List.fromList([7, 8]));
          return [
            {'text': '课', 'x': 10.0, 'y': 20.0, 'width': 12.0, 'height': 14.0},
          ];
        });
        final boxes = await recognizeImage(Uint8List.fromList([7, 8]));
        expect(boxes.single.text, '课');
        expect(boxes.single.x, 10);
      },
    );

    test(
      'widget sync uses the full semester without Android pin calls',
      () async {
        final calls = <String>[];
        messenger.setMockMethodCallHandler(WidgetBridge.channel, (call) async {
          calls.add(call.method);
          expect(jsonDecode(call.arguments as String), widgetSnapshot(data));
          return null;
        });
        expect(WidgetBridge.supported, isTrue);
        expect(WidgetBridge.isHarmonyOS, isTrue);
        await WidgetBridge.sync(data);
        expect(await WidgetBridge.androidStatus(), isNull);
        expect(await WidgetBridge.requestPin(wide: true), isFalse);
        expect(calls, ['sync']);
      },
    );

    testWidgets('settings offer both service card dimensions and resync', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      messenger.setMockMethodCallHandler(
        WidgetBridge.channel,
        (_) async => null,
      );
      await tester.pumpWidget(KejianApp(repository: MemoryRepository(data)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('设置').last);
      await tester.pumpAndSettle();
      expect(find.textContaining('2×2 方形和 2×4 横向卡片'), findsOneWidget);
      expect(find.text('添加 4×2'), findsNothing);
      expect(find.text('重新同步小组件'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      debugDefaultTargetPlatformOverride = null;
    });
  });
}
