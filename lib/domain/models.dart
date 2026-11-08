import 'dart:convert';

DateTime dayOnly(DateTime date) => DateTime(date.year, date.month, date.day);
String dateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
int dayDistance(DateTime a, DateTime b) => DateTime.utc(
  a.year,
  a.month,
  a.day,
).difference(DateTime.utc(b.year, b.month, b.day)).inDays;
DateTime addDays(DateTime date, int days) =>
    DateTime(date.year, date.month, date.day + days);
DateTime parseDay(String value) {
  final result = DateTime.tryParse(value);
  if (result == null || dateKey(result) != value) {
    throw const FormatException('日期格式应为 YYYY-MM-DD');
  }
  return dayOnly(result);
}

int timeMinutes(String value) {
  if (!RegExp(r'^\d{2}:\d{2}$').hasMatch(value)) {
    throw const FormatException('时间格式应为 HH:mm');
  }
  final parts = value.split(':').map(int.parse).toList();
  if (parts[0] > 23 || parts[1] > 59) throw const FormatException('时间超出范围');
  return parts[0] * 60 + parts[1];
}

String newId() => '${DateTime.now().microsecondsSinceEpoch}-${_counter++}';
int _counter = 0;

class Period {
  final int number;
  final String start, end;
  const Period(this.number, this.start, this.end);
  Map<String, dynamic> toJson() => {
    'number': number,
    'start': start,
    'end': end,
  };
  factory Period.fromJson(Map<String, dynamic> json) => Period(
    json['number'] as int,
    json['start'] as String,
    json['end'] as String,
  );
}

class Semester {
  final String name;
  final DateTime firstMonday;
  final int weekCount;
  final List<Period> periods;
  const Semester({
    required this.name,
    required this.firstMonday,
    required this.weekCount,
    required this.periods,
  });
  int weekOf(DateTime date) => (dayDistance(date, firstMonday) / 7).floor() + 1;
  DateTime dateAt(int week, int weekday) =>
      addDays(firstMonday, (week - 1) * 7 + weekday - 1);
  Map<String, dynamic> toJson() => {
    'name': name,
    'firstMonday': dateKey(firstMonday),
    'weekCount': weekCount,
    'periods': periods.map((p) => p.toJson()).toList(),
  };
  factory Semester.fromJson(Map<String, dynamic> json) => Semester(
    name: json['name'] as String,
    firstMonday: parseDay(json['firstMonday'] as String),
    weekCount: json['weekCount'] as int,
    periods: (json['periods'] as List)
        .map((p) => Period.fromJson(Map<String, dynamic>.from(p)))
        .toList(),
  );
}

class Meeting {
  final String id, room;
  final int weekday, startPeriod, endPeriod;
  final List<int> weeks;
  const Meeting({
    required this.id,
    required this.weekday,
    required this.startPeriod,
    required this.endPeriod,
    required this.weeks,
    required this.room,
  });
  Map<String, dynamic> toJson() => {
    'id': id,
    'weekday': weekday,
    'startPeriod': startPeriod,
    'endPeriod': endPeriod,
    'weeks': weeks,
    'room': room,
  };
  factory Meeting.fromJson(Map<String, dynamic> json) => Meeting(
    id: json['id'] as String,
    weekday: json['weekday'] as int,
    startPeriod: json['startPeriod'] as int,
    endPeriod: json['endPeriod'] as int,
    weeks: (json['weeks'] as List).cast<int>(),
    room: json['room'] as String,
  );
}

class Course {
  final String id, name, teacher, note;
  final int color;
  final List<Meeting> meetings;
  const Course({
    required this.id,
    required this.name,
    required this.teacher,
    required this.note,
    required this.color,
    required this.meetings,
  });
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'teacher': teacher,
    'note': note,
    'color': color,
    'meetings': meetings.map((m) => m.toJson()).toList(),
  };
  factory Course.fromJson(Map<String, dynamic> json) => Course(
    id: json['id'] as String,
    name: json['name'] as String,
    teacher: json['teacher'] as String,
    note: json['note'] as String,
    color: json['color'] as int,
    meetings: (json['meetings'] as List)
        .map((m) => Meeting.fromJson(Map<String, dynamic>.from(m)))
        .toList(),
  );
}

class LessonException {
  final String meetingId;
  final DateTime originalDate;
  final bool cancelled;
  final DateTime? targetDate;
  final int? startPeriod, endPeriod;
  final String? room;
  const LessonException({
    required this.meetingId,
    required this.originalDate,
    this.cancelled = false,
    this.targetDate,
    this.startPeriod,
    this.endPeriod,
    this.room,
  });
  String get key => '$meetingId@${dateKey(originalDate)}';
  Map<String, dynamic> toJson() => {
    'meetingId': meetingId,
    'originalDate': dateKey(originalDate),
    'cancelled': cancelled,
    'targetDate': targetDate == null ? null : dateKey(targetDate!),
    'startPeriod': startPeriod,
    'endPeriod': endPeriod,
    'room': room,
  };
  factory LessonException.fromJson(Map<String, dynamic> json) =>
      LessonException(
        meetingId: json['meetingId'] as String,
        originalDate: parseDay(json['originalDate'] as String),
        cancelled: json['cancelled'] as bool,
        targetDate: json['targetDate'] == null
            ? null
            : parseDay(json['targetDate'] as String),
        startPeriod: json['startPeriod'] as int?,
        endPeriod: json['endPeriod'] as int?,
        room: json['room'] as String?,
      );
}

class ScheduleData {
  final Semester semester;
  final List<Course> courses;
  final List<LessonException> exceptions;
  final bool isDemo, showWeekends;
  const ScheduleData({
    required this.semester,
    required this.courses,
    this.exceptions = const [],
    this.isDemo = false,
    this.showWeekends = true,
  });
  ScheduleData copyWith({
    Semester? semester,
    List<Course>? courses,
    List<LessonException>? exceptions,
    bool? isDemo,
    bool? showWeekends,
  }) => ScheduleData(
    semester: semester ?? this.semester,
    courses: courses ?? this.courses,
    exceptions: exceptions ?? this.exceptions,
    isDemo: isDemo ?? this.isDemo,
    showWeekends: showWeekends ?? this.showWeekends,
  );
  Map<String, dynamic> toJson() => {
    'schemaVersion': 1,
    'semester': semester.toJson(),
    'courses': courses.map((c) => c.toJson()).toList(),
    'exceptions': exceptions.map((e) => e.toJson()).toList(),
    'isDemo': isDemo,
    'showWeekends': showWeekends,
  };
  String encode() => const JsonEncoder.withIndent('  ').convert(toJson());
  factory ScheduleData.decode(String source) {
    try {
      final json = jsonDecode(source) as Map<String, dynamic>;
      if (json['schemaVersion'] != 1) {
        throw const FormatException('不支持此备份版本，请使用版本 1 的课间备份');
      }
      final result = ScheduleData(
        semester: Semester.fromJson(
          Map<String, dynamic>.from(json['semester']),
        ),
        courses: (json['courses'] as List)
            .map((c) => Course.fromJson(Map<String, dynamic>.from(c)))
            .toList(),
        exceptions: (json['exceptions'] as List)
            .map((e) => LessonException.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        isDemo: json['isDemo'] as bool? ?? false,
        showWeekends: json['showWeekends'] as bool? ?? true,
      );
      result.validate();
      return result;
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException('备份结构不完整，请选择课间导出的 JSON 文件');
    }
  }
  void validate() {
    if (semester.name.trim().isEmpty ||
        semester.name.length > 100 ||
        semester.weekCount < 1 ||
        semester.weekCount > 52 ||
        semester.firstMonday.year < 2000 ||
        semester.firstMonday.year > 2099 ||
        semester.firstMonday.weekday != 1) {
      throw const FormatException('学期需要名称、1—52 周和第一教学周的周一日期');
    }
    if (semester.periods.isEmpty || semester.periods.length > 16) {
      throw const FormatException('每天需设置 1—16 节课');
    }
    var previousEnd = -1;
    for (var i = 0; i < semester.periods.length; i++) {
      final p = semester.periods[i];
      if (p.number != i + 1 ||
          timeMinutes(p.start) >= timeMinutes(p.end) ||
          timeMinutes(p.start) < previousEnd) {
        throw const FormatException('节次应连续，时间需按顺序且不能重叠');
      }
      previousEnd = timeMinutes(p.end);
    }
    if (courses.length > 300 || exceptions.length > 10000) {
      throw const FormatException('数据量超过单学期限制');
    }
    final courseIds = <String>{};
    final meetingIds = <String, Meeting>{};
    for (final c in courses) {
      if (c.id.isEmpty ||
          !courseIds.add(c.id) ||
          c.name.trim().isEmpty ||
          c.name.length > 120 ||
          c.teacher.length > 120 ||
          c.note.length > 4000 ||
          c.color < 0 ||
          c.color > 5 ||
          c.meetings.isEmpty ||
          c.meetings.length > 30) {
        throw const FormatException('课程名称、标识或安排不合法');
      }
      for (final m in c.meetings) {
        if (m.id.isEmpty ||
            meetingIds.containsKey(m.id) ||
            m.weekday < 1 ||
            m.weekday > 7 ||
            m.startPeriod < 1 ||
            m.endPeriod < m.startPeriod ||
            m.endPeriod > semester.periods.length ||
            m.weeks.isEmpty ||
            m.weeks.toSet().length != m.weeks.length ||
            m.weeks.any((w) => w < 1 || w > semester.weekCount) ||
            m.room.length > 120) {
          throw const FormatException('上课安排的星期、节次或周次不合法');
        }
        meetingIds[m.id] = m;
      }
    }
    final exceptionKeys = <String>{};
    for (final e in exceptions) {
      final m = meetingIds[e.meetingId];
      if (m == null ||
          !exceptionKeys.add(e.key) ||
          m.weekday != e.originalDate.weekday ||
          !m.weeks.contains(semester.weekOf(e.originalDate))) {
        throw const FormatException('调课记录没有对应的原始课程');
      }
      if (!e.cancelled &&
          (e.targetDate == null ||
              e.startPeriod == null ||
              e.endPeriod == null ||
              e.startPeriod! < 1 ||
              e.endPeriod! < e.startPeriod! ||
              e.endPeriod! > semester.periods.length ||
              semester.weekOf(e.targetDate!) < 1 ||
              semester.weekOf(e.targetDate!) > semester.weekCount)) {
        throw const FormatException('调课日期必须在本学期内，节次必须有效');
      }
    }
  }
}

List<int> parseWeeks(String text, int maxWeek) {
  final weeks = <int>{};
  for (final token
      in text
          .trim()
          .replaceAll(RegExp(r'\s*-\s*'), '-')
          .split(RegExp(r'[\s,，]+'))) {
    final parts = token.split('-');
    if (parts.length > 2 || parts.any((p) => int.tryParse(p) == null)) {
      throw const FormatException('周次用空格或逗号分隔，例如：1 3 5-8');
    }
    final start = int.parse(parts.first), end = int.parse(parts.last);
    if (start < 1 || end < start || end > maxWeek) {
      throw FormatException('周次应在 1—$maxWeek 之间');
    }
    weeks.addAll(List.generate(end - start + 1, (i) => start + i));
  }
  return weeks.toList()..sort();
}

String formatWeeks(List<int> values) {
  final sorted = values.toSet().toList()..sort();
  final runs = <String>[];
  for (var i = 0; i < sorted.length; i++) {
    final start = sorted[i];
    while (i + 1 < sorted.length && sorted[i + 1] == sorted[i] + 1) {
      i++;
    }
    runs.add(start == sorted[i] ? '$start' : '$start-${sorted[i]}');
  }
  return runs.join(',');
}
