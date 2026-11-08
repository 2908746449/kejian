# 课间 · Kejian

一个留白多一点的开源大学课程表。手机优先，免登录，课表由你掌握。

当前版本：**0.1.0 开发预览**。Flutter 3.47.9 / Dart 3.13.7。Android、iOS 和 Web 工程已建立；Web 可直接运行，原生平台的验证状态见 `docs/VERIFICATION.md`。

## 已实现

- 周课表、当前周定位、下一节课、今天高亮和周末显示开关。
- 课程增删改查，一门课支持多组时间、不同教室、自选周次、单双周。
- 单次停课、跨周调课、临时换教室、撤销变更。
- 冲突提示与并排显示，重叠课程仍可点击。
- 自定义学期起始日、教学周数和每节课的起止时间。
- UTF-8 CSV 模板导入，支持预览、追加或替换。
- JSON 完整备份和恢复，包含课程、作息、设置和单次变更。
- Android / iOS 使用 SQLite；浏览器预览使用本地站点存储。
- 明确标记的示例课表，可一键清空示例后开始建立个人课表。

目前只管理一份当前学期。提醒、小组件、教务自动导入、账号同步、深色模式尚未实现。Web 是评审与体验入口，当前不承诺离线启动能力。原生正式发布需要签名和真机验证。

## 运行

安装 Flutter 3.47.9，并将 `flutter/bin` 加入 PATH：

```sh
flutter pub get
flutter run -d chrome
```

Android 开发需要 JDK 17、Android SDK 36、NDK 28.2.13676358；SDK/Gradle 首次构建可能需要下载。连接测试设备后：

```sh
flutter run -d <device-id>
flutter build apk --debug --target-platform android-arm64
```

Android 当前使用开发包标识 `dev.kejian.kejian`。正式发布前需确定包名、配置自己的签名，不能将模板内的 debug 签名配置用作正式发行方案。

iOS 需要完整 Xcode 与签名环境，本机仅有 Command Line Tools，当前未验证 iOS 编译和真机运行。

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

测试覆盖教学周边界、单双周、停课、跨周调课、下一节课、冲突、备份往返、坏数据、CSV 引号/换行/行号错误、手机与桌面布局、保存失败，以及重建应用后的数据恢复。

示例文件在 `examples/`；可运行 `dart run tool/generate_examples.dart` 重新生成。当前示例固定采用 2026 年秋季学期，仅用于演示和测试。

## 项目文档

- [产品范围与后续路线](docs/PRODUCT.md)
- [架构、规则与备份格式](docs/ARCHITECTURE.md)
- [测试和平台验证记录](docs/VERIFICATION.md)
- [GitHub 参考与第三方素材](docs/REFERENCES.md)
- [参与贡献](CONTRIBUTING.md)

本地仓库已准备，尚未发布到 GitHub。界面、课程规则与数据模型为独立实现；参考项目及各自许可记录在参考文档中。

## 许可证

应用源码采用 [MIT](LICENSE)。Noto Sans SC 字体采用 SIL OFL 1.1，见 `assets/fonts/OFL.txt`；第三方依赖保留各自许可。
