package dev.kejian.kejian

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "dev.kejian/widgets")
            .setMethodCallHandler { call, result ->
                if (call.method != "sync") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                try {
                    val source = call.arguments as? String ?: error("Missing snapshot")
                    require(JSONObject(source).getInt("version") == 1)
                    check(getSharedPreferences(ScheduleWidget.STORE, MODE_PRIVATE).edit()
                        .putString(ScheduleWidget.KEY, source).commit())
                    ScheduleWidget.updateAll(this)
                    result.success(null)
                } catch (error: Exception) {
                    result.error("WIDGET_SYNC", "无法保存小组件课表", null)
                }
            }
    }
}
