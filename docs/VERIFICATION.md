# 验证记录

日期：2026-11-09。版本：0.3.2 开发预览。

## v0.3.2 凯里学院作息与原版/宽版双课小组件

- 默认时间依据用户提供的 08:20/11:45、14:00/17:25、19:00，以及 5/15 分钟休息推算为每节 45 分钟；晚课沿用两节至 20:35。完整钟点记录在 `TIMETABLE_DEFAULTS.md`，未冒称学校官方作息。
- Flutter 静态分析、45 项测试通过，新增默认时间边界、旧文档一次迁移、课程/停课/设置保留、自定义不覆盖、迁移后小组件通道的实际时间、预设取消/保存，以及原版/宽版独立添加请求验证。
- iOS 工程检查与 Swift 语法检查通过；15 项 Foundation 时间线检查通过，新增两门课排序、跨日期接续、结束边界滚动、不重复末节和调课信息保留。
- 两端提供原版与宽版两个独立入口：原版保留旧尺寸并上下显示，宽版左右显示。Android 保留旧 provider，iOS 保留旧 kind，避免改变已有桌面实例的身份。实际平台构建与安装结果在验证完成后补充。

## v0.3.1 iPhone 真机编译与 TrollStore IPA

- 使用完整 Xcode 的 GitHub macOS runner 运行 `flutter build ios --release --no-codesign`，完成 iPhoneOS SDK 的 App 和 WidgetKit 扩展编译。Flutter AOT Release 不依赖 JIT。
- [最终构建与打包任务](https://github.com/2908746449/kejian/actions/runs/42580413334) 提供 `kejian-ios-trollstore` artifact，包含 IPA 和 JSON 校验报告；另存原始真机 App artifact 供开发检查。任务可通过 `target=ios-trollstore` 单独执行。
- `tool/package_trollstore_ipa.py` 检查 App 和扩展均为 0.3.1 / 4、最低 iOS 15.0、相同 App Group、iPhoneOS 平台和完整内嵌 WidgetKit；将 Flutter 单个 arm64 slice 的 universal 封装统一为普通 arm64 Mach-O，拒绝混入模拟器平台或其他架构。
- ldid 分别写入主 App 与扩展的应用身份和共享组 entitlements，并重新读取核对。所有原生二进制的 CodeDirectory 代码页和权限哈希均检查通过；IPA 使用 `Payload/Runner.app` 结构。JSON 报告记录每个二进制及最终 IPA 的 SHA-256、最低系统、平台和构建提交。
- 对签名检查器做了实际二进制检查：接受未修改的 ldid 代码哈希、拒绝翻转一个代码字节后的文件；平台检查拒绝 arm64 模拟器。首次打包错误地使用了要求 CMS 的 `codesign --verify`，已改为验证 ldid 代码页与权限；随后修正 Flutter 单架构 universal 封装的处理。两次前期失败均发生于打包阶段，真机 Release 编译已通过。
- 本轮本地 39 项 Flutter 测试及 iOS 工程检查通过。[构建提交的 Check 流程](https://github.com/2908746449/kejian/actions/runs/42580412524) 也已通过。之前一次 Linux 检查因上游 PDFium 返回 HTTP 504 失败；没有将下载失败表述为应用测试失败或省略既有测试。
- 发布补充 IPA、校验报告和安装说明，保留原 v0.3.1 的 APK、模拟器、Web 和源码压缩包；应用源码及版本未变，新增打包工具位于 main。
- 用户确认已有可用 TrollStore，系统为 iOS 15.6.1。官方版本范围包含该系统。**本轮未连接 iPhone；尚待安装、App Group 实际写入、PDF / 图片导入以及小中大组件运行和刷新验收。**

## v0.3.1 Android 小组件添加入口

- 用户反馈环境为小米 14 Pro / 澎湃 OS 1 / Android 14，症状是小部件列表找不到课间。本轮只连接了专用 Android 模拟器，没有连接该真机。
- 0.3.0 的已安装 release 包在 Android 13 / API 33 系统 `dumpsys appwidget` 中存在 `dev.kejian.kejian.ScheduleWidget` provider，未复现系统注册丢失。没有据此将 Receiver 的 `exported=false` 判为问题。
- 根据小米官方小部件适配说明，原生 Android 小组件有单独的「安卓小部件」入口。设置页增加准确路径，以及 Android 8+ 的系统固定请求；Android 7、不支持的桌面或请求失败均保留手动指引。
- 静态分析、Dart 格式检查、39 项 Flutter 测试通过。新增请求前同步、请求后仍等待确认、不支持桌面的指引、失败重试、不改变课表、iOS 不发送 Android 请求的覆盖。
- iOS 工程配置检查、Swift 语法和 10 项 Foundation 数据/时间线检查通过。本机仍无完整 Xcode；云端已完成 App 和扩展的真正 iOS SDK 模拟器编译，见下文。
- `flutter test integration_test/widget_pinning_test.dart -d emulator-5580` 通过。系统 API 确认 provider 已注册、桌面支持固定请求；App 设置按钮先同步，再调用系统 API。实际截图 `kejian-widget-add-dialog.png` 显示系统「Add to home screen」确认框、课间名称和布局预览。只验证请求与弹窗，没有通过该测试确认最终桌面放置。
- 0.3.1 / 4 release arm64 APK 构建成功，约 70.1 MB，minSdk 24 / targetSdk 36；`apksigner verify` 通过。运行集成测试后使用正常 `flutter build apk --release` 重新生成插件注册表，避免 `--no-pub` 复用测试插件的生成文件。Web release 构建成功。
- 最终 release 包已在专用 Android 13 模拟器覆盖安装并启动；系统状态为 `stopped=false`、`notLaunched=false`，provider 仍被识别。0.3.0 和 0.3.1 的签名证书 SHA-256 相同，保持原包名，可覆盖旧版；未清空应用数据。发布包中不含 integration_test 插件或私人测试资产。
- GitHub 的 [Check 流程](https://github.com/2908746449/kejian/actions/runs/42566007284) 全部通过，包含格式、静态分析、39 项测试和 Web 构建。
- [Mobile builds](https://github.com/2908746449/kejian/actions/runs/42566023283) 的 iOS 任务成功：完成工程检查、10 项 Foundation 检查、`flutter build ios --simulator --debug --no-codesign`、模拟器 App 打包和 artifact 上传。初次 Android 任务因 setup-android 默认请求已下架的 `tools` 包而失败，已显式指定 SDK 包后重试。这些云端结果不代表已验证小米或 iOS 真机。
- 已下载并检查 iOS 模拟器 artifact：`Runner.app/PlugIns/ScheduleWidget.appex` 确实内嵌；App / Widget 的版本均为 0.3.1 / 4，两个 `MinimumOSVersion` 均为 15.0；不含私人课表。后续重跑曾因 PDFium 上游二进制下载 HTTP 504 失败，属于依赖获取问题；已有的成功编译记录和产物保留。
- 修复初始化并重跑后，[Mobile builds 的 Android / iOS 两个任务均通过](https://github.com/2908746449/kejian/actions/runs/42566722778)。Android debug APK 和内嵌扩展的 iOS 模拟器 App 均已上传 Actions artifact。文档更新后的 [Check 流程也已通过](https://github.com/2908746449/kejian/actions/runs/42567399260)。

## v0.3 文档识别检查

- Dart 格式和静态分析通过；35 项 Flutter 测试全部通过。其中新增 12 项匿名识别与核对测试，覆盖课程合并、单双周、节次覆盖、OCR 范围修复、缺标签推算、页脚隔离、非法日期、待安排备份、格线检测与预览取消。
- Android 13 / API 33 arm64 模拟器运行真正的 PDFium 与 ML Kit 通道，两项文档集成测试通过；使用本次私人附件 PDF 与其渲染 PNG，未使用 PDF 文字代替图片 OCR。最终适配 Web 解码后重新跑通。
- PDF：18 门课程、19 组重复安排、3 门待安排、0 段未解析；学期第一周周一 2026-08-31、20 周。已对照原 PDF 文字和渲染布局核对。原表没有钟点作息，沿用当前并提示用户确认。
- Android 图片：19 组安排、19 门课程（其中 3 门待安排）、0 段未解析。与 PDF 多出的一门来自同名课的一字识别偏差；课名、教师、教室仍有少量 OCR 误字，不声明逐字准确。
- 浏览器 Web release：本地 PDF 文件选择、识别结果、编辑入口、返回取消均通过；统计与 Android PDF 一致，取消后仍是 7 门示例课表；重新识别并确认替换后，刷新仍保留 18 门课程、3 门待安排，完整 JSON 导出结果也校验通过。
- Web 图片：19 组安排、15 门已排课程；底部 3 段 OCR 未能可靠拆分，原文保留供手工补充。网页初次测试暴露 ImageDescriptor.width 不支持 Web，已改用跨平台 codec。图片 OCR 的开学月份误读被新增日期规则拦截并提示手动核对，不据此自动平移课表。
- Web 390×844 手机布局、作息增加第 11 节并取消通过；最终 release 控制台无 error / warn。Web 使用随站点分发的 worker、WASM 和中文模型。截图 `kejian-pdf-import.jpg` / `kejian-image-import.jpg` 作为本轮证据。
- 0.3 Android release arm64 构建成功（约 70.1 MB，增加了 bundled 中文模型和 PDFium）；版本 0.3.0 / 3，最终包已在模拟器安装并由 Flutter release 启动。开发密钥签名，非正式发行签名。
- 私人测试 PDF/PNG、姓名和学号不进入开源源码、APK 或 Web 交付包；集成测试只提供可选本地流程，正式 pubspec 不包含私人资产。

## v0.2 保留的已有检查

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

## iOS 本地检查与初始限制（v0.3.0）

- Runner 和 ScheduleWidget 两个 target 的 Debug / Release / Profile 都明确设置 `IPHONEOS_DEPLOYMENT_TARGET = 15.0`；Flutter Framework 最低版本元数据为 15.0。
- `plutil` 检查工程、Info.plist 和两个 entitlements 均通过。
- `python3 tool/check_ios_project.py` 检查共享 Swift 源码同时属于 App/Widget、扩展依赖与嵌入阶段、App Group entitlements 和 iOS 15 配置；扩展嵌入阶段先于 Flutter Run Script。
- `swiftc -parse` 检查 AppDelegate、共享模型与 Widget SwiftUI 源码语法。
- 用 macOS Command Line Tools 实际编译并运行共享 Foundation 数据模型的 10 项边界/时间线检查：上课开始与结束、学期边界、午夜条目、时区切换和未知版本拒绝。它没有编译 WidgetKit/SwiftUI 或 Flutter iOS 应用。
- 尝试 `flutter build ios --simulator --debug --no-codesign --no-pub`，在读取 Xcode 项目设置阶段退出，提示 `Application not configured for iOS`。本机 `xcodebuild -version` 明确报错：需要完整 Xcode，当前选择的是 `/Library/Developer/CommandLineTools`。该命令没有进入 iOS SDK 编译阶段。
- **v0.3.0 阶段没有 iOS App / IPA 编译成功记录，没有完成签名、iOS 15 真机或 iOS 小组件运行验证。** v0.3.1 的云端编译结果见本文开头，真机运行仍待验证。
- v0.3.0 添加了 `.github/workflows/mobile.yml`，当时尚未上传或运行 GitHub Actions。

可复现的原生检查：

```sh
python3 tool/check_ios_project.py
swiftc -parse ios/Shared/WidgetSnapshot.swift ios/ScheduleWidget/ScheduleWidget.swift ios/Runner/AppDelegate.swift
swiftc ios/Shared/WidgetSnapshot.swift tool/check_widget_snapshot.swift -o /tmp/kejian-check-widget
/tmp/kejian-check-widget examples/widget-snapshot.json
```

## v0.1 保留的验证记录

0.1 Web 版本已实际完成新增课程后刷新保留、JSON 下载和恢复、CSV 文件选择与导入预览，手机 390×844 / 宽屏 1440×1050 没有布局或控制台错误。这些不等同于本轮已测试原生文件选择器。

## 尚需设备验证

- Android 7.0 最低系统与不同厂商桌面、电池策略、跨午夜、重启、时区改变、真实文件导入/导出及调课后的后台刷新。
- 在 iOS 15 及较新系统实际验收安装、小中大尺寸、共享文件、停课/调课同步和后台时间线。
- 两端正式分发前配置自己的标识与签名。源码已发布到 GitHub，没有发布到 TestFlight 或应用商店。

构建、签名与添加小组件的方法见 `MOBILE.md`。
