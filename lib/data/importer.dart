import '../domain/models.dart';

const csvHeader = '课程名称,教师,教室,星期,开始节次,结束节次,周次,颜色,备注';
const csvExample =
    '$csvHeader\n高等数学,陈老师,博学楼 A301,1,1,2,1-16,1,带教材\n高等数学,陈老师,博学楼 A301,4,3,4,"1,3,5,7,9,11,13,15",1,带教材\n大学英语,王老师,文华楼 B205,2,3,4,1-16,3,\n';

/// RFC 4180-style fields, including quoted commas, double quotes and line breaks.
List<List<String>> readCsv(String source) {
  final rows = <List<String>>[];
  var row = <String>[];
  final field = StringBuffer();
  var quoted = false, closed = false;
  final text = source
      .replaceFirst(RegExp('^\uFEFF'), '')
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n');
  void cell() {
    row.add(field.toString());
    field.clear();
    closed = false;
  }

  void line() {
    cell();
    if (row.any((s) => s.trim().isNotEmpty)) rows.add(row);
    row = [];
  }

  for (var i = 0; i < text.length; i++) {
    final c = text[i];
    if (quoted) {
      if (c == '"') {
        if (i + 1 < text.length && text[i + 1] == '"') {
          field.write('"');
          i++;
        } else {
          quoted = false;
          closed = true;
        }
      } else {
        field.write(c);
      }
    } else if (c == ',') {
      cell();
    } else if (c == '\n') {
      line();
    } else if (c == '"' && field.isEmpty && !closed) {
      quoted = true;
    } else if (closed || c == '"') {
      throw const FormatException('CSV 引号格式错误');
    } else {
      field.write(c);
    }
  }
  if (quoted) throw const FormatException('CSV 中的引号未闭合');
  if (field.isNotEmpty || row.isNotEmpty || closed) line();
  return rows;
}

List<Course> coursesFromCsv(String text, Semester semester) {
  final rows = readCsv(text);
  if (rows.isEmpty || rows.first.join(',') != csvHeader) {
    throw const FormatException('CSV 表头不匹配，请先下载模板');
  }
  if (rows.length > 1001) throw const FormatException('CSV 最多导入 1000 组上课安排');
  final grouped = <String, Course>{};
  for (var i = 1; i < rows.length; i++) {
    final row = rows[i];
    try {
      if (row.length != 9) throw const FormatException('需要 9 列，包含逗号的单元格请使用双引号');
      final name = row[0].trim(), teacher = row[1].trim();
      if (name.isEmpty) throw const FormatException('课程名称不能为空');
      final key = '$name\u0000$teacher\u0000${row[7]}\u0000${row[8]}';
      final previous = grouped[key];
      final meeting = Meeting(
        id: newId(),
        weekday: int.parse(row[3]),
        startPeriod: int.parse(row[4]),
        endPeriod: int.parse(row[5]),
        weeks: parseWeeks(row[6], semester.weekCount),
        room: row[2].trim(),
      );
      grouped[key] = Course(
        id: previous?.id ?? newId(),
        name: name,
        teacher: teacher,
        note: row[8],
        color: int.parse(row[7]) - 1,
        meetings: [...?previous?.meetings, meeting],
      );
      ScheduleData(semester: semester, courses: [grouped[key]!]).validate();
    } catch (e) {
      throw FormatException(
        '第 ${i + 1} 行：${e is FormatException ? e.message : '请检查数字和周次格式'}',
      );
    }
  }
  if (grouped.isEmpty) throw const FormatException('文件中没有课程');
  return grouped.values.toList();
}
