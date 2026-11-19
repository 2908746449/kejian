# HarmonyOS 5+ 适配

课间的 HarmonyOS NEXT 目标为 API 12 起（HarmonyOS 5.0），使用社区维护的 Flutter OHOS 3.47.9 工具链。该工具链由 CPF-Flutter 维护，与 Flutter 上游 SDK 分支独立；不能将鸿蒙适配描述成 Flutter 官方支持。

## 当前实现

- 复用 Flutter 课表界面、课程规则、学期配置和 JSON 备份格式。
- 通过 ArkTS MethodChannel 将课表 JSON 保存在应用私有目录。Android/iOS 的 SQLite 存储不变。
- 使用 HarmonyOS 文档选择器导入 CSV、课间 JSON 备份、PDF 及 PNG/JPG/WebP 图片；导出 CSV 模板与 JSON 备份。
- 图片文字识别接入系统 CoreVisionKit；识别后的课程仍经过现有解析、预览、人工核对和课程校验流程。
- 提供 2×2 方形和 2×4 横向两种 ArkTS 服务卡片（鸿蒙配置按行×列表示），均显示接下来的两门课，包含上课中、跨日接续、教室和调课标记；点击卡片打开 App。保存课表后更新已安装卡片，失败可从设置重新同步。
- 系统配置为 30 分钟刷新周期，课程筛选在刷新时使用当前时间。系统调度可能延后刷新，当前不承诺在每个上下课边界即时切换。
- PDF 接入 `oh-flutter/pdfrx` 的 OHOS 适配分支，固定提交 `99b3c7e37639a21c61b131950c94472fd4410945`：pdfrx 2.6.5、pdfrx_engine 0.6.1、pdfium_dart / pdfium_flutter 0.3.1。arm64 PDFium 运行库来自该提交，准备脚本核对 SHA-256。文字层提取和扫描页渲染沿用现有处理流程；尚未在鸿蒙设备验证。

## 工具链

使用 CPF-Flutter `oh-3.47.9-dev` 分支（本轮检查的提交：`5455dafab5da2b2168671bf8a8bc19d015c7c6e6`，Dart 3.13.7）以及支持 HarmonyOS 5 / API 12 的 DevEco Studio、HarmonyOS SDK、Hvigor 和 ohpm。工具链安装与环境配置以 [Flutter OH 开发文档](https://gitcode.com/openharmony-tpc/flutter_samples) 和 [HarmonyOS 开发者文档](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/) 为准。

本仓库包含由该 Flutter SDK 生成的 `ohos/` 原生工程。最低兼容配置为 HarmonyOS 5.0.0 / API 12，编译目标为 5.0.5 / API 17。不要在原 Android / iOS 工程里覆盖 PDF 依赖；先从仓库根目录生成一个独立构建目录：

```sh
export FLUTTER_OHOS=/absolute/path/to/flutter-ohos
HARMONY_DIR="$(python3 tool/prepare_harmonyos.py)"
cd "$HARMONY_DIR"
"$FLUTTER_OHOS/bin/flutter" pub get
"$FLUTTER_OHOS/bin/dart" analyze lib test integration_test tool
"$FLUTTER_OHOS/bin/flutter" test
"$FLUTTER_OHOS/bin/flutter" build hap --release --target-platform ohos-arm64 --no-codesign
```

脚本保留根 `pubspec.lock` 并仅在副本添加四个 PDF 包的 path overrides；源码提交和 PDFium 哈希记录到副本的 `HARMONYOS_SOURCE.json`。复制后修改的根源码不会自动同步到副本，修改后需重新准备。PDFium 插件通过 HAR 打包 arm64 原生库；脚本在副本修补仅处理 Darwin 元数据的 link hook，源码依赖及原生合并仍需实际 HAP 构建验证。

上述命令只构建未签名 HAP，不能直接安装。需要在 DevEco Studio 打开独立目录中的 `ohos/`，使用自己的开发者身份配置签名，之后运行不带 `--no-codesign` 的构建命令。证书和 `.sign/` 保持本地，不能提交密钥。没有 DevEco/SDK 时可用 `python3 tool/prepare_harmonyos.py --checks-only` 省略原生 host，在生成的目录执行 Dart 分析和 Flutter 测试；这不执行 ArkTS 检查。

安装后先打开 App 同步课表，再在桌面服务卡片列表找到「课间」选择小方块或横向双课。实际入口依系统桌面版本而异。发布前需在 HarmonyOS 5 及更新设备验收文件导入/导出、PDF 文字层/扫描页、图片 OCR、存储重启恢复、两个卡片同时添加、周期刷新、跨日和卡片点击；当前卡片采用固定浅色外观。

## 验证边界

本轮 Flutter OHOS 的 Dart 分析和 53 项测试通过，包含 8 项鸿蒙通道/界面测试；Node 另有 11 项实际卡片 helper/配置检查通过。系统文件、文档选择和 OCR 在 Flutter 测试中使用模拟通道，不能据此认定系统 API 运行通过。

当前执行环境没有 DevEco Studio、HarmonyOS SDK、Hvigor、ohpm 或鸿蒙设备。ArkTS 类型检查、HAP 构建、签名、最低 API 12 原生库兼容及真机卡片渲染均未验证。没有发布可安装 HAP。工程文件存在不等于已构建或已通过设备验收；`ohosTest` 下的 Hypium 用例也尚未在设备执行。
