# 参考与第三方素材

核对日期：2026-11-08。

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
