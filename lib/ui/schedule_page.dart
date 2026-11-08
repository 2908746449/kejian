import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../domain/models.dart';
import '../domain/engine.dart';
import '../domain/agenda.dart';
import 'theme.dart';

class SchedulePage extends StatelessWidget {
  final ScheduleData data;
  final int week;
  final DateTime now;
  final ValueChanged<int> onWeek;
  final ValueChanged<Lesson> onLesson;
  final ValueChanged<LessonException> onRestore;
  final VoidCallback onAdd, onStart;
  const SchedulePage({
    super.key,
    required this.data,
    required this.week,
    required this.now,
    required this.onWeek,
    required this.onLesson,
    required this.onRestore,
    required this.onAdd,
    required this.onStart,
  });
  @override
  Widget build(BuildContext context) {
    final lessons = lessonsInWeek(data, week);
    final current = data.semester.weekOf(now);
    final monday = data.semester.dateAt(week, 1),
        sunday = data.semester.dateAt(week, 7);
    final changes = data.exceptions
        .where(
          (e) =>
              data.semester.weekOf(e.originalDate) == week ||
              (e.targetDate != null &&
                  data.semester.weekOf(e.targetDate!) == week),
        )
        .toList();
    final compact = MediaQuery.sizeOf(context).width < 650;
    final agenda = agendaPreview(data, now);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PageTitle(
          eyebrow: compact ? '' : 'A LITTLE SPACE BETWEEN CLASSES',
          title: compact ? '我的课表' : '课间，留一点从容。',
          subtitle: data.semester.name,
          action: compact
              ? IconButton.filled(
                  onPressed: onAdd,
                  icon: const Icon(Icons.add),
                  tooltip: '添加课程',
                )
              : FilledButton.icon(
                  onPressed: onAdd,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('添加课程'),
                ),
        ),
        if (data.isDemo)
          Container(
            margin: const EdgeInsets.only(bottom: 18),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFEDF0E7),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome_outlined, size: 17, color: green),
                const SizedBox(width: 9),
                const Expanded(
                  child: Text(
                    '正在体验示例课表',
                    style: TextStyle(fontSize: 12, color: green),
                  ),
                ),
                TextButton(
                  onPressed: onStart,
                  child: const Text('建立我的课表', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
        _nextCard(context, agenda.next),
        if (data.courses.isNotEmpty) _followingCards(context, agenda),
        const SizedBox(height: 26),
        Row(
          children: [
            const Text(
              '本周课表',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            if (week != current &&
                current >= 1 &&
                current <= data.semester.weekCount)
              TextButton(
                onPressed: () => onWeek(current),
                child: const Text('回到本周'),
              ),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: lineColor),
              ),
              child: Row(
                children: [
                  IconButton(
                    tooltip: '上一周',
                    visualDensity: VisualDensity.compact,
                    onPressed: week > 1 ? () => onWeek(week - 1) : null,
                    icon: const Icon(Icons.chevron_left, size: 20),
                  ),
                  InkWell(
                    onTap: () => _pickWeek(context),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 3,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Text(
                            '第 $week 周',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          const Icon(Icons.expand_more, size: 17),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '下一周',
                    visualDensity: VisualDensity.compact,
                    onPressed: week < data.semester.weekCount
                        ? () => onWeek(week + 1)
                        : null,
                    icon: const Icon(Icons.chevron_right, size: 20),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          '${monday.month} 月 ${monday.day} 日 — ${sunday.month} 月 ${sunday.day} 日  ·  ${lessons.length} 次课程${current < 1 || current > data.semester.weekCount ? '  ·  当前不在学期内' : ''}',
          style: const TextStyle(color: muted, fontSize: 12),
        ),
        const SizedBox(height: 16),
        if (data.courses.isEmpty)
          Surface(
            child: SizedBox(
              width: double.infinity,
              child: EmptyState(
                title: '新的学期，从这里开始',
                subtitle: '添加第一门课程，或到「课程」导入课表。',
                action: FilledButton.icon(
                  onPressed: onAdd,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('添加第一门课'),
                ),
              ),
            ),
          )
        else
          _WeekGrid(
            data: data,
            lessons: lessons,
            week: week,
            now: now,
            onLesson: onLesson,
          ),
        if (lessons.isEmpty && data.courses.isNotEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Text('这一周没有课程，留些时间给自己。', style: TextStyle(color: muted)),
          ),
        if (conflictKeys(lessons).isNotEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Color(0xFFA6614A), size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '有课程时间重叠，已并排显示。点击课程查看详情。',
                    style: TextStyle(color: Color(0xFFA6614A), fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        if (changes.isNotEmpty) ...[
          const SizedBox(height: 20),
          Surface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '本周变更',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                for (final e in changes)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(
                      '${_courseFor(e)} · ${e.cancelled ? '已停课' : '已调课'}',
                    ),
                    subtitle: Text(
                      '原定 ${e.originalDate.month}/${e.originalDate.day}${e.cancelled ? '' : ' → ${e.targetDate!.month}/${e.targetDate!.day}'}',
                    ),
                    trailing: TextButton(
                      onPressed: () => onRestore(e),
                      child: const Text('撤销'),
                    ),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 18),
        const Center(
          child: Text(
            '好好上课，也好好生活。',
            style: TextStyle(color: muted, fontSize: 11, letterSpacing: 1),
          ),
        ),
      ],
    );
  }

  String _courseFor(LessonException e) => data.courses
      .firstWhere((c) => c.meetings.any((m) => m.id == e.meetingId))
      .name;
  Widget _followingCards(BuildContext context, AgendaPreview agenda) {
    final items = agenda.following;
    final title = agenda.tomorrow ? '明天的安排' : '今天还有 ${items.length} 门课';
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: muted, fontSize: 12)),
          const SizedBox(height: 9),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Text(
                '明天没有其他课程，留些时间给自己。',
                style: TextStyle(color: muted, fontSize: 12),
              ),
            )
          else if (items.length == 1)
            _nextCard(
              context,
              items.single,
              label: agenda.tomorrow ? '明日课程' : '今日后续',
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final width =
                    ((constraints.maxWidth - (items.length - 1) * 10) /
                            items.length)
                        .clamp(112.0, 220.0);
                return SizedBox(
                  height: 128,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 10),
                    itemBuilder: (context, i) {
                      final lesson = items[i];
                      final start =
                          data.semester.periods[lesson.startPeriod - 1].start;
                      final end =
                          data.semester.periods[lesson.endPeriod - 1].end;
                      return SizedBox(
                        width: width,
                        child: Material(
                          color: const Color(0xFFE8EDDF),
                          borderRadius: BorderRadius.circular(16),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => onLesson(lesson),
                            child: Padding(
                              padding: const EdgeInsets.all(13),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '$start—$end',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: green,
                                      fontSize: 11,
                                    ),
                                  ),
                                  const SizedBox(height: 9),
                                  Text(
                                    lesson.course.name,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    lesson.room.isEmpty ? '教室待补充' : lesson.room,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: green,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _nextCard(BuildContext context, Lesson? next, {String? label}) {
    final active = next != null && !next.start(data.semester).isAfter(now);
    final subtitle = next == null
        ? '这一学期的安排已经完成，给自己放个小假。'
        : '${weekdays[next.date.weekday - 1]} ${next.date.month}/${next.date.day}  ·  ${data.semester.periods[next.startPeriod - 1].start}—${data.semester.periods[next.endPeriod - 1].end}';
    if (MediaQuery.sizeOf(context).width < 650) {
      return Material(
        color: const Color(0xFFE8EDDF),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: next == null ? null : () => onLesson(next),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.menu_book_outlined, color: green, size: 26),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label ?? (active ? '正在上课' : '下一节课'),
                        style: const TextStyle(color: green, fontSize: 10),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        next?.course.name ?? '享受一段自由时光',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        next == null
                            ? '暂无后续课程'
                            : '$subtitle\n${next.room.isEmpty ? '教室待补充' : next.room}',
                        style: const TextStyle(
                          color: green,
                          fontSize: 11,
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                ),
                if (next != null)
                  const Icon(Icons.chevron_right, color: green, size: 18),
              ],
            ),
          ),
        ),
      );
    }
    return Material(
      color: const Color(0xFFE8EDDF),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: next == null ? null : () => onLesson(next),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: green,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 7),
                        Text(
                          label ??
                              (active
                                  ? '正在上课'
                                  : next == null
                                  ? '暂时没有下一节课'
                                  : '下一节课'),
                          style: const TextStyle(
                            fontSize: 11,
                            color: green,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      next?.course.name ?? '享受一段自由时光',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 9),
                    Text(
                      subtitle,
                      style: const TextStyle(color: green, fontSize: 12),
                    ),
                    if (next != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(
                            Icons.place_outlined,
                            color: green,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              next.room.isEmpty ? '教室待补充' : next.room,
                              style: const TextStyle(
                                color: green,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  next == null ? Icons.spa_outlined : Icons.menu_book_outlined,
                  size: 30,
                  color: green,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickWeek(BuildContext context) async {
    final picked = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('切换教学周'),
        content: SizedBox(
          width: 340,
          child: SingleChildScrollView(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(
                data.semester.weekCount,
                (i) => ChoiceChip(
                  label: Text('第 ${i + 1} 周'),
                  selected: week == i + 1,
                  onSelected: (_) => Navigator.pop(ctx, i + 1),
                ),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
    if (picked != null) onWeek(picked);
  }
}

class _Placed {
  final Lesson lesson;
  final int lane, lanes;
  const _Placed(this.lesson, this.lane, this.lanes);
}

List<_Placed> _positions(List<Lesson> lessons) {
  final result = <_Placed>[];
  var index = 0;
  while (index < lessons.length) {
    final cluster = <Lesson>[lessons[index++]];
    var end = cluster.first.endPeriod;
    while (index < lessons.length && lessons[index].startPeriod <= end) {
      final lesson = lessons[index++];
      cluster.add(lesson);
      end = math.max(end, lesson.endPeriod);
    }
    final laneEnds = <int>[], assignments = <int>[];
    for (final lesson in cluster) {
      var lane = laneEnds.indexWhere((end) => end < lesson.startPeriod);
      if (lane == -1) {
        lane = laneEnds.length;
        laneEnds.add(0);
      }
      laneEnds[lane] = lesson.endPeriod;
      assignments.add(lane);
    }
    for (var i = 0; i < cluster.length; i++) {
      result.add(_Placed(cluster[i], assignments[i], laneEnds.length));
    }
  }
  return result;
}

class _WeekGrid extends StatelessWidget {
  final ScheduleData data;
  final List<Lesson> lessons;
  final int week;
  final DateTime now;
  final ValueChanged<Lesson> onLesson;
  const _WeekGrid({
    required this.data,
    required this.lessons,
    required this.week,
    required this.now,
    required this.onLesson,
  });
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxWidth < 600;
      final rowHeight = compact ? 62.0 : 66.0,
          timeWidth = compact ? 33.0 : 52.0;
      final dayCount = data.showWeekends ? 7 : 5;
      final width = math.max(constraints.maxWidth, 335.0);
      final column = (width - timeWidth) / dayCount;
      final conflicts = conflictKeys(lessons);
      return ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: lineColor),
            borderRadius: BorderRadius.circular(20),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: width,
              child: Column(
                children: [
                  Row(
                    children: [
                      SizedBox(
                        width: timeWidth,
                        height: 66,
                        child: Center(
                          child: Text(
                            '${data.semester.dateAt(week, 1).month}月',
                            style: TextStyle(
                              color: muted,
                              fontSize: compact ? 10 : 12,
                            ),
                          ),
                        ),
                      ),
                      for (var d = 1; d <= dayCount; d++)
                        SizedBox(
                          width: column,
                          height: 66,
                          child: _dayHeader(d),
                        ),
                    ],
                  ),
                  SizedBox(
                    height: rowHeight * data.semester.periods.length,
                    child: Stack(
                      children: [
                        for (var d = 1; d <= dayCount; d++)
                          Positioned(
                            left: timeWidth + (d - 1) * column,
                            top: 0,
                            bottom: 0,
                            width: column,
                            child: Container(
                              decoration: BoxDecoration(
                                color:
                                    dateKey(data.semester.dateAt(week, d)) ==
                                        dateKey(now)
                                    ? const Color(0xFFF6F8F1)
                                    : Colors.transparent,
                                border: const Border(
                                  left: BorderSide(
                                    color: lineColor,
                                    width: 0.5,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        for (var i = 0; i < data.semester.periods.length; i++)
                          Positioned(
                            left: 0,
                            right: 0,
                            top: i * rowHeight,
                            height: rowHeight,
                            child: Container(
                              decoration: const BoxDecoration(
                                border: Border(
                                  top: BorderSide(color: lineColor, width: 0.5),
                                ),
                              ),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: SizedBox(
                                  width: timeWidth,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        '${i + 1}'.padLeft(2, '0'),
                                        style: const TextStyle(
                                          color: muted,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        data.semester.periods[i].start,
                                        style: TextStyle(
                                          color: muted,
                                          fontSize: compact ? 8 : 10,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        for (var d = 1; d <= dayCount; d++)
                          for (final placed in _positions(
                            lessons.where((l) => l.date.weekday == d).toList(),
                          ))
                            Positioned(
                              left:
                                  timeWidth +
                                  (d - 1) * column +
                                  placed.lane * column / placed.lanes +
                                  2,
                              top:
                                  (placed.lesson.startPeriod - 1) * rowHeight +
                                  3,
                              width: column / placed.lanes - 4,
                              height:
                                  (placed.lesson.endPeriod -
                                          placed.lesson.startPeriod +
                                          1) *
                                      rowHeight -
                                  6,
                              child: _lessonCard(
                                placed.lesson,
                                compact,
                                conflicts.contains(placed.lesson.key),
                              ),
                            ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
  Widget _dayHeader(int d) {
    final date = data.semester.dateAt(week, d),
        today = dateKey(data.semester.dateAt(week, d)) == dateKey(now);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          weekdays[d - 1],
          style: TextStyle(fontSize: 10, color: today ? green : muted),
        ),
        const SizedBox(height: 5),
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: today ? green : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(
            '${date.day}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: today ? Colors.white : ink,
            ),
          ),
        ),
      ],
    );
  }

  Widget _lessonCard(Lesson lesson, bool compact, bool conflict) => Semantics(
    button: true,
    label:
        '${lesson.course.name}，${weekdays[lesson.date.weekday - 1]}，第 ${lesson.startPeriod} 到 ${lesson.endPeriod} 节，${lesson.room}${conflict ? '，时间冲突' : ''}',
    child: Material(
      color: courseColors[lesson.course.color],
      borderRadius: BorderRadius.circular(compact ? 8 : 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => onLesson(lesson),
        child: Container(
          padding: EdgeInsets.all(compact ? 5 : 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(compact ? 8 : 12),
            border: conflict
                ? Border.all(color: const Color(0xFFB96D56), width: 1.5)
                : null,
          ),
          child: LayoutBuilder(
            builder: (context, box) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (lesson.changed && box.maxHeight > 90)
                  Text(
                    '调课',
                    style: TextStyle(
                      fontSize: 8,
                      color: courseInks[lesson.course.color],
                    ),
                  ),
                Text(
                  lesson.course.name,
                  maxLines: box.maxHeight < 80 ? 2 : 4,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: compact ? 10 : 13,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                    color: courseInks[lesson.course.color],
                  ),
                ),
                if (box.maxHeight > 70) ...[
                  const SizedBox(height: 7),
                  Flexible(
                    child: Text(
                      lesson.room,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: compact ? 9 : 11,
                        height: 1.35,
                        color: courseInks[lesson.course.color].withValues(
                          alpha: 0.8,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
