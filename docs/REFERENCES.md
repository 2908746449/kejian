# 参考与第三方素材

核对日期：2026-11-09。

## 功能与结构参考

- [SleepIn](https://github.com/Kurosu-Ti01/SleepIn)：阅读项目 README，借鉴自定义作息、周视图、CSV、教务导入和小组件的功能分层。该项目使用 GPL-3.0；本项目没有复制其实现代码或视觉资源。
- [XDYou / Traintime PDA](https://github.com/BenderBlog/traintime_pda)：阅读 README 及其课程时间表示例，参考课程表页面与学校信息获取模块分离的思路。主项目采用 MPL-2.0，部分文件另有许可；本项目未使用其源码、图标或其他品牌素材。

本项目中的 Flutter UI、课程规则引擎、数据模型、CSV 解析与测试为独立实现。GitHub 项目仅作设计调研参考。

## 字体

Noto Sans SC 来自 [Google Fonts](https://github.com/google/fonts/tree/main/ofl/notosanssc)，字体版权与 SIL Open Font License 1.1 位于 `assets/fonts/OFL.txt`。字体随应用打包，以减少中文显示对外部资源的依赖。该字体不受本项目 MIT 许可证替代。

## 工具与依赖

- Flutter SDK 3.47.9 / Dart 3.13.7，来自 Flutter 官方 GitHub 仓库，SDK 产物下载使用 Flutter 中国镜像。
- sqflite、shared_preferences、file_picker：版本由 `pubspec.lock` 固定。
- Material Icons 随 Flutter 分发；第三方许可证可从设置中的「开源许可」查看。

技术依据为 Flutter 官方文档、依赖包自身 API 和源代码；没有引入其他课程表项目的代码依赖。

## Android 小组件入口

- [Android 固定小组件 API](https://developer.android.com/reference/android/appwidget/AppWidgetManager#requestPinAppWidget(android.content.ComponentName,android.os.Bundle,android.app.PendingIntent))：检查桌面支持后请求固定；返回成功仅代表桌面接受请求，最终添加由用户确认。
- [Android 小组件注册](https://developer.android.com/develop/ui/views/appwidgets/overview)：保持非导出的 AppWidgetProvider，提供 provider metadata、布局与预览。
- [小米小部件适配说明](https://dev.mi.com/xiaomihyperos/documentation/detail?pId=1588)：独立的「安卓小部件」入口可从搜索页应用列表底部进入；仅参考官方入口说明，未引入专有小米小部件 SDK。

## 本地文档识别方案

- [pdfrx](https://github.com/espresso3389/pdfrx)：采用 2.12.0 的 PDFium 文字和坐标提取、扫描页渲染 API。依赖 pdfrx_engine 0.9.1、pdfium_dart 0.4.1；MIT。pdfrx 的 iOS 插件声明最低 15.0。
- [PDFium binaries](https://github.com/bblanchon/pdfium-binaries)：pdfium_dart 当前下载 chromium/8125 预编译引擎。分发包主 LICENSE 和 licenses 目录均保留在 `assets/licenses/PDFium.txt`。
- [Tesseract.js](https://github.com/naptha/tesseract.js) 与 [tesseract.js-core](https://github.com/naptha/tesseract.js-core)：采用各自 7.0.0 的本地 worker / WASM，保留 Apache-2.0 与压缩包附带声明。浏览器不将课表上传到识别服务。
- [naptha/tessdata](https://github.com/naptha/tessdata) / [tessdata_best](https://github.com/tesseract-ocr/tessdata_best)：中文模型来自 npm `@tesseract.js-data/chi_sim@1.0.0` 的 `4.0.0_best_int`，仅使用中文模型（包含数字和 ASCII）；模型上游 Apache-2.0，包元数据 MIT，来源区别见第三方声明。
- [Android 中文文字识别](https://developers.google.com/ml-kit/vision/text-recognition/v2/android)：使用 `com.google.mlkit:text-recognition-chinese:16.0.1` 预打包模型，实际读取 symbol 坐标。ML Kit 是 Google 的专有 SDK，不列为开源库。
- [Apple Vision](https://developer.apple.com/documentation/vision/vnrecognizetextrequest)：使用 iOS 系统中文/英文文字识别与字符包围框，未引入需要更高最低 iOS 的第三方 OCR 插件。App 与扩展已通过云端完整 Xcode 模拟器编译，识别运行仍需真机验证。

参考的是「本地引擎提取文字和坐标 → 表格解析 → 人工核对」的处理流程。课表布局解析器、格线预处理、课程合并和核对页为本项目实现，没有复制其他课程表项目的识别代码。更多分发信息见 `THIRD_PARTY_NOTICES.md`。
