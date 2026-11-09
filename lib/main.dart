import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:file_picker/file_picker.dart';

import 'data/demo.dart';
import 'data/importer.dart';
import 'data/document_recognizer.dart';
import 'data/timetable_recognition.dart';
import 'data/repository.dart';
import 'domain/models.dart';
import 'domain/engine.dart';
import 'platform/widget_bridge.dart';
import 'ui/theme.dart';
import 'ui/course_editor.dart';
import 'ui/courses_page.dart';
import 'ui/schedule_page.dart';
import 'ui/settings_page.dart';
import 'ui/lesson_dialog.dart';
import 'ui/recognition_review.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    for (final name in ['PDFium', 'Tesseract', 'Tesseract-models']) {
      yield LicenseEntryWithLineBreaks([
        name,
      ], await rootBundle.loadString('assets/licenses/$name.txt'));
    }
  });
  runApp(KejianApp(repository: LocalScheduleRepository()));
}

class KejianApp extends StatelessWidget {
  final ScheduleRepository repository;
  final DateTime Function()? clock;
  const KejianApp({super.key, required this.repository, this.clock});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: '课间 · Kejian',
    debugShowCheckedModeBanner: false,
    theme: appTheme(),
    locale: const Locale('zh', 'CN'),
    supportedLocales: const [Locale('zh', 'CN'), Locale('en')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    home: _Home(repository: repository, clock: clock ?? DateTime.now),
  );
}

class _Home extends StatefulWidget {
  final ScheduleRepository repository;
  final DateTime Function() clock;
  const _Home({required this.repository, required this.clock});
  @override
  State<_Home> createState() => _HomeState();
}

class _HomeState extends State<_Home> with WidgetsBindingObserver {
  ScheduleData? data;
  String? loadError;
  int tab = 0, week = 1;
  bool saving = false, importing = false;
  String? widgetError;
  Timer? ticker;
  final scroll = ScrollController();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    load();
    ticker = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    ticker?.cancel();
    scroll.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      setState(() {});
      if (data != null) unawaited(syncWidgets(data!));
    }
  }

  Future<bool> syncWidgets(ScheduleData value) async {
    try {
      await WidgetBridge.sync(value);
      if (mounted) setState(() => widgetError = null);
      return true;
    } catch (_) {
      if (mounted) setState(() => widgetError = '小组件同步失败，点击重新同步。');
      return false;
    }
  }

  Future<void> load() async {
    setState(() => loadError = null);
    try {
      final stored = await widget.repository.load();
      final value = stored ?? demoData(widget.clock());
      if (stored == null) await widget.repository.save(value);
      if (mounted) {
        setState(() {
          data = value;
          week = value.semester
              .weekOf(widget.clock())
              .clamp(1, value.semester.weekCount);
        });
        unawaited(syncWidgets(value));
      }
    } catch (_) {
      if (mounted) setState(() => loadError = '暂时无法读取本地课表。原始数据已保留，请重试或检查设备存储。');
    }
  }

  void toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<bool> persist(ScheduleData value, String message) async {
    if (saving) return false;
    setState(() => saving = true);
    try {
      value.validate();
      await widget.repository.save(value);
      if (!mounted) return false;
      setState(() {
        data = value;
        week = week.clamp(1, value.semester.weekCount);
      });
      final synced = await syncWidgets(value);
      toast(synced ? message : '$message；小组件同步失败，可在设置中重试。');
      return true;
    } catch (e) {
      toast(e is FormatException ? e.message : '保存失败，当前更改未写入，请检查存储空间后重试。');
      return false;
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<bool> confirm(
    String title,
    String body, {
    String accept = '确认',
  }) async =>
      await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(title),
          content: Text(body, style: const TextStyle(height: 1.7)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(accept),
            ),
          ],
        ),
      ) ??
      false;
  void switchTab(int value) {
    setState(() => tab = value);
    if (scroll.hasClients) scroll.jumpTo(0);
  }

  Future<void> courseEditor([Course? course]) async {
    final result = await editCourse(context, data!.semester, course: course);
    if (result == null || !mounted) return;
    final courses = [...data!.courses.where((c) => c.id != result.id), result];
    final value = data!.copyWith(
      courses: courses,
      exceptions: validExceptions(data!, courses),
    );
    final oldConflicts = conflictKeys(
      lessonsBetween(
        data!,
        data!.semester.firstMonday,
        data!.semester.dateAt(data!.semester.weekCount, 7),
      ),
    );
    final newConflicts = conflictKeys(
      lessonsBetween(
        value,
        value.semester.firstMonday,
        value.semester.dateAt(value.semester.weekCount, 7),
      ),
    );
    if (newConflicts.difference(oldConflicts).isNotEmpty &&
        !await confirm(
          '存在时间重叠',
          '这门课与已有课程存在时间冲突。仍然保存后，课表中会并排显示并标记。',
          accept: '仍然保存',
        )) {
      return;
    }
    await persist(value, '课程已保存');
  }

  Future<void> deleteCourse(Course course) async {
    if (await confirm(
      '删除「${course.name}」？',
      '将同时删除这门课的所有上课安排和调课记录。',
      accept: '删除课程',
    )) {
      final courses = data!.courses.where((c) => c.id != course.id).toList();
      await persist(
        data!.copyWith(
          courses: courses,
          exceptions: validExceptions(data!, courses),
        ),
        '课程已删除',
      );
    }
  }

  Future<void> clearCourses() async {
    if (await confirm(
      data!.isDemo ? '开始建立自己的课表？' : '清空当前课程？',
      data!.isDemo
          ? '示例课程和调课记录将被清除，学期与作息设置会保留。你可以随后修改学期，再添加或导入自己的课程。'
          : '所有课程和调课记录将被清除，学期与作息设置会保留。建议先导出备份。',
      accept: data!.isDemo ? '开始建立' : '清空课程',
    )) {
      await persist(
        data!.copyWith(courses: [], exceptions: [], isDemo: false),
        '可以开始添加你的课程了',
      );
    }
  }

  Future<void> semesterEditor() async {
    final result = await editSemester(context, data!.semester);
    if (result == null || !mounted) return;
    final shift = dayDistance(result.firstMonday, data!.semester.firstMonday);
    final exceptions = data!.exceptions
        .map(
          (e) => LessonException(
            meetingId: e.meetingId,
            originalDate: addDays(e.originalDate, shift),
            cancelled: e.cancelled,
            targetDate: e.targetDate == null
                ? null
                : addDays(e.targetDate!, shift),
            startPeriod: e.startPeriod,
            endPeriod: e.endPeriod,
            room: e.room,
          ),
        )
        .toList();
    final value = data!.copyWith(semester: result, exceptions: exceptions);
    try {
      value.validate();
    } on FormatException {
      toast('现有课程或调课超出了新的学期范围，请先调整这些课程后再修改周数。');
      return;
    }
    if (shift != 0 &&
        !await confirm(
          '调整学期起始日期？',
          '课程和单次调课将按教学周整体平移 $shift 天。',
          accept: '保存设置',
        )) {
      return;
    }
    if (await persist(value, '学期与作息已保存') && mounted) {
      setState(
        () => week = result.weekOf(widget.clock()).clamp(1, result.weekCount),
      );
    }
  }

  Future<void> showLesson(Lesson lesson) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: paper,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          child: LessonDetails(lesson: lesson, semester: data!.semester),
        ),
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'edit') {
      await courseEditor(lesson.course);
      return;
    }
    if (action == 'cancel') {
      if (await confirm(
        '仅停课这一次？',
        '${lesson.course.name} · ${lesson.date.month}/${lesson.date.day}\n其他周次不受影响，可在「本周变更」中撤销。',
        accept: '确认停课',
      )) {
        final exception = LessonException(
          meetingId: lesson.meeting.id,
          originalDate: lesson.originalDate,
          cancelled: true,
        );
        await persist(
          data!.copyWith(
            exceptions: [
              ...data!.exceptions.where((e) => e.key != lesson.key),
              exception,
            ],
          ),
          '本次课程已停课',
        );
      }
      return;
    }
    if (action == 'move') {
      final exception = await moveLesson(context, lesson, data!.semester);
      if (exception == null || !mounted) return;
      final value = data!.copyWith(
        exceptions: [
          ...data!.exceptions.where((e) => e.key != lesson.key),
          exception,
        ],
      );
      final conflicts = conflictKeys(
        lessonsBetween(value, exception.targetDate!, exception.targetDate!),
      );
      if (conflicts.contains(lesson.key) &&
          !await confirm('调课后存在时间冲突', '这个时间段已有其他课程，是否仍然调整？', accept: '仍然调课')) {
        return;
      }
      await persist(value, '仅本次课程已调整');
    }
  }

  Future<void> restoreException(LessonException exception) async {
    await persist(
      data!.copyWith(
        exceptions: data!.exceptions
            .where((e) => e.key != exception.key)
            .toList(),
      ),
      '已恢复原来的上课安排',
    );
  }

  Future<void> exportFile({bool template = false}) async {
    try {
      final name = template
          ? 'kejian-template.csv'
          : 'kejian-backup-${dateKey(widget.clock())}.json';
      final source = template ? '\uFEFF$csvExample' : data!.encode();
      final result = await FilePicker.saveFile(
        fileName: name,
        bytes: Uint8List.fromList(utf8.encode(source)),
        mimeType: template ? 'text/csv' : 'application/json',
        dialogTitle: template ? '保存课程模板' : '保存课表备份',
      );
      if (result != null) toast(template ? '模板已导出' : '备份已导出');
    } catch (_) {
      toast('文件导出失败，请重试。');
    }
  }

  Future<void> importFile({bool backupOnly = false}) async {
    if (importing) return;
    importing = true;
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: backupOnly
            ? ['json']
            : ['json', 'csv', 'pdf', 'png', 'jpg', 'jpeg', 'webp'],
        dialogTitle: '选择课表文件',
      );
      if (file == null || !mounted) return;
      final builder = BytesBuilder();
      await for (final chunk in file.readAsByteStream()) {
        builder.add(chunk);
        if (builder.length > 20 * 1024 * 1024) {
          throw const FormatException('请选择 20 MB 以内的课表文件');
        }
      }
      final bytes = builder.takeBytes();
      final extension = file.name.toLowerCase().split('.').last;
      if (['pdf', 'png', 'jpg', 'jpeg', 'webp'].contains(extension)) {
        await importDocument(bytes, file.name);
        return;
      }
      if (bytes.length > 2 * 1024 * 1024) {
        throw const FormatException('CSV 和 JSON 文件请控制在 2 MB 以内');
      }
      final source = utf8.decode(bytes).replaceFirst(RegExp('^\uFEFF'), '');
      final isBackup = file.name.toLowerCase().endsWith('.json');
      final imported = isBackup
          ? ScheduleData.decode(source)
          : ScheduleData(
              semester: data!.semester,
              courses: coursesFromCsv(source, data!.semester),
            );
      if (!mounted) return;
      final mode = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('导入预览'),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${imported.courses.length} 门课程 · ${imported.courses.fold<int>(0, (n, c) => n + c.meetings.length)} 组上课安排',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isBackup
                        ? '${imported.semester.name}\n${imported.exceptions.length} 条单次变更，学期与作息一起恢复。'
                        : '使用当前学期「${data!.semester.name}」的作息。',
                  ),
                  const SizedBox(height: 16),
                  for (final c in imported.courses.take(15))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text('• ${c.name} · ${c.teacher}'),
                    ),
                  if (imported.courses.length > 15) const Text('…'),
                  const SizedBox(height: 12),
                  const Text(
                    '替换会覆盖当前课程，请确认已保留需要的数据。',
                    style: TextStyle(color: Color(0xFFA6614A), fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            if (!isBackup)
              OutlinedButton(
                onPressed: () => Navigator.pop(ctx, 'append'),
                child: const Text('追加课程'),
              ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, 'replace'),
              child: const Text('替换当前课表'),
            ),
          ],
        ),
      );
      if (mode == null || !mounted) return;
      await applyImported(imported, mode, isBackup: isBackup);
    } on FormatException catch (e) {
      toast(e.message);
    } catch (_) {
      toast('无法读取文件，请选择 PDF、清晰课表图片、UTF-8 CSV 或课间 JSON 备份。');
    } finally {
      importing = false;
    }
  }

  Future<void> importDocument(Uint8List bytes, String name) async {
    final progress = ValueNotifier<String>('正在准备本地识别…');
    final dialog = showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: const Text('正在识别课表'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const LinearProgressIndicator(),
              const SizedBox(height: 18),
              ValueListenableBuilder<String>(
                valueListenable: progress,
                builder: (_, value, child) =>
                    Text(value, style: const TextStyle(height: 1.6)),
              ),
              const SizedBox(height: 10),
              const Text(
                '在当前设备处理，请保持页面打开。',
                style: TextStyle(fontSize: 12, color: muted),
              ),
            ],
          ),
        ),
      ),
    );
    late final RecognitionResult result;
    try {
      result = await recognizeTimetableDocument(
        bytes,
        name,
        onProgress: (stage) => progress.value = stage,
      );
    } finally {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      await dialog;
      progress.dispose();
    }
    if (!mounted) return;
    final selection = await Navigator.of(context).push<DocumentImportSelection>(
      MaterialPageRoute(
        builder: (_) => RecognitionReview(
          result: result,
          currentSemester: data!.semester,
          fileName: name,
          imageBytes: name.toLowerCase().endsWith('.pdf') ? null : bytes,
        ),
      ),
    );
    if (selection == null || !mounted) return;
    await applyImported(
      selection.data,
      selection.append ? 'append' : 'replace',
      useImportedSemester: true,
    );
  }

  Future<void> applyImported(
    ScheduleData imported,
    String mode, {
    bool isBackup = false,
    bool useImportedSemester = false,
  }) async {
    final value = mode == 'append'
        ? data!.copyWith(
            courses: [...data!.courses, ...imported.courses],
            isDemo: false,
          )
        : isBackup
        ? imported
        : data!.copyWith(
            semester: useImportedSemester ? imported.semester : data!.semester,
            courses: imported.courses,
            exceptions: [],
            isDemo: false,
          );
    final lessons = lessonsBetween(
      value,
      value.semester.firstMonday,
      value.semester.dateAt(value.semester.weekCount, 7),
    );
    if (conflictKeys(lessons).isNotEmpty &&
        !await confirm(
          '导入后存在时间重叠',
          '课表中存在时间冲突。继续导入后会保留全部课程并标记冲突。',
          accept: '继续导入',
        )) {
      return;
    }
    if (await persist(value, '课表导入成功') && mounted) {
      setState(
        () => week = value.semester
            .weekOf(widget.clock())
            .clamp(1, value.semester.weekCount),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (data == null) {
      return Scaffold(
        body: Center(
          child: loadError == null
              ? const CircularProgressIndicator()
              : Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(loadError!, textAlign: TextAlign.center),
                      const SizedBox(height: 20),
                      FilledButton(onPressed: load, child: const Text('重新读取')),
                    ],
                  ),
                ),
        ),
      );
    }
    final wide = MediaQuery.sizeOf(context).width >= 1000;
    final content = switch (tab) {
      0 => SchedulePage(
        data: data!,
        week: week,
        now: widget.clock(),
        onWeek: (w) => setState(() => week = w),
        onLesson: showLesson,
        onRestore: restoreException,
        onAdd: courseEditor,
        onStart: clearCourses,
      ),
      1 => CoursesPage(
        data: data!,
        onEdit: courseEditor,
        onDelete: deleteCourse,
        onAdd: courseEditor,
        onImport: importFile,
        onTemplate: () => exportFile(template: true),
      ),
      _ => SettingsPage(
        data: data!,
        supportsWidgets: WidgetBridge.supported,
        widgetError: widgetError,
        onWidgetSync: () async {
          if (await syncWidgets(data!)) toast('已请求更新桌面小组件');
        },
        onSemester: semesterEditor,
        onExport: exportFile,
        onImport: () => importFile(backupOnly: true),
        onClear: clearCourses,
        onWeekends: (v) =>
            persist(data!.copyWith(showWeekends: v), v ? '已显示周末' : '已隐藏周末'),
      ),
    };
    return Scaffold(
      body: Stack(
        children: [
          AbsorbPointer(
            absorbing: saving,
            child: SafeArea(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (wide) _sidebar(),
                  Expanded(
                    child: Column(
                      children: [
                        if (!wide) _mobileHeader(),
                        Expanded(
                          child: Scrollbar(
                            controller: scroll,
                            child: SingleChildScrollView(
                              controller: scroll,
                              padding: EdgeInsets.fromLTRB(
                                wide ? 42 : 16,
                                wide ? 38 : 20,
                                wide ? 42 : 16,
                                30,
                              ),
                              child: Align(
                                alignment: Alignment.topCenter,
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 1050,
                                  ),
                                  child: content,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (saving)
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(),
            ),
        ],
      ),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: tab,
              onDestinationSelected: saving ? null : switchTab,
              backgroundColor: Colors.white,
              indicatorColor: const Color(0xFFE8EDDF),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.calendar_view_week_outlined),
                  selectedIcon: Icon(Icons.calendar_view_week),
                  label: '课表',
                ),
                NavigationDestination(
                  icon: Icon(Icons.auto_stories_outlined),
                  selectedIcon: Icon(Icons.auto_stories),
                  label: '课程',
                ),
                NavigationDestination(
                  icon: Icon(Icons.tune_outlined),
                  selectedIcon: Icon(Icons.tune),
                  label: '设置',
                ),
              ],
            ),
    );
  }

  Widget _brand() => Row(
    children: [
      Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: green,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons.grid_view_rounded,
          color: Colors.white,
          size: 22,
        ),
      ),
      const SizedBox(width: 12),
      const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '课间',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: 3,
            ),
          ),
          Text(
            'KEJIAN',
            style: TextStyle(fontSize: 8, color: muted, letterSpacing: 3),
          ),
        ],
      ),
    ],
  );
  Widget _mobileHeader() => Container(
    padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(bottom: BorderSide(color: lineColor)),
    ),
    child: Row(
      children: [
        _brand(),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: paper,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Row(
            children: [
              Icon(Icons.lock_outline, color: green, size: 12),
              SizedBox(width: 4),
              Text('本地保存', style: TextStyle(fontSize: 10, color: green)),
            ],
          ),
        ),
      ],
    ),
  );
  Widget _sidebar() => Container(
    width: 230,
    padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(right: BorderSide(color: lineColor)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _brand(),
        const SizedBox(height: 44),
        const Padding(
          padding: EdgeInsets.only(left: 12, bottom: 14),
          child: Text(
            '我的学期',
            style: TextStyle(color: muted, fontSize: 11, letterSpacing: 2),
          ),
        ),
        for (var i = 0; i < 3; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: tab == i ? const Color(0xFFEAF0E4) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              child: ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                dense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 3,
                ),
                leading: Icon(
                  [
                    Icons.calendar_view_week_outlined,
                    Icons.auto_stories_outlined,
                    Icons.tune,
                  ][i],
                  color: tab == i ? green : muted,
                  size: 20,
                ),
                title: Text(
                  ['我的课表', '课程管理', '偏好设置'][i],
                  style: TextStyle(
                    color: tab == i ? green : muted,
                    fontWeight: tab == i ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
                onTap: () => switchTab(i),
              ),
            ),
          ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: paper,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.eco_outlined, color: green, size: 26),
              const SizedBox(height: 12),
              const Text(
                '把日子过成自己的节奏',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 7),
              const Text(
                '认真生活的每一天\n都有值得期待的课间。',
                style: TextStyle(fontSize: 11, color: muted, height: 1.8),
              ),
              const SizedBox(height: 16),
              Text(
                '${data!.semester.weekOf(widget.clock()).clamp(0, data!.semester.weekCount)} / ${data!.semester.weekCount} 教学周',
                style: const TextStyle(fontSize: 10, color: green),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value:
                      (data!.semester.weekOf(widget.clock()) /
                              data!.semester.weekCount)
                          .clamp(0, 1),
                  minHeight: 4,
                  color: green,
                  backgroundColor: lineColor,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Row(
          children: [
            Icon(Icons.lock_outline, color: muted, size: 13),
            SizedBox(width: 7),
            Text('课表只保存在此设备', style: TextStyle(fontSize: 10, color: muted)),
          ],
        ),
        const SizedBox(height: 10),
        const Text(
          'KEJIAN  /  OPEN SOURCE  /  0.3',
          style: TextStyle(fontSize: 8, color: muted, letterSpacing: 1),
        ),
      ],
    ),
  );
}
