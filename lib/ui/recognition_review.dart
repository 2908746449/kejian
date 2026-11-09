import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../data/timetable_recognition.dart';
import '../domain/models.dart';
import 'course_editor.dart';
import 'settings_page.dart';
import 'theme.dart';

class DocumentImportSelection {
  final ScheduleData data;
  final bool append;
  const DocumentImportSelection(this.data, this.append);
}

class RecognitionReview extends StatefulWidget {
  final RecognitionResult result;
  final Semester currentSemester;
  final String fileName;
  final Uint8List? imageBytes;
  const RecognitionReview({
    super.key,
    required this.result,
    required this.currentSemester,
    required this.fileName,
    this.imageBytes,
  });
  @override
  State<RecognitionReview> createState() => _RecognitionReviewState();
}

class _RecognitionReviewState extends State<RecognitionReview> {
  late final List<Course> courses;
  late final Set<String> included;
  late Semester semester;
  bool detectedSemester = true;
  String? error;
  bool get hasDetected =>
      widget.result.firstMonday != null ||
      widget.result.semesterName != null ||
      widget.result.weekCount != null;
  bool get canAppend =>
      semester.firstMonday == widget.currentSemester.firstMonday &&
      semester.weekCount == widget.currentSemester.weekCount &&
      jsonEncode(semester.periods.map((p) => p.toJson()).toList()) ==
          jsonEncode(
            widget.currentSemester.periods.map((p) => p.toJson()).toList(),
          );

  Semester detected() => Semester(
    name: widget.result.semesterName ?? widget.currentSemester.name,
    firstMonday:
        widget.result.firstMonday ?? widget.currentSemester.firstMonday,
    weekCount: widget.result.weekCount ?? widget.currentSemester.weekCount,
    periods: widget.currentSemester.periods,
  );
  @override
  void initState() {
    super.initState();
    courses = [...widget.result.courses];
    included = courses.map((c) => c.id).toSet();
    semester = hasDetected ? detected() : widget.currentSemester;
  }

  Future<void> edit(Course? course) async {
    if (course != null &&
        course.meetings.any((m) => m.endPeriod > semester.periods.length)) {
      setState(() => error = '这门课超出当前节次数，请先在「修改学期与作息」中增加节次。');
      return;
    }
    final value = await editCourse(context, semester, course: course);
    if (value == null || !mounted) return;
    setState(() {
      if (course == null) {
        courses.add(value);
        included.add(value.id);
      } else {
        courses[courses.indexWhere((c) => c.id == course.id)] = value;
      }
      error = null;
    });
  }

  Future<void> editTerm() async {
    final value = await editSemester(context, semester);
    if (value != null && mounted) {
      setState(() {
        semester = value;
        error = null;
      });
    }
  }

  void finish(bool append) {
    try {
      final selected = courses.where((c) => included.contains(c.id)).toList();
      if (selected.isEmpty) {
        throw const FormatException('请至少选择一门课程，或手动补充识别遗漏的课程。');
      }
      final result = ScheduleData(semester: semester, courses: selected);
      result.validate();
      Navigator.pop(context, DocumentImportSelection(result, append));
    } on FormatException catch (e) {
      setState(() => error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = courses.where((c) => included.contains(c.id)).toList();
    final count = selected.fold<int>(0, (n, c) => n + c.meetings.length);
    final pending = selected.where((c) => c.meetings.isEmpty).length;
    return Scaffold(
      appBar: AppBar(title: const Text('识别结果核对'), backgroundColor: paper),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  children: [
                    const Text(
                      '把这一学期，带进课间。',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.fileName,
                      style: const TextStyle(color: muted, fontSize: 12),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _tag('$count 组上课安排'),
                        _tag('${selected.length} 门课程'),
                        if (pending > 0) _tag('$pending 门待安排'),
                        _tag(
                          widget.result.pages.any((p) => p.isOcr)
                              ? '本地图片识别'
                              : 'PDF 文字提取',
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Surface(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '先核对学期与作息',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                          if (hasDetected)
                            SwitchListTile.adaptive(
                              contentPadding: EdgeInsets.zero,
                              title: const Text(
                                '使用识别到的学期',
                                style: TextStyle(fontSize: 14),
                              ),
                              subtitle: const Text('关闭后使用当前学期'),
                              value: detectedSemester,
                              onChanged: (v) => setState(() {
                                detectedSemester = v;
                                semester = v
                                    ? detected()
                                    : widget.currentSemester;
                                error = null;
                              }),
                            ),
                          const SizedBox(height: 8),
                          Text(
                            '${semester.name}\n第一周周一：${dateKey(semester.firstMonday)} · ${semester.weekCount} 周\n每天 ${semester.periods.length} 节，请按学校作息核对钟点时刻',
                            style: const TextStyle(height: 1.8, fontSize: 13),
                          ),
                          TextButton.icon(
                            onPressed: editTerm,
                            icon: const Icon(Icons.tune, size: 17),
                            label: const Text('修改学期与作息'),
                          ),
                          for (final warning in widget.result.warnings)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                '• $warning',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF98694D),
                                  height: 1.6,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (widget.imageBytes != null) ...[
                      const SizedBox(height: 14),
                      Surface(
                        padding: const EdgeInsets.all(10),
                        child: ExpansionTile(
                          tilePadding: const EdgeInsets.symmetric(
                            horizontal: 6,
                          ),
                          title: const Text(
                            '查看课表原图',
                            style: TextStyle(fontSize: 14),
                          ),
                          children: [
                            SizedBox(
                              height: 320,
                              child: InteractiveViewer(
                                minScale: .5,
                                maxScale: 6,
                                child: Image.memory(
                                  widget.imageBytes!,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            '逐门核对，可编辑或取消勾选',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () => edit(null),
                          icon: const Icon(Icons.add, size: 17),
                          label: const Text('补充课程'),
                        ),
                      ],
                    ),
                    if (courses.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 22),
                        child: Text(
                          '没有识别出可导入的课程。可查看下方原文并手动补充，或换一张完整、清晰、摆正的课表。',
                          style: TextStyle(color: muted, height: 1.8),
                        ),
                      ),
                    for (final c in courses)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: _courseCard(c),
                      ),
                    if (widget.result.unparsed.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Surface(
                        child: ExpansionTile(
                          tilePadding: EdgeInsets.zero,
                          title: Text(
                            '未识别原文 · ${widget.result.unparsed.length} 段',
                            style: const TextStyle(fontSize: 14),
                          ),
                          children: [
                            SelectableText(
                              widget.result.unparsed.join('\n\n'),
                              style: const TextStyle(fontSize: 12, height: 1.7),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: lineColor)),
                ),
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            error!,
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      const Text(
                        '替换会覆盖当前课程与调课记录。保存前请核对上方结果。',
                        style: TextStyle(color: muted, fontSize: 11),
                      ),
                      if (!canAppend)
                        const Padding(
                          padding: EdgeInsets.only(top: 4),
                          child: Text(
                            '追加课程需使用与当前课表一致的学期及作息。',
                            style: TextStyle(color: muted, fontSize: 11),
                          ),
                        ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: canAppend ? () => finish(true) : null,
                              child: const Text('追加课程'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton(
                              onPressed: () => finish(false),
                              child: const Text('确认替换课表'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tag(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: const Color(0xFFE8EEE2),
      borderRadius: BorderRadius.circular(9),
    ),
    child: Text(text, style: const TextStyle(fontSize: 12, color: green)),
  );
  Widget _courseCard(Course c) {
    final entry = widget.result.entries
        .where((e) => e.course.id == c.id)
        .firstOrNull;
    return Surface(
      padding: const EdgeInsets.fromLTRB(12, 10, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Checkbox(
                value: included.contains(c.id),
                onChanged: (v) => setState(() {
                  if (v == true) {
                    included.add(c.id);
                  } else {
                    included.remove(c.id);
                  }
                }),
              ),
              Expanded(
                child: Text(
                  c.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => edit(c),
                tooltip: '编辑 ${c.name}',
                icon: const Icon(Icons.edit_outlined, size: 19),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  c.teacher.isEmpty ? '教师待补充' : c.teacher,
                  style: const TextStyle(fontSize: 12, color: muted),
                ),
                const SizedBox(height: 8),
                if (c.meetings.isEmpty)
                  const Text(
                    '待安排 · 补充星期和节次后显示在课表中',
                    style: TextStyle(fontSize: 12, color: green),
                  ),
                for (final m in c.meetings)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      '${weekdays[m.weekday - 1]} · 第 ${m.startPeriod}—${m.endPeriod} 节 · ${m.room.isEmpty ? "地点待定" : m.room}\n第 ${formatWeeks(m.weeks)} 周',
                      style: const TextStyle(fontSize: 13, height: 1.8),
                    ),
                  ),
                if (entry != null) ...[
                  for (final warning in entry.warnings)
                    Text(
                      warning,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF98694D),
                        height: 1.7,
                      ),
                    ),
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(
                      '识别原文 · 第 ${entry.page} 页',
                      style: const TextStyle(fontSize: 11, color: muted),
                    ),
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: SelectableText(
                          entry.source,
                          style: const TextStyle(fontSize: 12, height: 1.7),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
