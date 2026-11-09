import Flutter
import UIKit
import WidgetKit
import Vision

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var widgetChannel: FlutterMethodChannel?
  private var recognitionChannel: FlutterMethodChannel?
  private var recognizing = false
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let recognition = FlutterMethodChannel(name: "dev.kejian/recognition", binaryMessenger: engineBridge.applicationRegistrar.messenger())
    recognitionChannel = recognition
    recognition.setMethodCallHandler { [weak self] call, result in
      guard call.method == "recognize" else { result(FlutterMethodNotImplemented); return }
      guard let self = self, !self.recognizing else {
        result(FlutterError(code: "OCR_BUSY", message: "正在识别另一份课表，请稍候。", details: nil)); return
      }
      guard let typed = call.arguments as? FlutterStandardTypedData,
            let image = UIImage(data: typed.data)?.cgImage else {
        result(FlutterError(code: "OCR_IMAGE", message: "无法读取图片，请使用 PNG 或 JPG。", details: nil)); return
      }
      self.recognizing = true
      DispatchQueue.global(qos: .userInitiated).async {
        do {
          let request = VNRecognizeTextRequest()
          request.recognitionLevel = .accurate
          request.recognitionLanguages = ["zh-Hans", "en-US"]
          request.usesLanguageCorrection = false
          try VNImageRequestHandler(cgImage: image).perform([request])
          var boxes: [[String: Any]] = []
          for observation in request.results ?? [] {
            guard let candidate = observation.topCandidates(1).first else { continue }
            for index in candidate.string.indices {
              let end = candidate.string.index(after: index)
              guard let rect = try candidate.boundingBox(for: index..<end)?.boundingBox else { continue }
              boxes.append(["text": String(candidate.string[index]),
                "x": rect.minX * Double(image.width), "y": (1-rect.maxY) * Double(image.height),
                "width": rect.width * Double(image.width), "height": rect.height * Double(image.height)])
            }
          }
          DispatchQueue.main.async { self.recognizing = false; result(boxes) }
        } catch {
          DispatchQueue.main.async {
            self.recognizing = false
            result(FlutterError(code: "OCR_FAILED", message: "图片识别失败，请换一张清晰完整的课表。", details: nil))
          }
        }
      }
    }
    let channel = FlutterMethodChannel(name: "dev.kejian/widgets", binaryMessenger: engineBridge.applicationRegistrar.messenger())
    widgetChannel = channel
    channel.setMethodCallHandler { call, result in
      guard call.method == "sync" else {
        result(FlutterMethodNotImplemented)
        return
      }
      do {
        guard let source = call.arguments as? String else { throw CocoaError(.coderReadCorrupt) }
        try WidgetStore.write(source)
        WidgetCenter.shared.reloadAllTimelines()
        result(nil)
      } catch {
        result(FlutterError(code: "WIDGET_SYNC", message: "小组件数据未能写入，请检查 App Group 配置", details: nil))
      }
    }
  }
}
