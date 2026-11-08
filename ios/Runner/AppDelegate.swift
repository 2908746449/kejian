import Flutter
import UIKit
import WidgetKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var widgetChannel: FlutterMethodChannel?
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
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
        WidgetCenter.shared.reloadTimelines(ofKind: "KejianScheduleWidget")
        result(nil)
      } catch {
        result(FlutterError(code: "WIDGET_SYNC", message: "小组件数据未能写入，请检查 App Group 配置", details: nil))
      }
    }
  }
}
