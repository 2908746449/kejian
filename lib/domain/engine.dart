import 'models.dart';

class Lesson {
  final Course course;
  final Meeting meeting;
  final DateTime originalDate, date;
  final int startPeriod, endPeriod;
  final String room;
  final bool changed;
  const Lesson({
    required this.course,
    required this.meeting,
    required this.originalDate,
    required this.date,
    required this.startPeriod,
    required this.endPeriod,
    required this.room,
    required this.changed,
  });
  String get key => '${meeting.id}@${dateKey(originalDate)}';
  DateTime start(Semester s) => _at(s.periods[startPeriod - 1].start);
  DateTime end(Semester s) => _at(s.periods[endPeriod - 1].end);
  DateTime _at(String time) {
    final minutes = timeMinutes(time);
    return DateTime(
      date.year,
      date.month,
      date.day,
      minutes ~/ 60,
      minutes % 60,
    );
  }
}

List<Lesson> lessonsBetween(
  ScheduleData data,
  DateTime from,
  DateTime through,
) {
  final overrides = {for (final e in data.exceptions) e.key: e};
  final result = <Lesson>[];
  for (final c in data.courses) {
    for (final m in c.meetings) {
      for (final week in m.weeks) {
        final original = data.semester.dateAt(week, m.weekday);
        final override = overrides['${m.id}@${dateKey(original)}'];
        if (override?.cancelled ?? false) continue;
        final date = override?.targetDate ?? original;
        if (dayDistance(date, from) < 0 || dayDistance(date, through) > 0) {
          continue;
        }
        result.add(
          Lesson(
            course: c,
            meeting: m,
            originalDate: original,
            date: date,
            startPeriod: override?.startPeriod ?? m.startPeriod,
            endPeriod: override?.endPeriod ?? m.endPeriod,
            room: override?.room ?? m.room,
            changed: override != null,
          ),
        );
      }
    }
  }
  result.sort((a, b) {
    final d = a.start(data.semester).compareTo(b.start(data.semester));
    return d != 0 ? d : a.key.compareTo(b.key);
  });
  return result;
}

List<Lesson> lessonsInWeek(ScheduleData data, int week) => lessonsBetween(
  data,
  data.semester.dateAt(week, 1),
  data.semester.dateAt(week, 7),
);
Lesson? nextLesson(ScheduleData data, DateTime now) {
  for (final lesson in lessonsBetween(
    data,
    dayOnly(now),
    data.semester.dateAt(data.semester.weekCount, 7),
  )) {
    if (lesson.end(data.semester).isAfter(now)) return lesson;
  }
  return null;
}

bool overlap(Lesson a, Lesson b) =>
    dateKey(a.date) == dateKey(b.date) &&
    a.startPeriod <= b.endPeriod &&
    b.startPeriod <= a.endPeriod;
Set<String> conflictKeys(List<Lesson> lessons) {
  final keys = <String>{};
  final occupied = <String, String>{};
  for (final lesson in lessons) {
    for (
      var period = lesson.startPeriod;
      period <= lesson.endPeriod;
      period++
    ) {
      final slot = '${dateKey(lesson.date)}:$period';
      final previous = occupied[slot];
      if (previous != null) keys.addAll([previous, lesson.key]);
      occupied[slot] = lesson.key;
    }
  }
  return keys;
}

/// Remove only exceptions whose original occurrence disappeared after editing.
List<LessonException> validExceptions(ScheduleData data, List<Course> courses) {
  final meetings = {
    for (final c in courses)
      for (final m in c.meetings) m.id: m,
  };
  return data.exceptions.where((e) {
    final m = meetings[e.meetingId];
    return m != null &&
        m.weekday == e.originalDate.weekday &&
        m.weeks.contains(data.semester.weekOf(e.originalDate));
  }).toList();
}
