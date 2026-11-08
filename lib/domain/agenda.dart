import 'engine.dart';
import 'models.dart';

class AgendaPreview {
  final Lesson? next;
  final List<Lesson> following;
  final bool tomorrow;
  const AgendaPreview(this.next, this.following, {required this.tomorrow});
}

/// The main card is never duplicated in the row. While today's last class is
/// the main card, the row previews tomorrow, including weekend/changed lessons.
AgendaPreview agendaPreview(ScheduleData data, DateTime now) {
  final next = nextLesson(data, now);
  final remaining = lessonsBetween(
    data,
    dayOnly(now),
    dayOnly(now),
  ).where((lesson) => lesson.end(data.semester).isAfter(now)).toList();
  if (remaining.length > 1) {
    return AgendaPreview(next, remaining.skip(1).toList(), tomorrow: false);
  }
  final tomorrow = addDays(now, 1);
  final following = lessonsBetween(
    data,
    tomorrow,
    tomorrow,
  ).where((lesson) => lesson.key != next?.key).toList();
  return AgendaPreview(next, following, tomorrow: true);
}
