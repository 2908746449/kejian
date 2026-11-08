# 架构与数据格式

```
lib/
  domain/models.dart       学期、节次、课程、重复安排、单次例外、校验
  domain/engine.dart       日期展开、下一节课、冲突检查
  domain/agenda.dart       今日剩余课程与明天预览
  domain/widget_snapshot.dart  完整学期的小组件快照
  platform/widget_bridge.dart  原生共享数据通道
  data/demo.dart           带明确标记的示例课表
  data/importer.dart       CSV 解析与导入规则
  data/repository.dart     SQLite / Web 存储接口
  ui/                     课表、课程编辑、详情、调课、设置
  main.dart               应用状态与操作协调
```

## 规则

`Course` 描述一门课程，`Meeting` 描述一组重复安排，`LessonException` 描述一次取消或移动。展示层的 `Lesson` 由前述数据计算，未重复持久化。

日期使用本地日历日，教学周差使用 UTC 的年月日计算，以避免夏令时导致的天数偏移。跨日运算使用日历日期构造。原始 occurrence 的稳定键为 `meetingId@YYYY-MM-DD`。

移动课程先抑制原始 occurrence，再在目标日期生成一次。所有展示均调用同一套展开逻辑。下一节包含仍在上课的课程，结束时间到达即排除。当前不在学期内时，周视图夹到边界，但会明确提示学期外。

修改学期起始日时，单次变更按同样天数整体平移。删除课程同时删除对应例外；编辑重复安排使某个原始 occurrence 消失时，清理不再适用的例外。

## 存储

Android / iOS：`kejian.db`，SQLite `documents(id INTEGER PRIMARY KEY, payload TEXT NOT NULL)`，一个当前学期对应一个经过校验的 JSON 文档。事务内整体替换，用持久化完成后更新 UI 的顺序避免假成功。对于单用户单学期，这比提前建立关系查询层更简单；仓储接口允许日后迁移为关系表。

Web 预览：`SharedPreferencesAsync` 对应的浏览器存储。浏览器清理站点数据会删除课表，不能代替导出备份；当前不提供跨标签页冲突合并，也不把 Web 构建声明为离线 PWA。

文件选择与保存由 `file_picker` 调用系统 UI。导入最多 2 MB，CSV 最多 1000 条安排；一学期最多 300 门课程、每课 30 组安排。所有导入先完整解析、校验、预览，再一次写入。无法读取现有数据时保留原文档并显示错误，不用示例覆盖。

## 备份版本 1

顶层：`schemaVersion`, `semester`, `courses`, `exceptions`, `isDemo`, `showWeekends`。

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

App 成功保存主文档后，把规则引擎展开的完整学期快照传给原生端。Android SharedPreferences 与 iOS App Group 原子文件作为只读副本；小组件自行按当前本地时间筛选下一节与当天安排。同步失败单独提示，不回滚已保存主文档。刷新、时间线与部署设置见 `MOBILE.md`。
