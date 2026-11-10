# 课间 · Kejian

一个留白多一点的开源大学课程表。手机优先，免登录，课表由你掌握。

当前版本：**0.3.3 开发预览**。默认采用凯里学院作息，Android / iOS 均提供 2×2 与 4×2 两个独立桌面小组件，都显示接下来的两门课。Flutter 3.47.9 / Dart 3.13.7；iOS App 与 WidgetKit 最低版本为 15.0，已有 TrollStore 的设备可安装真机 IPA。各版本的构建和设备验证状态见 `docs/VERIFICATION.md`。

[下载 Android / iOS 安装包](https://github.com/2908746449/kejian/releases) · [报告问题](https://github.com/2908746449/kejian/issues)

## 已实现

- 周课表、当前周定位、下一节课、今天高亮和周末显示开关。
- 下一节下方展示当日剩余课程小卡：逐节减少，单个展开；当天只剩主卡时预览明天。
- Android 原生桌面小组件，支持 App 内请求添加、检测已添加数量和澎湃 OS 操作指引；iOS 15+ 小、中、大 WidgetKit 组件工程。
- 课程增删改查，一门课支持多组时间、不同教室、自选周次、单双周；自定义周次支持空格，如 `1 3 5 8-12`。
- 单次停课、跨周调课、临时换教室、撤销变更。
- 冲突提示与并排显示，重叠课程仍可点击。
- 自定义学期起始日、教学周数和每节课的起止时间；每天可配置 1—16 节。
- 默认凯里学院作息：上午 08:20–11:45、下午 14:00–17:25、晚课 19:00 开始；设置中可一键填入或继续自定义，升级时迁移原有默认作息。
- 两端均有 2×2 小方块与 4×2 横向双卡：小方块上下显示两门课，横向双卡放大课名、突出时间，内容随高度铺满；跨日期接续，展示起止时间、教室和调课状态。
- PDF、PNG/JPG/WebP 课表本地识别，导入前逐门核对和编辑，保留原文与待安排课程。
- UTF-8 CSV 模板导入，支持预览、追加或替换。
- JSON 完整备份和恢复，包含课程、作息、设置和单次变更。
- Android / iOS 使用 SQLite；浏览器预览使用本地站点存储。
- 明确标记的示例课表，可一键清空示例后开始建立个人课表。

目前只管理一份当前学期。提醒、教务自动导入、账号同步、深色模式尚未实现。Web 是评审与体验入口，当前不承诺离线启动能力。原生正式发布需要签名和真机验证。

## 运行

安装 Flutter 3.47.9，并将 `flutter/bin` 加入 PATH：

```sh
flutter pub get
flutter run -d chrome
```

Android 开发需要 JDK 17、Android SDK 36、NDK 28.2.13676358；SDK/Gradle 首次构建可能需要下载。连接测试设备后：

```sh
flutter run -d <device-id>
flutter build apk --release --target-platform android-arm64
```

Android 当前使用开发包标识 `dev.kejian.kejian`。正式发布前需确定包名、配置自己的签名，不能将模板内的 debug 签名配置用作正式发行方案。

iOS App 与 Widget 扩展均设置最低 iOS 15.0。已有可用 TrollStore 的设备可下载 `kejian-ios-trollstore-v0.3.3.ipa`，包含小、中、大 WidgetKit 扩展与共享 App Group。iOS 15.6.1 在支持范围内；安装后先启动主 App，再添加桌面小组件。常规 Apple 签名分发仍需完整 Xcode、开发团队和注册的 App Group。配置、构建和添加小组件的方法见 [移动端与小组件说明](docs/MOBILE.md)。

中国大陆网络可按需使用 Flutter 官方文档列出的镜像环境：

```sh
export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
export PUB_HOSTED_URL=https://pub.flutter-io.cn
flutter pub get
```

## Web 预览

```sh
flutter build web --release --no-web-resources-cdn
python3 -m http.server 8765 --bind 127.0.0.1 --directory build/web
```

在浏览器访问 `http://127.0.0.1:8765`。同源、同端口保留浏览器课表；更换浏览器、隐私模式或清理站点数据会影响本地数据。迁移时使用设置页的完整备份。

## 验证

```sh
dart format --output=none --set-exit-if-changed lib test tool
flutter analyze
flutter test
```

45 项 Flutter 测试覆盖课程规则、导入、布局、保存和恢复，以及剩余课程递减/明天预览、空格周次、小组件快照与同步失败、原版/宽版独立添加请求、默认作息迁移与预设取消/保存。原生共享数据与时间线另有 15 项 Swift Foundation 检查，包括两门课排序、跨日期接续和结束边界；它们不能替代 iOS UI 编译与设备验证。

示例文件在 `examples/`；可运行 `dart run tool/generate_examples.dart` 重新生成。当前示例固定采用 2026 年秋季学期，仅用于演示和测试。

## 项目文档

- [产品范围与后续路线](docs/PRODUCT.md)
- [PDF / 图片识别导入](docs/IMPORT.md)
- [Android / iOS 15 与小组件](docs/MOBILE.md)
- [凯里学院作息、升级与两门课小组件](docs/TIMETABLE_DEFAULTS.md)
- [架构、规则与备份格式](docs/ARCHITECTURE.md)
- [测试和平台验证记录](docs/VERIFICATION.md)
- [GitHub 参考与第三方素材](docs/REFERENCES.md)
- [参与贡献](CONTRIBUTING.md)

源码托管于 [2908746449/kejian](https://github.com/2908746449/kejian)。界面、课程规则与数据模型为独立实现；参考项目及各自许可记录在参考文档中。

## 许可证

应用源码采用 [MIT](LICENSE)。Noto Sans SC 字体采用 SIL OFL 1.1，见 `assets/fonts/OFL.txt`；第三方依赖保留各自许可，见 [第三方声明](THIRD_PARTY_NOTICES.md)。Android 图片识别使用非开源的 ML Kit 本地 SDK，iOS 使用系统 Vision；Web 使用开源 Tesseract.js。
