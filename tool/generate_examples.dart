import 'dart:io';

import 'package:kejian/data/demo.dart';
import 'package:kejian/data/importer.dart';

void main() {
  Directory('examples').createSync(recursive: true);
  File('examples/semester-demo.json')
      .writeAsStringSync(demoData(DateTime(2026, 11, 8)).encode());
  File('examples/courses-template.csv').writeAsStringSync('\uFEFF$csvExample');
  stdout.writeln('Generated the versioned sample backup and CSV template.');
}
