import 'package:flutter/material.dart';

import '../domain/models.dart';
import '../domain/engine.dart';
import 'theme.dart';

class LessonDetails extends StatelessWidget {
  final Lesson lesson;
  final Semester semester;
  const LessonDetails({
    super.key,
    required this.lesson,
    required this.semester,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: courseColors[lesson.course.color],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            lesson.changed ? '本次已调整' : '第 ${semester.weekOf(lesson.date)} 周',
            style: TextStyle(
              color: courseInks[lesson.course.color],
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          lesson.course.name,
          style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 20),
        _row(
          Icons.calendar_today_outlined,
          '${lesson.date.month} 月 ${lesson.date.day} 日 · ${weekdays[lesson.date.weekday - 1]}',
        ),
        _row(
          Icons.schedule,
          '${semester.periods[lesson.startPeriod - 1].start}—${semester.periods[lesson.endPeriod - 1].end}  ·  第 ${lesson.startPeriod}—${lesson.endPeriod} 节',
        ),
        _row(Icons.place_outlined, lesson.room.isEmpty ? '教室待补充' : lesson.room),
        _row(
          Icons.person_outline,
          lesson.course.teacher.isEmpty ? '教师待补充' : lesson.course.teacher,
        ),
        if (lesson.course.note.isNotEmpty)
          _row(Icons.notes, lesson.course.note),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => Navigator.pop(context, 'move'),
            icon: const Icon(Icons.edit_calendar_outlined, size: 18),
            label: const Text('调整这一次'),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context, 'edit'),
                child: const Text('编辑整门课程'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context, 'cancel'),
                child: const Text('仅本次停课'),
              ),
            ),
          ],
        ),
      ],
    ),
  );
  Widget _row(IconData icon, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: muted),
        const SizedBox(width: 12),
        Expanded(
          child: Text(text, style: const TextStyle(color: ink, height: 1.5)),
        ),
      ],
    ),
  );
}

Future<LessonException?> moveLesson(
  BuildContext context,
  Lesson lesson,
  Semester semester,
) => showDialog<LessonException>(
  context: context,
  builder: (_) => _MoveDialog(lesson: lesson, semester: semester),
);

class _MoveDialog extends StatefulWidget {
  final Lesson lesson;
  final Semester semester;
  const _MoveDialog({required this.lesson, required this.semester});
  @override
  State<_MoveDialog> createState() => _MoveDialogState();
}

class _MoveDialogState extends State<_MoveDialog> {
  late DateTime date;
  late int start, end;
  late final TextEditingController room;
  @override
  void initState() {
    super.initState();
    date = widget.lesson.date;
    start = widget.lesson.startPeriod;
    end = widget.lesson.endPeriod;
    room = TextEditingController(text: widget.lesson.room);
  }

  @override
  void dispose() {
    room.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('只调整这一次'),
    content: SizedBox(
      width: 380,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.lesson.course.name,
              style: const TextStyle(color: muted),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final selected = await showDatePicker(
                    context: context,
                    initialDate: date,
                    firstDate: widget.semester.firstMonday,
                    lastDate: widget.semester.dateAt(
                      widget.semester.weekCount,
                      7,
                    ),
                  );
                  if (selected != null && mounted) {
                    setState(() => date = selected);
                  }
                },
                icon: const Icon(Icons.calendar_month_outlined, size: 18),
                label: Text(dateKey(date)),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: start,
                    decoration: const InputDecoration(labelText: '开始节次'),
                    items: widget.semester.periods
                        .map(
                          (p) => DropdownMenuItem(
                            value: p.number,
                            child: Text('第 ${p.number} 节'),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() {
                      start = v!;
                      if (end < start) end = start;
                    }),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    key: ValueKey(end),
                    initialValue: end,
                    decoration: const InputDecoration(labelText: '结束节次'),
                    items: widget.semester.periods
                        .where((p) => p.number >= start)
                        .map(
                          (p) => DropdownMenuItem(
                            value: p.number,
                            child: Text('第 ${p.number} 节'),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => end = v!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: room,
              maxLength: 120,
              decoration: const InputDecoration(
                labelText: '这一次的教室',
                counterText: '',
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '原来的重复安排会保留，其他周次不受影响。',
              style: TextStyle(color: muted, fontSize: 12),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(
          context,
          LessonException(
            meetingId: widget.lesson.meeting.id,
            originalDate: widget.lesson.originalDate,
            targetDate: date,
            startPeriod: start,
            endPeriod: end,
            room: room.text.trim(),
          ),
        ),
        child: const Text('确认调整'),
      ),
    ],
  );
}
