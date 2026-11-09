import 'dart:math' as math;

import '../domain/models.dart';

/// Character boxes use a top-left origin. PDF and OCR feed the same parser.
class TextBox {
  final String text;
  final double x, y, width, height;
  const TextBox(this.text, this.x, this.y, this.width, this.height);
  double get cx => x + width / 2;
  double get cy => y + height / 2;
  factory TextBox.fromJson(Map<String, dynamic> json) => TextBox(
    json['text'] as String,
    (json['x'] as num).toDouble(),
    (json['y'] as num).toDouble(),
    (json['width'] as num).toDouble(),
    (json['height'] as num).toDouble(),
  );
}

class RecognizedPage {
  final int number;
  final double width, height;
  final List<TextBox> boxes;
  final bool isOcr;
  final List<double> horizontalLines;
  const RecognizedPage({
    required this.number,
    required this.width,
    required this.height,
    required this.boxes,
    this.isOcr = false,
    this.horizontalLines = const [],
  });
}

class RecognitionEntry {
  final Course course;
  final String source;
  final int page;
  final List<String> warnings;
  const RecognitionEntry({
    required this.course,
    required this.source,
    required this.page,
    this.warnings = const [],
  });
}

class RecognitionResult {
  final List<RecognitionEntry> entries;
  final String? semesterName;
  final DateTime? firstMonday;
  final int? weekCount;
  final List<String> warnings;
  final List<String> unparsed;
  final List<RecognizedPage> pages;
  const RecognitionResult({
    required this.entries,
    required this.pages,
    required this.warnings,
    required this.unparsed,
    this.semesterName,
    this.firstMonday,
    this.weekCount,
  });

  List<Course> get courses => entries.map((e) => e.course).toList();
  int get meetingCount => courses.fold(0, (n, c) => n + c.meetings.length);
}

class _TextLine {
  final List<TextBox> boxes;
  _TextLine(this.boxes);
  String get text => boxes.map((b) => b.text).join();
  double get cy => boxes.fold<double>(0, (n, b) => n + b.cy) / boxes.length;
}

double _median(Iterable<double> values) {
  final sorted = values.toList()..sort();
  return sorted.isEmpty ? 1 : sorted[sorted.length ~/ 2];
}

List<TextBox> _glyphs(List<TextBox> boxes) {
  final result = <TextBox>[];
  for (final box in boxes) {
    if (!box.x.isFinite ||
        !box.y.isFinite ||
        box.width <= 0 ||
        box.height <= 0) {
      continue;
    }
    for (var i = 0; i < box.text.length; i++) {
      final ch = box.text[i];
      if (ch.trim().isEmpty || ch == '|') continue;
      result.add(
        TextBox(
          ch,
          box.x + box.width * i / box.text.length,
          box.y,
          box.width / box.text.length,
          box.height,
        ),
      );
    }
  }
  return result;
}

List<_TextLine> _lines(Iterable<TextBox> source) {
  final boxes = source.toList()..sort((a, b) => a.cy.compareTo(b.cy));
  final tolerance = _median(boxes.map((b) => b.height)) * .7;
  final lines = <_TextLine>[];
  for (final b in boxes) {
    if (lines.isEmpty || (lines.last.cy - b.cy).abs() > tolerance) {
      lines.add(_TextLine([b]));
    } else {
      lines.last.boxes.add(b);
    }
  }
  for (final line in lines) {
    line.boxes.sort((a, b) => a.x.compareTo(b.x));
  }
  return lines;
}

String _read(Iterable<TextBox> boxes) =>
    _lines(boxes).map((l) => l.text).join('\n');
String _compact(String value) => value
    .replaceAll(RegExp(r'\s+'), '')
    .replaceAll(RegExp('[（〈《]'), '(')
    .replaceAll(RegExp('[）〉》]'), ')')
    .replaceAll('／', '/')
    .replaceAll('：', ':')
    .replaceAll(RegExp('[‐‑–—－~～至]'), '-');

class _Column {
  final int weekday;
  final double center;
  const _Column(this.weekday, this.center);
}

class _Row {
  final int start, end;
  final double top, bottom;
  final bool inferred;
  const _Row(
    this.start,
    this.end,
    this.top,
    this.bottom, {
    this.inferred = false,
  });
  double get center => (top + bottom) / 2;
}

List<int> _periodNumbers(String text) {
  text = _compact(text).replaceAll(RegExp('[第节课、,]'), '');
  if (RegExp(r'\d').hasMatch(text) && RegExp('[一二三四五六七八九十]').hasMatch(text)) {
    return [];
  }
  if (RegExp(r'\d').hasMatch(text)) {
    return RegExp(r'\d+')
        .allMatches(text)
        .map((m) => int.parse(m[0]!))
        .toList();
  }
  // Vertical Chinese labels often omit punctuation: 第九十十一节.
  const singles = {
    '一': 1,
    '二': 2,
    '三': 3,
    '四': 4,
    '五': 5,
    '六': 6,
    '七': 7,
    '八': 8,
    '九': 9,
  };
  final values = <int>[];
  for (var i = 0; i < text.length; i++) {
    if (text[i] == '十') {
      if (i + 1 < text.length && singles.containsKey(text[i + 1])) {
        values.add(10 + singles[text[++i]]!);
      } else {
        values.add(10);
      }
    } else if (singles.containsKey(text[i])) {
      values.add(singles[text[i]]!);
    }
  }
  return values;
}

List<_Row> _findRows(
  List<TextBox> boxes,
  double left,
  double spacing,
  double headerY,
) {
  final side =
      boxes
          .where(
            (b) => b.cx < left && b.cx > left - spacing * .6 && b.cy > headerY,
          )
          .toList()
        ..sort((a, b) => a.cx.compareTo(b.cx));
  final bands = <List<TextBox>>[];
  for (final b in side) {
    if (bands.isEmpty ||
        (bands.last.map((b) => b.cx).reduce((a, b) => a + b) /
                        bands.last.length -
                    b.cx)
                .abs() >
            _median(side.map((b) => b.width)) * .9) {
      bands.add([b]);
    } else {
      bands.last.add(b);
    }
  }
  var best = <_Row>[];
  for (final band in bands) {
    band.sort((a, b) => a.cy.compareTo(b.cy));
    final rows = <_Row>[];
    for (final match in RegExp(
      r'第([一二三四五六七八九十0-9、,\-]+)节',
    ).allMatches(band.map((b) => b.text).join())) {
      final numbers = _periodNumbers(match[1]!);
      if (numbers.isEmpty ||
          numbers.first < 1 ||
          numbers.last > 16 ||
          List.generate(
            numbers.length - 1,
            (i) => numbers[i + 1] != numbers[i] + 1,
          ).any((v) => v)) {
        continue;
      }
      final used = band.sublist(match.start, match.end);
      rows.add(
        _Row(
          numbers.first,
          numbers.last,
          used.map((b) => b.y).reduce(math.min),
          used.map((b) => b.y + b.height).reduce(math.max),
        ),
      );
    }
    if (rows.length > best.length) best = rows;
  }
  // Horizontal labels such as "1-2节" are used by other timetable templates.
  if (best.isEmpty) {
    for (final line in _lines(side)) {
      final match = RegExp(r'(?:第)?(\d+)(?:[-、,](\d+))?节')
          .firstMatch(_compact(line.text));
      if (match == null) continue;
      final a = int.parse(match[1]!), b = int.parse(match[2] ?? match[1]!);
      if (a >= 1 && b >= a && b <= 16) {
        best.add(
          _Row(
            a,
            b,
            line.boxes.first.y,
            line.boxes.last.y + line.boxes.last.height,
          ),
        );
      }
    }
  }
  return best..sort((a, b) => a.center.compareTo(b.center));
}

List<int> recognitionWeeks(String value) {
  final text = _compact(value).replaceAll(RegExp('[第周()单双]'), '');
  final result = parseWeeks(text, 52);
  if (value.contains('单')) return result.where((w) => w.isOdd).toList();
  if (value.contains('双')) return result.where((w) => w.isEven).toList();
  return result;
}

/// A deliberately conservative parser for weekday-column / period-row tables.
/// Unknown layouts are retained for manual correction, never silently scheduled.
RecognitionResult parseTimetable(List<RecognizedPage> pages) {
  final entries = <RecognitionEntry>[];
  final unparsed = <String>[];
  final warnings = <String>[];
  String? semesterName;
  DateTime? monday;
  int? weekCount;
  for (final page in pages) {
    final boxes = _glyphs(page.boxes);
    final lines = _lines(boxes);
    final all = _compact(lines.map((l) => l.text).join('\n'));
    semesterName ??= RegExp(r'20\d{2}-20\d{2}年第?[一二三12]学期').firstMatch(all)?[0];
    final start = RegExp(r'(?:本学期|开学日期:?)(20\d{2}-\d{2}-\d{2})')
        .firstMatch(all);
    if (start != null) {
      final raw = start[1]!;
      final parts = raw.split('-').map(int.parse).toList();
      final date = DateTime(parts[0], parts[1], parts[2]);
      if (date.year != parts[0] ||
          date.month != parts[1] ||
          date.day != parts[2]) {
        warnings.add('开学日期「$raw」不是有效日期，请对照原表手动填写。');
      } else if (page.isOcr && date.weekday != DateTime.monday) {
        warnings.add('图片中读取的开学日期「$raw」不是周一，请对照原图手动填写；暂沿用当前学期日期。');
      } else {
        monday ??= addDays(date, 1 - date.weekday);
        if (date.weekday != DateTime.monday) {
          warnings.add('开学日期「$raw」已换算为所在周的周一，请核对第一教学周。');
        }
      }
    }
    final count = RegExp(r'共(\d{1,2})周').allMatches(all).toList();
    // Footer count follows 本学期; "共16周" within a course is not a semester length.
    final footer = all.indexOf('本学期');
    if (footer >= 0) {
      final m = RegExp(r'共(\d{1,2})周').firstMatch(all.substring(footer));
      if (m != null) weekCount ??= int.tryParse(m[1]!);
    } else if (count.length == 1 && !all.contains('其他课程')) {
      weekCount ??= int.tryParse(count.single[1]!);
    }
    List<_Column> columns = [];
    double headerY = 0;
    for (final line in lines) {
      final found = <_Column>[];
      for (final m in RegExp(r'(?:星期|周)([一二三四五六日天])').allMatches(line.text)) {
        const days = '一二三四五六日';
        final weekday = m[1] == '天' ? 7 : days.indexOf(m[1]!) + 1;
        final glyphs = line.boxes.sublist(m.start, m.end);
        found.add(
          _Column(
            weekday,
            (glyphs.first.x + glyphs.last.x + glyphs.last.width) / 2,
          ),
        );
      }
      if (found.length >= 3 &&
          found.map((c) => c.weekday).toSet().length == found.length) {
        columns = found;
        headerY = line.cy;
        break;
      }
    }
    if (columns.isEmpty) {
      warnings.add('第 ${page.number} 页未找到星期表头，请参考原文手动补充课程。');
      unparsed.add(_read(boxes));
      continue;
    }
    final spacing = _median([
      for (var i = 1; i < columns.length; i++)
        (columns[i].center - columns[i - 1].center) /
            (columns[i].weekday - columns[i - 1].weekday),
    ]);
    if (spacing <= 0) {
      unparsed.add(_read(boxes));
      continue;
    }
    final origin = _median(
      columns.map((c) => c.center - spacing * (c.weekday - 1)),
    );
    if (columns.first.weekday != 1 || columns.length != columns.last.weekday) {
      warnings.add('第 ${page.number} 页部分星期文字缺失，已按等宽表格补齐，请核对星期。');
      columns = [
        for (var day = 1; day <= columns.last.weekday; day++)
          _Column(day, origin + spacing * (day - 1)),
      ];
    }
    final left = origin - spacing / 2;
    var rows = _findRows(boxes, left, spacing, headerY);

    final otherLine = lines
        .where((l) => RegExp(r'其.{0,2}课.?程').hasMatch(l.text))
        .firstOrNull;
    final footerLine = lines
        .where((l) => l.text.startsWith('注') || l.text.startsWith('备注'))
        .firstOrNull;
    final endY =
        otherLine?.boxes.map((b) => b.y).reduce(math.min) ??
        footerLine?.boxes.map((b) => b.y).reduce(math.min) ??
        page.height;
    final grid =
        page.horizontalLines
            .where(
              (y) =>
                  y > headerY + _median(boxes.map((b) => b.height)) * .5 &&
                  y < endY,
            )
            .toList()
          ..sort();
    if (grid.length >= 3) {
      final known = <int, _Row>{};
      for (var i = 0; i < grid.length - 1; i++) {
        final matches = rows
            .where((r) => r.center > grid[i] && r.center < grid[i + 1])
            .toList();
        if (matches.length == 1) known[i] = matches.single;
      }
      // Two independently read row labels must agree before filling a gap.
      final patterns = <String, int>{};
      for (final e in known.entries) {
        final stride = e.value.end - e.value.start + 1;
        final offset = e.value.start - e.key * stride;
        if (offset >= 1) {
          final key = '$offset,$stride';
          patterns[key] = (patterns[key] ?? 0) + 1;
        }
      }
      final ranked = patterns.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final infer = ranked.isNotEmpty && ranked.first.value >= 2;
      final pattern = infer
          ? ranked.first.key.split(',').map(int.parse).toList()
          : [0, 0];
      rows = [
        for (var i = 0; i < grid.length - 1; i++)
          if (known[i] != null &&
              (!infer ||
                  (known[i]!.start == pattern[0] + i * pattern[1] &&
                      known[i]!.end - known[i]!.start + 1 >= pattern[1])))
            _Row(known[i]!.start, known[i]!.end, grid[i], grid[i + 1])
          else
            _Row(
              infer ? pattern[0] + i * pattern[1] : 0,
              infer ? pattern[0] + (i + 1) * pattern[1] - 1 : 0,
              grid[i],
              grid[i + 1],
              inferred: true,
            ),
      ];
    }
    if (rows.isEmpty) {
      warnings.add('第 ${page.number} 页的节次未识别，请参考原文手动补充。');
      unparsed.add(_read(boxes));
      continue;
    }
    for (final col in columns) {
      for (var r = 0; r < rows.length; r++) {
        final row = rows[r];
        // Label bounds tolerate cells with vertically centered or top-aligned text.
        final top = grid.length >= 3
            ? row.top
            : r == 0
            ? headerY + _median(boxes.map((b) => b.height))
            : (rows[r - 1].bottom + row.top) / 2;
        final bottom = grid.length >= 3
            ? row.bottom
            : r == rows.length - 1
            ? endY
            : (row.bottom + rows[r + 1].top) / 2;
        final cell = boxes.where(
          (b) =>
              (b.cx - col.center).abs() < spacing / 2 &&
              b.cy > top &&
              b.cy < bottom,
        );
        final source = _read(cell);
        if (source.trim().isEmpty) continue;
        final entry = _parseCell(source, col.weekday, row, page);
        if (entry == null) {
          if (_compact(source).length > 3) {
            unparsed.add(
              '第 ${page.number} 页 · 周${"一二三四五六日"[col.weekday - 1]} · ${row.start}-${row.end} 节\n$source',
            );
          }
        } else {
          entries.add(entry);
        }
      }
    }
    if (otherLine != null) {
      final raw = _read(
        boxes.where(
          (b) =>
              b.cy >= otherLine.boxes.map((b) => b.y).reduce(math.min) &&
              b.cy <
                  (footerLine?.boxes.map((b) => b.y).reduce(math.min) ??
                      page.height),
        ),
      );
      final text = _compact(raw)
          .replaceFirst(RegExp(r'^.*?其.{0,2}课.?程[:：]?'), '');
      for (final part in text.split(RegExp('[;；]'))) {
        if (part.isEmpty) continue;
        final m = RegExp(r'^(.+?)[★■◆●]([^(/]+)(?:\(.*?\))?/').firstMatch(part);
        if (m == null) {
          unparsed.add(part);
          continue;
        }
        entries.add(
          RecognitionEntry(
            course: Course(
              id: newId(),
              name: m[1]!,
              teacher: m[2]!,
              note: '未排时间；原文：$part',
              color: entries.length % 6,
              meetings: const [],
            ),
            source: part,
            page: page.number,
            warnings: const ['原表未排星期和节次，保留为待安排课程。'],
          ),
        );
      }
    }
  }
  // Merge a course's multiple cells, but retain differing rooms and week sets.
  final grouped = <String, RecognitionEntry>{};
  final seen = <String>{};
  for (final entry in entries) {
    final c = entry.course;
    final signature =
        '${c.name}|${c.teacher}|${c.meetings.map((m) => '${m.weekday}:${m.startPeriod}-${m.endPeriod}:${formatWeeks(m.weeks)}:${m.room}').join(';')}';
    if (!seen.add(signature)) continue;
    final key = '${c.name}\u0000${c.teacher}';
    final previous = grouped[key];
    grouped[key] = RecognitionEntry(
      course: Course(
        id: previous?.course.id ?? c.id,
        name: c.name,
        teacher: c.teacher,
        note: previous?.course.note ?? c.note,
        color: previous?.course.color ?? grouped.length % 6,
        meetings: [...?previous?.course.meetings, ...c.meetings],
      ),
      source: [
        if (previous != null) previous.source,
        entry.source,
      ].join('\n\n'),
      page: previous?.page ?? entry.page,
      warnings: {...?previous?.warnings, ...entry.warnings}.toList(),
    );
  }
  if (pages.any((p) => p.isOcr)) {
    warnings.add('图片文字可能有误，请逐项核对学期日期、课程名称、教师、教室及单双周。');
  }
  if (monday == null) warnings.add('未识别到开学日期，默认沿用当前学期，请核对第一周的周一。');
  if (unparsed.isNotEmpty) {
    warnings.add('有 ${unparsed.length} 段内容未能自动转换，请查看未识别原文并补充。');
  }
  warnings.add('原表未提供每节课的钟点时刻，沿用当前作息；请按学校作息核对。');
  return RecognitionResult(
    entries: grouped.values.toList(),
    pages: pages,
    warnings: warnings,
    unparsed: unparsed,
    semesterName: semesterName,
    firstMonday: monday,
    weekCount: weekCount != null && weekCount >= 1 && weekCount <= 52
        ? weekCount
        : null,
  );
}

RecognitionEntry? _parseCell(
  String source,
  int day,
  _Row row,
  RecognizedPage page,
) {
  final text = _compact(source);
  final parts = text.split('/');
  var repairedRange = false;
  if (page.isOcr && parts.length > 1) {
    if (parts[0].endsWith('(') &&
        RegExp(r'^\d{1,2}-?\d{1,2}节\)').hasMatch(parts[1])) {
      parts[0] = parts[0].substring(0, parts[0].length - 1);
      parts[1] = '(${parts[1]}';
      repairedRange = true;
    }
    final normalized = _repairOcrRanges(parts[1]);
    repairedRange = repairedRange || normalized != parts[1];
    parts[1] = normalized;
  }
  if (parts.length < 3 || parts[0].isEmpty) return null;
  // Explicit (9-10节) overrides a row headed 第九十十一节.
  final period = RegExp(r'\((\d{1,2})-(\d{1,2})节\)').firstMatch(parts[1]);
  final weekText = parts[1].replaceAll(RegExp(r'\([^)]*节\)'), '');
  if (!weekText.contains('周')) return null;
  List<int> weeks;
  try {
    weeks = recognitionWeeks(weekText);
  } on FormatException {
    return null;
  }
  if (weeks.isEmpty) return null;
  final start = period == null ? row.start : int.parse(period[1]!);
  final end = period == null ? row.end : int.parse(period[2]!);
  if (start < 1 || end < start || end > 16) return null;
  final room = parts[2] == '未排地点' || parts[2] == '无' ? '' : parts[2];
  final teacher = parts.length > 3 && !parts[3].startsWith('(')
      ? parts[3].replaceFirst(RegExp(r'\(.*$'), '')
      : '';
  return RecognitionEntry(
    course: Course(
      id: newId(),
      name: parts[0],
      teacher: teacher,
      note: '',
      color: 0,
      meetings: [
        Meeting(
          id: newId(),
          weekday: day,
          startPeriod: start,
          endPeriod: end,
          weeks: weeks,
          room: room,
        ),
      ],
    ),
    source: source,
    page: page.number,
    warnings: [
      if (page.isOcr) '来自图片识别，请核对文字。',
      if (repairedRange) '数字范围的分隔符由识别结果补全，请核对周次和节次。',
      if (row.inferred && period == null) '节次由相邻表格行推算，请核对。',
      if (room.isEmpty) '原表未排地点。',
      if (teacher.isEmpty) '教师未识别。',
    ],
  );
}

String _repairOcrRanges(String source) {
  final text = source.replaceAllMapped(
    RegExp(r'(\d)[一ー](?=\d)'),
    (m) => '${m[1]}-',
  );
  return text.replaceAllMapped(RegExp(r'(\d{3,4})(?=(节|周))'), (m) {
    final max = m[2] == '节' ? 16 : 52;
    final digits = m[1]!;
    final choices = <String>[];
    for (var i = 1; i < digits.length; i++) {
      final start = int.parse(digits.substring(0, i)),
          end = int.parse(digits.substring(i));
      if (digits.substring(0, i) == '$start' &&
          digits.substring(i) == '$end' &&
          start >= 1 &&
          end > start &&
          end <= max) {
        choices.add('$start-$end');
      }
    }
    return choices.length == 1 ? choices.single : digits;
  });
}
