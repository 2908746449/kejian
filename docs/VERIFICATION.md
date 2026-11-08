# 验证记录

日期：2026-11-08。版本：0.1.0 开发预览。

## 已通过

- `dart format --output=none --set-exit-if-changed lib test tool`。
- `flutter analyze --no-pub`：无问题。
- `flutter test --no-pub`：16 项测试全部通过（12 项规则/导入测试，4 项界面/存储状态测试）。
- `flutter build web --release --no-web-resources-cdn --no-pub`：成功生成 Web 构建。
- 实际浏览器操作：390×844 手机布局、1440×1050 宽屏布局，导航与周次切换正常。
- 浏览器新增一门验证用课程，刷新后仍存在；导出的 JSON 确认包含这门课程与完整作息。
- 从示例 JSON 预览并恢复，恢复后为 7 门课程、10 组安排。
- 实际选择 CSV 文件，正确预览 2 门课程、3 组安排，显示追加与替换选项。
- 浏览器未捕获 error / warn 日志。

测试通过不等同于已完成手机真机验证。`MemoryRepository` 测试验证写入顺序和恢复流程；原生 SQLite、原生文件选择器仍需要在设备上测试。

## 平台状态

- Web：构建与交互验证通过。
- Android：尚未生成 APK。首次构建发生 Gradle 依赖下载超时；单独下载并核对校验值后继续，进入 Android SDK/NDK 初始化。SDK 清单出现 IO 异常，NDK 28.2.13676358 下载未完成，已中止本轮打包。应用源码尚未经过原生编译和真机验证。
- iOS：工程已建立；本机没有完整 Xcode，未执行编译、签名或真机验证。

已补齐适配界面的 CupertinoIcons 字体依赖，最终 Web 构建没有字体缺失提示。

## 下一次原生构建

先在 Android SDK Manager 中完成 NDK 28.2.13676358 安装，确认 SDK Command-line Tools 与 SDK 元数据版本兼容，再运行 README 中的 Android 构建命令。本次未创建正式签名配置，未上传应用商店或 GitHub。
