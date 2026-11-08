import 'dart:io';
import 'dart:convert';

import 'package:kejian/domain/widget_snapshot.dart';

import 'package:kejian/data/demo.dart';
import 'package:kejian/data/importer.dart';

void main() {
  Directory('examples').createSync(recursive: true);
  File('examples/semester-demo.json')
      .writeAsStringSync(demoData(DateTime(2026, 11, 8)).encode());
  File('examples/courses-template.csv').writeAsStringSync('\uFEFF$csvExample');
  File('examples/widget-snapshot.json').writeAsStringSync(
    const JsonEncoder.withIndent('  ')
        .convert(widgetSnapshot(demoData(DateTime(2026, 11, 8)))),
  );
  stdout.writeln('Generated the versioned sample backup and CSV template.');
}
