import 'package:flutter/material.dart';

import '../data/defaults.dart';
import '../domain/models.dart';
import '../platform/widget_bridge.dart';
import 'theme.dart';

class SettingsPage extends StatelessWidget {
  final ScheduleData data;
  final VoidCallback onSemester, onExport, onImport, onClear;
  final ValueChanged<bool> onWeekends;
  final bool supportsWidgets;
  final String? widgetError;
  final VoidCallback? onWidgetSync;
  final bool androidWidgets, addingWidget;
  final AndroidWidgetStatus? androidWidgetStatus;
  final String? widgetAddMessage;
  final VoidCallback? onWidgetAdd;
  const SettingsPage({
    super.key,
    required this.data,
    required this.onSemester,
    required this.onExport,
    required this.onImport,
    required this.onClear,
    required this.onWeekends,
    this.supportsWidgets = false,
    this.widgetError,
    this.onWidgetSync,
    this.androidWidgets = false,
    this.addingWidget = false,
    this.androidWidgetStatus,
    this.widgetAddMessage,
    this.onWidgetAdd,
  });
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const PageTitle(
        eyebrow: 'MAKE IT YOURS',
        title: '按你的节奏来。',
        subtitle: '从学期到作息，让课表适合你。',
      ),
      Surface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '学期与作息',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_month_outlined, color: green),
              title: Text(data.semester.name),
              subtitle: Text(
                '第一教学周：${dateKey(data.semester.firstMonday)} 起\n共 ${data.semester.weekCount} 周 · ${usesKailiUniversityPeriods(data.semester.periods) ? '凯里学院作息' : '每天 ${data.semester.periods.length} 节'}',
              ),
              isThreeLine: true,
              trailing: const Icon(Icons.chevron_right),
              onTap: onSemester,
            ),
            const Divider(),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('显示周末'),
              subtitle: const Text('隐藏周末不会删除周末课程'),
              value: data.showWeekends,
              onChanged: onWeekends,
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      if (supportsWidgets) ...[
        Surface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '桌面小组件',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              Text(
                androidWidgets ? '显示接下来的两门课及时间、教室。点击「添加到桌面」，再在系统弹窗中确认。' : '在手机桌面长按空白处，打开小组件列表并选择「课间」。\n显示接下来的两门课及时间、教室，点击小组件可打开 App。',
                style: const TextStyle(color: muted, fontSize: 12, height: 1.8),
              ),
              if (androidWidgets) ...[
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: addingWidget ? null : onWidgetAdd,
                  icon: const Icon(Icons.add_to_home_screen, size: 18),
                  label: Text(addingWidget ? '正在请求…' : '添加到桌面'),
                ),
                if ((androidWidgetStatus?.installedCount ?? 0) > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '桌面已添加 ${androidWidgetStatus!.installedCount} 个课间小组件',
                      style: const TextStyle(color: green, fontSize: 12),
                    ),
                  ),
                if (widgetAddMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      widgetAddMessage!,
                      style: const TextStyle(
                        color: green,
                        fontSize: 12,
                        height: 1.7,
                      ),
                    ),
                  ),
                if (androidWidgetStatus?.registered == false)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      '系统暂未识别小组件，请覆盖安装最新版后重新打开课间。',
                      style: TextStyle(color: Color(0xFFA6614A), fontSize: 12),
                    ),
                  ),
                const SizedBox(height: 8),
                const ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: EdgeInsets.only(bottom: 12),
                  title: Text('找不到课间？查看手动添加步骤', style: TextStyle(fontSize: 13)),
                  children: [
                    Text(
                      '小米 / 澎湃 OS：\n桌面双指捏合或长按空白处 → 添加小部件 → 右上角搜索 → 滑到应用列表底部 → 安卓小部件 → 课间。\n\n课间位于「安卓小部件」列表；部分系统入口名为「全部应用小部件」。\n\n其他桌面：\n长按桌面空白处 → 小组件 → 课间，长按或拖动到桌面。\n\n如果点击按钮没有弹窗，请按上述路径手动添加；Android 7 也请使用手动方式。',
                      style: TextStyle(color: muted, fontSize: 12, height: 1.8),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              Text(
                widgetError ?? '课表修改后会自动同步；实际刷新时间由系统安排。',
                style: TextStyle(
                  color: widgetError == null ? muted : const Color(0xFFA6614A),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: onWidgetSync,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('重新同步小组件'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
      ],
      Surface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '数据与备份',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              '课表保存在当前设备。更换设备前，记得导出备份。',
              style: TextStyle(color: muted, fontSize: 12, height: 1.6),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.file_download_outlined, color: green),
              title: const Text('导出完整备份'),
              subtitle: const Text('包含课程、作息、调课记录和设置'),
              trailing: const Icon(Icons.chevron_right),
              onTap: onExport,
            ),
            const Divider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.restore_outlined, color: green),
              title: const Text('从备份恢复'),
              subtitle: const Text('先预览，再确认替换当前课表'),
              trailing: const Icon(Icons.chevron_right),
              onTap: onImport,
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      Surface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '关于课间',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 14),
            const Text(
              '一个留白多一点的大学课程表。\n免登录，无广告。你的课表，由你掌握。',
              style: TextStyle(color: muted, height: 1.8),
            ),
            const SizedBox(height: 16),
            const Row(
              children: [
                Icon(Icons.code, size: 17, color: green),
                SizedBox(width: 8),
                Text(
                  '开源 · MIT · v0.3.2',
                  style: TextStyle(color: green, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => showAboutDialog(
                context: context,
                applicationName: '课间 Kejian',
                applicationVersion: '0.3.2',
                applicationLegalese: '© 2026 Kejian contributors · MIT',
                children: const [
                  Text('功能设计参考 SleepIn 与 XDYou。源码中记录了参考来源；应用界面和核心规则为独立实现。'),
                ],
              ),
              child: const Text('开源许可'),
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      TextButton.icon(
        onPressed: onClear,
        icon: const Icon(Icons.restart_alt, size: 18),
        label: const Text('清空课程，保留学期设置'),
        style: TextButton.styleFrom(foregroundColor: const Color(0xFFA6614A)),
      ),
    ],
  );
}

Future<Semester?> editSemester(BuildContext context, Semester semester) =>
    showDialog<Semester>(
      context: context,
      builder: (_) => _SemesterEditor(semester: semester),
    );

class _SemesterEditor extends StatefulWidget {
  final Semester semester;
  const _SemesterEditor({required this.semester});
  @override
  State<_SemesterEditor> createState() => _SemesterEditorState();
}

class _SemesterEditorState extends State<_SemesterEditor> {
  late final TextEditingController name, count;
  late DateTime monday;
  late final List<TextEditingController> starts, ends;
  String? error;
  @override
  void initState() {
    super.initState();
    name = TextEditingController(text: widget.semester.name);
    count = TextEditingController(text: '${widget.semester.weekCount}');
    monday = widget.semester.firstMonday;
    starts = widget.semester.periods
        .map((p) => TextEditingController(text: p.start))
        .toList();
    ends = widget.semester.periods
        .map((p) => TextEditingController(text: p.end))
        .toList();
  }

  @override
  void dispose() {
    for (final c in [name, count, ...starts, ...ends]) {
      c.dispose();
    }
    super.dispose();
  }

  void save() {
    try {
      final s = Semester(
        name: name.text.trim(),
        firstMonday: monday,
        weekCount: int.tryParse(count.text) ?? 0,
        periods: List.generate(
          starts.length,
          (i) => Period(i + 1, starts[i].text.trim(), ends[i].text.trim()),
        ),
      );
      ScheduleData(semester: s, courses: []).validate();
      Navigator.pop(context, s);
    } on FormatException catch (e) {
      setState(() => error = e.message);
    }
  }

  void addPeriod() {
    try {
      final start = timeMinutes(ends.last.text.trim()) + 10;
      if (start + 45 >= 24 * 60) {
        throw const FormatException('新增节次超出当天，请先调整最后一节的时间。');
      }
      String time(int n) =>
          '${(n ~/ 60).toString().padLeft(2, '0')}:${(n % 60).toString().padLeft(2, '0')}';
      setState(() {
        starts.add(TextEditingController(text: time(start)));
        ends.add(TextEditingController(text: time(start + 45)));
        error = null;
      });
    } on FormatException catch (e) {
      setState(() => error = e.message);
    }
  }

  void useKailiUniversityPeriods() {
    setState(() {
      for (final controller in [...starts, ...ends]) {
        controller.dispose();
      }
      starts
        ..clear()
        ..addAll(
          kailiUniversityPeriods.map(
            (p) => TextEditingController(text: p.start),
          ),
        );
      ends
        ..clear()
        ..addAll(
          kailiUniversityPeriods.map((p) => TextEditingController(text: p.end)),
        );
      error = null;
    });
  }

  @override
  Widget build(BuildContext context) => Dialog(
    insetPadding: const EdgeInsets.all(16),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 12, 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    '学期与作息',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 22),
                  ),
                ),
                IconButton(
                  tooltip: '关闭',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: name,
                    maxLength: 100,
                    decoration: const InputDecoration(
                      labelText: '学期名称',
                      counterText: '',
                    ),
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: monday,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (date != null && mounted) {
                        setState(
                          () => monday = addDays(date, 1 - date.weekday),
                        );
                      }
                    },
                    icon: const Icon(Icons.calendar_today_outlined, size: 18),
                    label: Text('第一周的周一：${dateKey(monday)}'),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '如果周中开学，选择开学日即可，系统会定位到该周周一。',
                    style: TextStyle(fontSize: 12, color: muted),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: count,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: '总教学周数（1—52）'),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    '每天的作息时间',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '使用 24 小时制，例如 08:00。新增节次的时间为参考值，请按学校作息修改。',
                    style: TextStyle(fontSize: 12, color: muted),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: useKailiUniversityPeriods,
                    icon: const Icon(Icons.schedule, size: 17),
                    label: const Text('使用凯里学院作息'),
                  ),
                  const SizedBox(height: 14),
                  for (var i = 0; i < starts.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 48,
                            child: Text(
                              '第 ${i + 1} 节',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          Expanded(
                            child: TextField(
                              controller: starts[i],
                              keyboardType: TextInputType.datetime,
                              decoration: const InputDecoration(
                                labelText: '开始',
                              ),
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 10),
                            child: Text('—'),
                          ),
                          Expanded(
                            child: TextField(
                              controller: ends[i],
                              keyboardType: TextInputType.datetime,
                              decoration: const InputDecoration(
                                labelText: '结束',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  Wrap(
                    spacing: 8,
                    children: [
                      if (starts.length < 16)
                        TextButton.icon(
                          onPressed: addPeriod,
                          icon: const Icon(Icons.add, size: 17),
                          label: const Text('增加一节'),
                        ),
                      if (starts.length > 1)
                        TextButton.icon(
                          onPressed: () => setState(() {
                            starts.removeLast().dispose();
                            ends.removeLast().dispose();
                          }),
                          icon: const Icon(Icons.remove, size: 17),
                          label: const Text('移除最后一节'),
                        ),
                    ],
                  ),
                  if (error != null)
                    Text(error!, style: const TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(onPressed: save, child: const Text('保存设置')),
            ),
          ),
        ],
      ),
    ),
  );
}
