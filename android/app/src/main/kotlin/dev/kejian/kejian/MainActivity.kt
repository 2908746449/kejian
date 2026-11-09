package dev.kejian.kejian

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import android.graphics.BitmapFactory
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions

class MainActivity : FlutterActivity() {
    private var recognizing = false
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "dev.kejian/recognition")
            .setMethodCallHandler { call, result ->
                if (call.method != "recognize") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                if (recognizing) {
                    result.error("OCR_BUSY", "正在识别另一份课表，请稍候。", null)
                    return@setMethodCallHandler
                }
                val bytes = call.arguments as? ByteArray
                val bitmap = bytes?.let { BitmapFactory.decodeByteArray(it, 0, it.size) }
                if (bitmap == null) {
                    result.error("OCR_IMAGE", "无法读取图片，请使用 PNG 或 JPG。", null)
                    return@setMethodCallHandler
                }
                recognizing = true
                val recognizer = TextRecognition.getClient(ChineseTextRecognizerOptions.Builder().build())
                recognizer.process(InputImage.fromBitmap(bitmap, 0))
                    .addOnSuccessListener { text ->
                        val boxes = text.textBlocks.flatMap { it.lines }.flatMap { it.elements }
                            .flatMap { element ->
                                element.symbols.mapNotNull { symbol ->
                                    symbol.boundingBox?.let { b ->
                                        mapOf("text" to symbol.text, "x" to b.left.toDouble(), "y" to b.top.toDouble(),
                                            "width" to b.width().toDouble(), "height" to b.height().toDouble())
                                    }
                                }
                            }
                        result.success(boxes)
                    }
                    .addOnFailureListener { result.error("OCR_FAILED", "图片识别失败，请换一张清晰完整的课表。", null) }
                    .addOnCompleteListener { recognizing = false; recognizer.close(); bitmap.recycle() }
            }
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
