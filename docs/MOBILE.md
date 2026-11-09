# Android / iOS 与桌面小组件

版本：0.3.2 开发预览，2026-11-09。

默认凯里学院作息；Android 和 iOS 小、中、大尺寸小组件均显示接下来的两门课，跨日期接续，时间来自当前已保存作息。Android 为左右两栏，最小宽度 250dp；iOS 小/大尺寸上下排列，中尺寸左右排列。完整说明见 `TIMETABLE_DEFAULTS.md`。

## Android

Android 7.0 / API 24 及以上，交付的 APK 为 arm64（多数现代 Android 手机）。`android/app/src/main/kotlin/dev/kejian/kejian/ScheduleWidget.kt` 使用系统 AppWidget / RemoteViews，无需运行 Flutter 页面。

打开 App → 设置 → 桌面小组件 → **添加到桌面**，在系统弹窗中确认。Android 8 及以上且桌面支持时，通过系统 `requestPinAppWidget` 请求添加；接受请求不代表已添加，用户仍可取消。回到 App 后会重新读取系统实际绑定的数量。不支持直接添加、Android 7 或点击后没有弹窗时使用手动方式。

小米 / 澎湃 OS 的小部件中心有独立的安卓原生小部件入口：桌面双指捏合或长按空白处 → 添加小部件 → 右上角搜索 → 应用列表底部的「安卓小部件」→ 课间。部分桌面版本入口名为「全部应用小部件」。课间没有接入小米专有小部件中心。该路径依据小米官方适配说明；本轮未连接小米 14 Pro 真机。

其他桌面：长按桌面空白处 → 小组件 → 课间，长按或拖动到桌面。默认尺寸由桌面决定，可缩放；两栏显示下一节和再下一节。点击组件打开 App。组件同时提供 Android 12+ 的布局预览和旧桌面使用的图片预览。Receiver 保持 `exported=false`，遵循 Android 官方注册示例。

无账号、无课表上传服务、无精确闹钟权限。图片识别的中文 ML Kit 模型随安装包打包，无需在线下载；PDF 由 PDFium 本地提取。

```sh
flutter pub get
flutter build apk --release --target-platform android-arm64
```

当前 release 仍使用开发用 debug 密钥签名，仅作为可安装预览。正式发布需选择自己的包标识并配置发行签名；签名变更后不能直接覆盖安装开发签名版本，迁移前先导出备份。

## iOS 15 及以上

`Runner` 和 `ScheduleWidget` 的 Debug / Release / Profile 均明确设置最低 iOS 15.0。WidgetKit 扩展内置小、中、大三种主屏幕尺寸；iOS 17 的容器背景 API 由版本判断保护，iOS 15 使用兼容布局。未加入锁屏组件或交互式按钮。图片识别使用系统 Vision，PDF 依赖 pdfrx / PDFium 的 iOS 15 构建。

本机缺少完整 Xcode。0.3.1 已在 GitHub Actions 使用完整 Xcode 完成 App 和 WidgetKit 扩展的[模拟器编译](https://github.com/2908746449/kejian/actions/runs/42566023283)，以及 [iPhoneOS Release 与 TrollStore IPA 打包](https://github.com/2908746449/kejian/actions/runs/42580413334)。两个产物分别提供，iPhone 使用 `kejian-ios-trollstore-v0.3.1.ipa`。尚未完成 iOS 15 真机或 WidgetKit 运行验证。

使用 Apple 开发团队签名时，在有完整 Xcode 的 Mac 上：

1. 安装项目所需 Flutter 3.47.9 并执行 `flutter pub get`。项目级启用 Swift Package Manager，当前 iOS 插件提供 Swift package；不要求先安装 CocoaPods。
2. 执行 `flutter build ios --simulator --debug --no-codesign` 验证编译，然后打开 `ios/Runner.xcworkspace`。
3. 真机/归档时为 `Runner` 和 `ScheduleWidget` 选择同一个 Apple 开发团队；确认两个 Bundle Identifier 属于自己的团队（默认 `dev.kejian.kejian` 与 `dev.kejian.kejian.ScheduleWidget`）。
4. 在两个 target 的 Signing & Capabilities 中配置同一个 App Group。工程级 `KEJIAN_APP_GROUP` 默认 `group.dev.kejian.kejian`，应替换为团队实际注册的组。Info.plist、两个 entitlement 及读写代码从该设置取值。
5. 使用 Runner scheme 运行或归档；扩展已经设为 Runner 的依赖并嵌入 `PlugIns`；嵌入阶段位于 Flutter Run Script 之前，无需单独拷贝。正式 IPA 通过 Xcode Organizer 导出或在完成签名配置后执行 `flutter build ipa`。
6. 在手机桌面长按 → 添加小组件 → 课间，分别检查小中大尺寸。

主 App 和扩展版本均从 Flutter 的版本名、构建号读取。任何 Bundle Identifier 或 App Group 变更，都需同时检查扩展与 App，避免只有 App 安装成功而小组件拿不到课表。

### 已安装 TrollStore 的设备

已有可用 TrollStore 的设备可安装真机 Release IPA。项目最低 iOS 15.0；TrollStore 官方支持 14.0 beta 2—16.6.1、16.7 RC（20H18）和 17.0，因此应同时满足项目和安装工具的版本要求。iOS 15.6.1 在范围内。这里的 IPA 不用于 TestFlight 或 App Store。

安装时将 `kejian-ios-trollstore-v0.3.2.ipa` 分享给 TrollStore 并确认安装。先打开课间一次，导入或建立课表，再长按主屏幕空白处 → 左上角「+」→ 搜索「课间」→ 选择小、中、大尺寸 → 添加小组件。进入课间的设置页可重试同步；系统决定实际刷新时机。安装、三个尺寸和同步仍需在实际设备验收。

`.github/workflows/mobile.yml` 手动运行时新增 `ios-trollstore` 任务：

```sh
brew install ldid
flutter pub get
flutter build ios --release --no-codesign
python3 tool/package_trollstore_ipa.py --app build/ios/iphoneos/Runner.app --output build/ios/ipa
```

该任务使用 `iphoneos` SDK 和 Flutter AOT Release。打包脚本检查两个 target 的最低系统、版本、Bundle Identifier、App Group、内嵌 WidgetKit 扩展，以及所有 Mach-O 的 arm64 架构和 iPhoneOS 平台。主 App 和扩展分别保留应用身份及共享组权限，使用本地 `TROLLTROLL` 身份；TrollStore 在手机上完成安装签名。脚本用 ldid 读取权限并逐页核对 CodeDirectory 哈希，输出 `Payload/Runner.app` 结构的 IPA 和 JSON 校验报告。ldid 伪签名没有 Apple CMS 签名，不使用 macOS `codesign --verify` 判断其是否可被 TrollStore 安装。

GitHub 的两个已有任务仍提供 Android debug APK 与 iOS 模拟器 App。[0.3.1 的两个任务均已成功](https://github.com/2908746449/kejian/actions/runs/42566722778)。Android 初始化已修正为明确安装 SDK 36、build-tools 36.0.0 和 platform-tools，避免请求下架的旧 `tools` 包。流程不保存 Apple 开发者签名或商店发布凭据。

## 数据一致性与刷新

课程规则由 Dart 引擎展开为完整学期快照（`examples/widget-snapshot.json` 为样例），包括有效的单双周、自选周、停课、跨周移动与教室变化。原始 SQLite 文档仍是唯一编辑源，小组件文件不用于恢复或反向修改课表。

加载、保存、导入/恢复、清空课程和返回 App 时同步。小组件同步失败不会撤销已经成功保存的课表，App 会提示并提供设置页重试。

- Android：快照保存在 App 私有 SharedPreferences；在上下课边界和午夜安排非精确更新，另有系统 30 分钟周期刷新；响应重启、日期、时间和时区变化。
- iOS：原子写入 App Group 文件，主 App 请求 `reloadTimelines`。扩展读取完整学期，在未来两天的上下课边界与午夜生成时间线，末尾再次读取文件生成后续条目。App 不运行时也不依赖 Dart 引擎。
- 两端以本地日历日期和作息时间计算；系统可以延迟刷新，因此不承诺秒级刷新。课表以 App 内数据为准。
- 首次打开前展示同步引导；清空课程后会同步空数组，移除旧课程；示例数据在小组件明确标记为示例。

## 必须补充的设备验证

至少在 iOS 15 和较新版本验证安装、App Group 写入、小中大布局、午夜切换、上课开始/结束、停课/调课后更新、重启及设备时区改变。TrollStore 安装和 Apple 签名分发分别验收。Android 需补充不同厂商桌面与电池管理行为。编译与逻辑测试不能替代这些检查。

## 官方资料

- Flutter 扩展接入：https://docs.flutter.dev/platform-integration/ios/app-extensions
- Flutter 支持平台：https://docs.flutter.dev/reference/supported-platforms
- Android App Widgets：https://developer.android.com/develop/ui/views/appwidgets/overview
- Android 添加请求：https://developer.android.com/reference/android/appwidget/AppWidgetManager#requestPinAppWidget(android.content.ComponentName,android.os.Bundle,android.app.PendingIntent)
- 小米小部件适配说明（含安卓小部件入口）：https://dev.mi.com/xiaomihyperos/documentation/detail?pId=1588
- Android 小组件更新：https://developer.android.com/develop/ui/views/appwidgets/advanced
- WidgetKit 时间线与刷新：https://developer.apple.com/documentation/widgetkit/keeping-a-widget-up-to-date
- App Groups：https://developer.apple.com/documentation/xcode/configuring-app-groups
- TrollStore 官方版本范围与 IPA 权限说明：https://github.com/opa334/TrollStore
- TrollStore 小组件容器问题记录：https://github.com/opa334/TrollStore/issues/873
