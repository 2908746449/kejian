import 'package:flutter/material.dart';

import '../domain/models.dart';
import 'theme.dart';

Future<Course?> editCourse(
  BuildContext context,
  Semester semester, {
  Course? course,
}) => showDialog<Course>(
  context: context,
  builder: (_) => CourseEditor(semester: semester, course: course),
);

class CourseEditor extends StatefulWidget {
  final Semester semester;
  final Course? course;
  const CourseEditor({super.key, required this.semester, this.course});
  @override
  State<CourseEditor> createState() => _CourseEditorState();
}

class _MeetingDraft {
  final String id;
  final TextEditingController room, weeks;
  int weekday, start, end;
  _MeetingDraft(Meeting m)
    : id = m.id,
      room = TextEditingController(text: m.room),
      weeks = TextEditingController(text: formatWeeks(m.weeks)),
      weekday = m.weekday,
      start = m.startPeriod,
      end = m.endPeriod;
  void dispose() {
    room.dispose();
    weeks.dispose();
  }
}

class _CourseEditorState extends State<CourseEditor> {
  late final TextEditingController name, teacher, note;
  late final List<_MeetingDraft> meetings;
  late int color;
  String? error;
  @override
  void initState() {
    super.initState();
    final c = widget.course;
    name = TextEditingController(text: c?.name ?? '');
    teacher = TextEditingController(text: c?.teacher ?? '');
    note = TextEditingController(text: c?.note ?? '');
    color = c?.color ?? 0;
    meetings = (c?.meetings ?? [_blank()]).map(_MeetingDraft.new).toList();
  }

  Meeting _blank() => Meeting(
    id: newId(),
    weekday: 1,
    startPeriod: 1,
    endPeriod: widget.semester.periods.length >= 2 ? 2 : 1,
    weeks: List.generate(widget.semester.weekCount, (i) => i + 1),
    room: '',
  );
  @override
  void dispose() {
    name.dispose();
    teacher.dispose();
    note.dispose();
    for (final m in meetings) {
      m.dispose();
    }
    super.dispose();
  }

  void save() {
    try {
      final c = Course(
        id: widget.course?.id ?? newId(),
        name: name.text.trim(),
        teacher: teacher.text.trim(),
        note: note.text.trim(),
        color: color,
        meetings: meetings
            .map(
              (m) => Meeting(
                id: m.id,
                weekday: m.weekday,
                startPeriod: m.start,
                endPeriod: m.end,
                weeks: parseWeeks(m.weeks.text, widget.semester.weekCount),
                room: m.room.text.trim(),
              ),
            )
            .toList(),
      );
      ScheduleData(semester: widget.semester, courses: [c]).validate();
      Navigator.pop(context, c);
    } on FormatException catch (e) {
      setState(() => error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) => Dialog(
    insetPadding: const EdgeInsets.all(16),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.course == null ? '添加一门新课程' : '编辑课程',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  tooltip: '关闭',
                ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: name,
                    maxLength: 120,
                    decoration: const InputDecoration(
                      labelText: '课程名称',
                      hintText: '例如：高等数学',
                      counterText: '',
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: teacher,
                    maxLength: 120,
                    decoration: const InputDecoration(
                      labelText: '任课教师（选填）',
                      counterText: '',
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    '课程颜色',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 12,
                    children: List.generate(
                      courseColors.length,
                      (i) => Semantics(
                        label: '颜色 ${i + 1}',
                        selected: color == i,
                        button: true,
                        child: InkWell(
                          onTap: () => setState(() => color = i),
                          borderRadius: BorderRadius.circular(30),
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: courseColors[i],
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: color == i
                                    ? courseInks[i]
                                    : courseColors[i],
                                width: 2,
                              ),
                            ),
                            child: color == i
                                ? Icon(
                                    Icons.check,
                                    size: 20,
                                    color: courseInks[i],
                                  )
                                : null,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          '上课安排',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (meetings.length < 30)
                        TextButton.icon(
                          onPressed: () => setState(
                            () => meetings.add(_MeetingDraft(_blank())),
                          ),
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('再加一组'),
                        ),
                    ],
                  ),
                  const Text(
                    '同一门课可以有多个时间和教室。',
                    style: TextStyle(color: muted, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  for (var i = 0; i < meetings.length; i++)
                    _meetingCard(meetings[i], i),
                  TextField(
                    controller: note,
                    maxLines: 2,
                    maxLength: 4000,
                    decoration: const InputDecoration(
                      labelText: '备注（选填）',
                      hintText: '教材、上课提醒或其他小事',
                      counterText: '',
                    ),
                  ),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: Text(
                        error!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: save,
                icon: const Icon(Icons.check, size: 18),
                label: const Text('保存课程'),
              ),
            ),
          ),
        ],
      ),
    ),
  );
  Widget _meetingCard(_MeetingDraft m, int i) => Container(
    key: ValueKey(m.id),
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: paper,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: lineColor),
    ),
    child: Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '安排 ${i + 1}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            if (meetings.length > 1)
              IconButton(
                tooltip: '删除这组安排',
                onPressed: () => setState(() {
                  meetings.remove(m);
                  m.dispose();
                }),
                icon: const Icon(Icons.close, size: 18),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<int>(
                initialValue: m.weekday,
                isExpanded: true,
                decoration: const InputDecoration(labelText: '星期'),
                items: List.generate(
                  7,
                  (j) =>
                      DropdownMenuItem(value: j + 1, child: Text(weekdays[j])),
                ),
                onChanged: (v) => setState(() => m.weekday = v!),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: DropdownButtonFormField<int>(
                key: ValueKey('${m.id}-s-${m.start}'),
                initialValue: m.start,
                isExpanded: true,
                decoration: const InputDecoration(labelText: '开始'),
                items: widget.semester.periods
                    .map(
                      (p) => DropdownMenuItem(
                        value: p.number,
                        child: Text('${p.number} 节'),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() {
                  m.start = v!;
                  if (m.end < v) m.end = v;
                }),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: DropdownButtonFormField<int>(
                key: ValueKey('${m.id}-e-${m.end}'),
                initialValue: m.end,
                isExpanded: true,
                decoration: const InputDecoration(labelText: '结束'),
                items: widget.semester.periods
                    .where((p) => p.number >= m.start)
                    .map(
                      (p) => DropdownMenuItem(
                        value: p.number,
                        child: Text('${p.number} 节'),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => m.end = v!),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: m.room,
          maxLength: 120,
          decoration: const InputDecoration(
            labelText: '教室（选填）',
            hintText: '例如：博学楼 A301',
            counterText: '',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: m.weeks,
          decoration: const InputDecoration(
            labelText: '上课周次',
            hintText: '例如：1 3 5 8-12',
            helperText: '可自定义周次，用空格或逗号分隔，支持 8-12 范围',
            helperMaxLines: 2,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          children: ['全部周', '仅单周', '仅双周']
              .asMap()
              .entries
              .map(
                (entry) => TextButton(
                  onPressed: () {
                    final values =
                        List.generate(widget.semester.weekCount, (i) => i + 1)
                            .where(
                              (w) =>
                                  entry.key == 0 ||
                                  (entry.key == 1 ? w.isOdd : w.isEven),
                            )
                            .toList();
                    m.weeks.text = formatWeeks(values);
                  },
                  child: Text(
                    entry.value,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    ),
  );
}
