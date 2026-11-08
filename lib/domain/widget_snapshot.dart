import 'engine.dart';
import 'models.dart';

/// A complete semester, with all recurrence and exception rules resolved once.
/// Local dates and wall-clock times let native widgets handle timezone changes.
Map<String, Object?> widgetSnapshot(ScheduleData data) => {
  'version': 1,
  'semesterName': data.semester.name,
  'firstMonday': dateKey(data.semester.firstMonday),
  'weekCount': data.semester.weekCount,
  'isDemo': data.isDemo,
  'lessons':
      lessonsBetween(
            data,
            data.semester.firstMonday,
            data.semester.dateAt(data.semester.weekCount, 7),
          )
          .map(
            (lesson) => {
              'id': lesson.key,
              'name': lesson.course.name,
              'room': lesson.room,
              'date': dateKey(lesson.date),
              'start': data.semester.periods[lesson.startPeriod - 1].start,
              'end': data.semester.periods[lesson.endPeriod - 1].end,
              'changed': lesson.changed,
            },
          )
          .toList(),
};
