# 参与课间开发

欢迎提交问题与改进建议。反馈时附上平台、应用版本、复现步骤和去掉个人信息的最小课表样本。不要提交教务账号、密码、Cookie 或其他学生的个人数据。

开发前阅读 `docs/PRODUCT.md` 与 `docs/ARCHITECTURE.md`。修改课表规则时补充对应场景测试，并运行：

```sh
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build web --release --no-web-resources-cdn
```

学校导入适配应独立于课表显示逻辑。所有时间安排使用统一数据模型，避免在页面中重复编写周次规则。
