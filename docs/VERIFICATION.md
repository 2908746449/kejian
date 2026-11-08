# 验证记录

日期：2026-11-09。版本：0.2.0 开发预览。

## 当前通过的检查

- Dart 格式检查、静态分析通过。
- `flutter test --no-pub`：23 项测试全部通过。包含课程规则、CSV/备份、界面与保存恢复，以及新增的今日后续卡片逐节减少、最后一门展开、明天预览、空格周次、完整学期快照和同步失败不撤销已保存课表。
- Android debug 与 release arm64 APK 均构建成功；release 约 30.9 MB（十进制），版本名 0.2.0 / 版本号 2。
- `aapt2 dump badging`：包名 `dev.kejian.kejian`，minSdk 24 / targetSdk 36；`apksigner verify` 通过，当前为 Android Debug 开发密钥，不能据此声明具备正式商店发行签名。
- 在本任务新建的 Android 13 / API 33 arm64 模拟器安装并启动 debug 和 release 版本，App 加载课表并展示下一节与今日后续完整卡片。
- 实际在模拟器桌面的小组件列表找到课间并添加；系统 `dumpsys appwidget` 确认已绑定 `ScheduleWidget`，桌面显示课名、时间、教室与今日后续。放大尺寸与后续行已观察；不同厂商桌面仍需验证。
- debug 首次启动后确认 `kejian.widgets` SharedPreferences 已创建。系统 `dumpsys alarm` 确认安排了下一次课程边界的非精确刷新。没有模拟等待整日或将结果表述为已完成重启/午夜/后台长期运行验证。
- `flutter build web --release --no-web-resources-cdn --no-pub` 成功。
- 本轮实际浏览器验证 390×844 手机布局与默认宽屏；下一节下方仅剩一门时显示完整卡片。自定义周次框可输入 `1 3 5 8-12`，下方提示空格/逗号/范围。未保存测试表单到用户预览课表。
- 本轮浏览器没有捕获 error / warn 日志；`outputs/kejian-mobile.jpg` 与 `outputs/kejian-weeks.jpg` 保存新版截图。

## iOS 检查与明确限制

- Runner 和 ScheduleWidget 两个 target 的 Debug / Release / Profile 都明确设置 `IPHONEOS_DEPLOYMENT_TARGET = 15.0`；Flutter Framework 最低版本元数据为 15.0。
- `plutil` 检查工程、Info.plist 和两个 entitlements 均通过。
- `python3 tool/check_ios_project.py` 检查共享 Swift 源码同时属于 App/Widget、扩展依赖与嵌入阶段、App Group entitlements 和 iOS 15 配置；扩展嵌入阶段先于 Flutter Run Script。
- `swiftc -parse` 检查 AppDelegate、共享模型与 Widget SwiftUI 源码语法。
- 用 macOS Command Line Tools 实际编译并运行共享 Foundation 数据模型的 10 项边界/时间线检查：上课开始与结束、学期边界、午夜条目、时区切换和未知版本拒绝。它没有编译 WidgetKit/SwiftUI 或 Flutter iOS 应用。
- 尝试 `flutter build ios --simulator --debug --no-codesign --no-pub`，在读取 Xcode 项目设置阶段退出，提示 `Application not configured for iOS`。本机 `xcodebuild -version` 明确报错：需要完整 Xcode，当前选择的是 `/Library/Developer/CommandLineTools`。该命令没有进入 iOS SDK 编译阶段。
- **没有 iOS App / IPA 编译成功记录，没有完成签名、iOS 15 真机或 iOS 小组件运行验证。** 三种 WidgetKit 尺寸和 App Group 通道为已实现的工程代码，实际兼容性须在完整 Xcode 环境验证。
- `.github/workflows/mobile.yml` 已添加 Android / iOS 模拟器构建流程，尚未上传或运行 GitHub Actions。

可复现的原生检查：

```sh
python3 tool/check_ios_project.py
swiftc -parse ios/Shared/WidgetSnapshot.swift ios/ScheduleWidget/ScheduleWidget.swift ios/Runner/AppDelegate.swift
swiftc ios/Shared/WidgetSnapshot.swift tool/check_widget_snapshot.swift -o /tmp/kejian-check-widget
/tmp/kejian-check-widget examples/widget-snapshot.json
```

## 保留的上一版验证记录

0.1 Web 版本已实际完成新增课程后刷新保留、JSON 下载和恢复、CSV 文件选择与导入预览，手机 390×844 / 宽屏 1440×1050 没有布局或控制台错误。这些不等同于本轮已测试原生文件选择器。

## 尚需设备验证

- Android 7.0 最低系统与不同厂商桌面、电池策略、跨午夜、重启、时区改变、真实文件导入/导出及调课后的后台刷新。
- 有完整 Xcode 后编译 App 与扩展，在 iOS 15 及较新系统实际验收小中大尺寸、共享文件、停课/调课同步和后台时间线。
- 两端正式分发前配置自己的标识与签名。没有发布到 GitHub、TestFlight 或应用商店。

构建、签名与添加小组件的方法见 `MOBILE.md`。
