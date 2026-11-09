// Private device fixtures are optional and never committed or shipped.
// See docs/IMPORT.md for the local fixture workflow.
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kejian/data/document_recognizer.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  if (!const bool.fromEnvironment('RUN_PRIVATE_IMPORT_TEST')) return;
  for (final name in ['fixture.pdf', 'fixture.png']) {
    testWidgets(
      name.endsWith('.pdf') ? 'local PDF extraction' : 'local image OCR',
      (tester) async {
        final bytes = await rootBundle.load('private_fixtures/$name');
        final result = await recognizeTimetableDocument(
          bytes.buffer.asUint8List(),
          name,
          onProgress: debugPrint,
        );
        debugPrint(
          'RESULT_$name: ${jsonEncode({
            'courses': result.courses.map((c) => c.toJson()).toList(),
            'warnings': result.warnings,
            'unparsed': result.unparsed,
            'pages': [
              for (final p in result.pages) {
                  'number': p.number,
                  'width': p.width,
                  'height': p.height,
                  'isOcr': p.isOcr,
                  'horizontalLines': p.horizontalLines,
                  'boxes': [
                    for (final b in p.boxes) {'text': b.text, 'x': b.x, 'y': b.y, 'width': b.width, 'height': b.height},
                  ],
                },
            ],
          })}',
          wrapWidth: 1000000,
        );
        final expected = const int.fromEnvironment(
          'IMPORT_TEST_MEETINGS',
          defaultValue: 0,
        );
        expect(result.meetingCount, expected > 0 ? expected : greaterThan(0));
        expect(result.pages.every((p) => p.isOcr), name.endsWith('.png'));
        debugPrint(
          '${result.courses.length} courses; ${result.meetingCount} meetings; ${result.unparsed.length} unresolved blocks',
        );
      },
    );
  }
}
