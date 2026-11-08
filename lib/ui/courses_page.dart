import 'package:flutter/material.dart';

import '../domain/models.dart';
import 'theme.dart';

class CoursesPage extends StatefulWidget {
  final ScheduleData data;
  final ValueChanged<Course> onEdit, onDelete;
  final VoidCallback onAdd, onImport, onTemplate;
  const CoursesPage({
    super.key,
    required this.data,
    required this.onEdit,
    required this.onDelete,
    required this.onAdd,
    required this.onImport,
    required this.onTemplate,
  });
  @override
  State<CoursesPage> createState() => _CoursesPageState();
}

class _CoursesPageState extends State<CoursesPage> {
  String query = '';
  @override
  Widget build(BuildContext context) {
    final courses = widget.data.courses
        .where(
          (c) =>
              '${c.name} ${c.teacher} ${c.meetings.map((m) => m.room).join(' ')}'
                  .toLowerCase()
                  .contains(query.toLowerCase()),
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PageTitle(
          eyebrow: 'A SEMESTER OF POSSIBILITIES',
          title: '这一学期的相遇。',
          subtitle: '共 ${widget.data.courses.length} 门课程，慢慢积累每一点新知。',
        ),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            FilledButton.icon(
              onPressed: widget.onAdd,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('添加课程'),
            ),
            OutlinedButton.icon(
              onPressed: widget.onImport,
              icon: const Icon(Icons.file_upload_outlined, size: 18),
              label: const Text('导入课表'),
            ),
            TextButton(
              onPressed: widget.onTemplate,
              child: const Text('下载 CSV 模板'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        TextField(
          onChanged: (v) => setState(() => query = v),
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search, size: 21),
            hintText: '搜索课程、教师或教室',
          ),
        ),
        const SizedBox(height: 20),
        if (courses.isEmpty)
          Surface(
            child: SizedBox(
              width: double.infinity,
              child: EmptyState(
                title: query.isEmpty ? '课程列表还是空的' : '没有找到相关课程',
                subtitle: query.isEmpty ? '手动添加，或从 CSV 文件导入。' : '换个关键词试试看。',
              ),
            ),
          ),
        for (final course in courses)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Surface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: courseColors[course.color],
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Icon(
                          Icons.menu_book_outlined,
                          size: 21,
                          color: courseInks[course.color],
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              course.name,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              course.teacher.isEmpty ? '教师待补充' : course.teacher,
                              style: const TextStyle(
                                fontSize: 12,
                                color: muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuButton<String>(
                        tooltip: '课程操作',
                        onSelected: (value) => value == 'edit'
                            ? widget.onEdit(course)
                            : widget.onDelete(course),
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'edit', child: Text('编辑课程')),
                          PopupMenuItem(value: 'delete', child: Text('删除课程')),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  for (final m in course.meetings)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.schedule, size: 15, color: muted),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              '${weekdays[m.weekday - 1]} · 第 ${m.startPeriod}—${m.endPeriod} 节  ${m.room.isEmpty ? '' : '· ${m.room}'}\n第 ${formatWeeks(m.weeks)} 周',
                              style: const TextStyle(
                                fontSize: 12,
                                color: muted,
                                height: 1.8,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (course.note.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        course.note,
                        style: const TextStyle(fontSize: 12, color: green),
                      ),
                    ),
                  const SizedBox(height: 4),
                  TextButton(
                    onPressed: () => widget.onEdit(course),
                    child: const Text('编辑课程安排', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
