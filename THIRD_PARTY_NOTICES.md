# 第三方声明

课间源码采用 MIT。下列依赖和素材保留各自许可，不受本项目许可证替代。版本锁定于 `pubspec.lock`；Flutter 依赖的完整声明可在 App「设置 → 开源许可」查看。

| 组件 | 用途 | 来源与许可 |
| --- | --- | --- |
| pdfrx 2.12.0 / pdfrx_engine 0.9.1 / pdfium_dart 0.4.1 | 本地 PDF 文字、坐标与扫描页渲染 | espresso3389/pdfrx，MIT |
| PDFium chromium/8125 Android binary | Android PDF 引擎 | bblanchon/pdfium-binaries / Chromium PDFium；BSD 风格主许可及其依赖许可 |
| Tesseract.js 7.0.0 / tesseract.js-core 7.0.0 | Web OCR worker / WASM | naptha，Apache-2.0 |
| chi_sim 4.0.0_best_int | Web 中文模型 | naptha/tessdata；上游 tesseract-ocr/tessdata_best，Apache-2.0 |
| Noto Sans SC | 中文字体 | Google Fonts，SIL OFL 1.1，`assets/fonts/OFL.txt` |
| ML Kit Chinese Text Recognition 16.0.1 | Android 本地 OCR | Google 专有 SDK，适用 Google API / ML Kit 条款，不宣称开源 |
| Apple Vision | iOS 本地 OCR | iOS 系统框架，适用 Apple SDK 条款 |

PDFium Android 分发包的 LICENSE 和各第三方许可证全文合并在 `assets/licenses/PDFium.txt`；随 App/Web 打包。pdfrx 的 Web WASM 由依赖包提供，其许可证随 Flutter NOTICES 分发。Tesseract 及模型声明保存在 `web/ocr/LICENSE-*` 和 `assets/licenses/`；压缩 worker 的附带声明也保留原文件。

`@tesseract.js-data/chi_sim@1.0.0` 的 npm 包元数据标注 MIT；训练模型按上游 Apache-2.0 声明分发，保留双方来源，不用包元数据替代模型许可。

参考链接、功能调研及没有复制的课程表项目见 `docs/REFERENCES.md`。
