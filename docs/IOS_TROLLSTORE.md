# iPhone 巨魔安装

课间 0.3.2 提供 `kejian-ios-trollstore-v0.3.2.ipa`，面向已经安装并能正常使用 TrollStore 的设备。项目最低 iOS 15.0；本次目标设备是 iOS 15.6.1。默认使用凯里学院作息，原版与宽版两个独立小组件均显示接下来的两门课。原版保留小、中、大尺寸并上下排列，宽版支持中、大尺寸并左右排列。

1. 下载 IPA，在 iPhone 的「文件」中点分享并选择 TrollStore；也可以在 TrollStore 内点击「+」选择 IPA。
2. 确认安装后打开课间，导入或建立课表。
3. 进入「设置 → 桌面小组件」，点「重新同步小组件」。
4. 回到主屏幕，长按空白处，点击左上角「+」，搜索「课间」，选择「课间 · 原版」或「课间 · 宽版」，再选择尺寸并添加。

IPA 是 iPhoneOS arm64 / AOT Release 包，版本 0.3.2（5），内含 WidgetKit 扩展和共享 App Group。TrollStore 在设备上完成安装签名；本包不用于 TestFlight 或 App Store。

课表修改会自动请求同步。系统安排小组件实际刷新时间；首次安装请先启动主 App。安装、App Group 写入、文件导入和原版/宽版各尺寸的小组件仍需在实际设备上验收。

校验报告 `kejian-ios-trollstore-v0.3.2.json` 记录 IPA SHA-256、构建提交、原生二进制架构、平台、最低系统和 ldid CodeDirectory 哈希。`SHA256SUMS.txt` 提供下载文件的 SHA-256。

TrollStore 官方说明：<https://github.com/opa334/TrollStore>
