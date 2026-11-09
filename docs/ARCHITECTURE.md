# 架构与数据格式

```
lib/
  domain/models.dart       学期、节次、课程、重复安排、单次例外、校验
  domain/engine.dart       日期展开、下一节课、冲突检查
  domain/agenda.dart       今日剩余课程与明天预览
  domain/widget_snapshot.dart  完整学期的小组件快照
  platform/widget_bridge.dart  原生共享数据通道
  data/demo.dart           带明确标记的示例课表
  data/defaults.dart       凯里学院作息预设与旧默认作息迁移
  data/importer.dart       CSV 解析与导入规则
  data/document_recognizer.dart  PDF 文字提取、扫描页渲染与 OCR 协调
  data/timetable_recognition.dart  坐标表格解析、周次与课程合并
  data/table_grid.dart     格线检测与去线
  platform/ocr*.dart       原生通道 / Web Tesseract bridge
  data/repository.dart     SQLite / Web 存储接口
  ui/                     课表、课程编辑、详情、调课、设置
  main.dart               应用状态与操作协调
```

## 规则

`Course` 描述一门课程，可没有 `Meeting` 并保留为待安排；待安排课程不会出现在周视图或小组件中。`Meeting` 描述一组重复安排，`LessonException` 描述一次取消或移动。展示层的 `Lesson` 由前述数据计算，未重复持久化。

日期使用本地日历日，教学周差使用 UTC 的年月日计算，以避免夏令时导致的天数偏移。跨日运算使用日历日期构造。原始 occurrence 的稳定键为 `meetingId@YYYY-MM-DD`。

移动课程先抑制原始 occurrence，再在目标日期生成一次。所有展示均调用同一套展开逻辑。下一节包含仍在上课的课程，结束时间到达即排除。当前不在学期内时，周视图夹到边界，但会明确提示学期外。

修改学期起始日时，单次变更按同样天数整体平移。删除课程同时删除对应例外；编辑重复安排使某个原始 occurrence 消失时，清理不再适用的例外。

## 存储

Android / iOS：`kejian.db`，SQLite `documents(id INTEGER PRIMARY KEY, payload TEXT NOT NULL)`，一个当前学期对应一个经过校验的 JSON 文档。事务内整体替换，用持久化完成后更新 UI 的顺序避免假成功。对于单用户单学期，这比提前建立关系查询层更简单；仓储接口允许日后迁移为关系表。

Web 预览：`SharedPreferencesAsync` 对应的浏览器存储。浏览器清理站点数据会删除课表，不能代替导出备份；当前不提供跨标签页冲突合并，也不把 Web 构建声明为离线 PWA。

文件选择与保存由 `file_picker` 调用系统 UI。CSV / JSON 导入最多 2 MB，PDF / 图片最多 20 MB，PDF 最多 5 页；CSV 最多 1000 条安排；一学期最多 300 门课程、每课 30 组安排。所有导入先完整解析、校验、预览，再一次写入。无法读取现有数据时保留原文档并显示错误，不用示例覆盖。

## 备份版本 1

顶层：`schemaVersion`, `defaultsVersion`, `semester`, `courses`, `exceptions`, `isDemo`, `showWeekends`。

`defaultsVersion` 缺省为 1，新文档为 2。首次打开旧文档时，只将完整匹配原 10 节默认钟点的作息升级为凯里学院作息，并标记版本；自定义作息、课程与单次变更保持原值。手动 JSON 恢复保留备份作息并记录已处理版本，避免下一次启动改变刚恢复的数据。备份结构版本仍为 1，旧版可忽略新增字段。

- `semester`：name、firstMonday（YYYY-MM-DD）、weekCount、periods（number/start/end）。
- `courses`：id、name、teacher、note、color（0—5）、meetings。
- `meetings`：id、weekday（1=周一）、startPeriod/endPeriod（1 起）、weeks（整数数组）、room。
- `exceptions`：meetingId、originalDate、cancelled、targetDate、startPeriod/endPeriod、room。

遇到未知版本拒绝导入。未来字段或存储升级必须提供迁移，不可静默丢失数据。

## CSV

表头固定为 `课程名称,教师,教室,星期,开始节次,结束节次,周次,颜色,备注`。

星期 1—7，颜色 1—6，周次如 `1-16`、`1 3 5 7` 或带引号的 `"1,3,5,7"`。同一名称、教师、颜色和备注合并为一门课，其每行形成不同安排。CSV 追加不会猜测并合并已有课程，重复导入会保留为新课程并提示冲突。完整迁移请使用 JSON。

学校导入器未来只需产出统一课程模型；当前未实现插件或动态脚本执行器。

## 小组件

App 成功保存主文档后，把规则引擎展开的完整学期快照传给原生端。Android SharedPreferences 与 iOS App Group 原子文件作为只读副本；小组件自行按当前本地时间筛选接下来的两门课。同步失败单独提示，不回滚已保存主文档。刷新、时间线与部署设置见 `MOBILE.md`。

0.3.2 起，小组件展示完整快照中按开始时间排序、结束时间晚于当前时刻的前两门课；可跨日期顺延。共享快照结构保持版本 1，原生展示只取两个条目，时间线仍覆盖完整学期。Android 的原版/宽版两个 provider 共用快照和刷新调度，删除一种的最后一个实例不会停止另一种刷新；iOS 的两个 kind 通过 WidgetBundle 注册，并由主 App 同时请求刷新。旧 provider/kind 保留，已有桌面实例可继续更新。

## PDF 与图片

PDFium 优先提取 PDF 文字与字符矩形；没有可用课表文字层时，页面渲染到最长边 3200 像素并进入图片识别。图片先去除长格线、保留行边界，Android 调用 bundled ML Kit 中文 OCR，iOS 调用 Vision，Web 调用随站点打包的 Tesseract.js / WASM / 中文模型。原始文件不上传，OCR 坐标统一转换为左上角原点。

空间解析器以星期表头确定列、节次标签确定行，读取斜杠分隔的课程信息；明确节次覆盖所在行默认节次，同名同教师的不同安排合并。缺节次只有在至少两行真实标签支持一致规律时才按格线推算；OCR 唯一合法的数字范围补全会保留原文并提示。未知布局、错误周次和未排时间分别进入待核对原文或待安排课程，避免静默丢弃。

核对页可改学期、作息、每门课和勾选范围。追加只允许与当前学期日期、周数和作息一致，替换清除旧调课记录；两者都先完整校验、提示冲突，再走统一事务保存和小组件同步。详细边界见 `IMPORT.md`。
