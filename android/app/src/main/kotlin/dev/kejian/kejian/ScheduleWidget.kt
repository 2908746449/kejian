package dev.kejian.kejian

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.view.View
import android.widget.RemoteViews
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale
import java.util.TimeZone

/** Native RemoteViews work without a Flutter engine or an open app. */
class ScheduleWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) = updateAll(context)

    override fun onAppWidgetOptionsChanged(context: Context, manager: AppWidgetManager, id: Int, options: Bundle) = updateAll(context)

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action in setOf(REFRESH, Intent.ACTION_DATE_CHANGED, Intent.ACTION_TIME_CHANGED,
                Intent.ACTION_TIMEZONE_CHANGED, Intent.ACTION_BOOT_COMPLETED, Intent.ACTION_MY_PACKAGE_REPLACED)) {
            updateAll(context)
        }
    }

    override fun onDisabled(context: Context) {
        (context.getSystemService(Context.ALARM_SERVICE) as AlarmManager).cancel(refreshIntent(context))
    }

    companion object {
        const val STORE = "kejian.widgets"
        const val KEY = "snapshot.v1"
        private const val REFRESH = "dev.kejian.kejian.WIDGET_REFRESH"

        fun updateAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(ComponentName(context, ScheduleWidget::class.java))
            if (ids.isEmpty()) return
            val now = System.currentTimeMillis()
            val snapshot = readSnapshot(context)
            val upcoming = snapshot?.lessons?.filter { it.end > now }.orEmpty()
            val next = upcoming.firstOrNull()
            val today = format("yyyy-MM-dd", now)
            val week = snapshot?.weekLabel(today) ?: "添加你的课程"
            for (id in ids) {
                val views = RemoteViews(context.packageName, R.layout.widget_schedule)
                views.setTextViewText(R.id.widget_date, "课间 · ${format("M月d日", now)}")
                views.setTextViewText(R.id.widget_week, if (snapshot?.isDemo == true) "$week · 示例" else week)
                views.setTextViewText(R.id.widget_status, when {
                    snapshot == null -> "先打开课间，同步课表"
                    next == null -> "暂无后续课程"
                    next.start <= now -> "正在上课"
                    else -> "下一节课"
                })
                views.setTextViewText(R.id.widget_name, next?.name ?: "享受一段自由时光")
                val whenText = next?.let {
                    val day = if (it.date == today) "今天" else format("M/d", it.start)
                    "$day ${format("HH:mm", it.start)}—${format("HH:mm", it.end)}"
                } ?: "点击打开课间"
                views.setTextViewText(R.id.widget_time, whenText)
                views.setTextViewText(R.id.widget_room, next?.let {
                    (if (it.room.isEmpty()) "教室待补充" else it.room) + if (it.changed) " · 已调课" else ""
                } ?: "好好上课，也好好生活。")
                val rows = upcoming.filter { it.date == today && it !== next }.take(2)
                views.setViewVisibility(R.id.widget_rows,
                    if (manager.getAppWidgetOptions(id).getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT) >= 180 && rows.isNotEmpty()) View.VISIBLE else View.GONE)
                for ((index, rowId) in listOf(R.id.widget_row_one, R.id.widget_row_two).withIndex()) {
                    views.setViewVisibility(rowId, if (index < rows.size) View.VISIBLE else View.GONE)
                    rows.getOrNull(index)?.let {
                        views.setTextViewText(rowId, "${format("HH:mm", it.start)}  ${it.name} · ${it.room.ifEmpty { "教室待补充" }}")
                    }
                }
                val open = PendingIntent.getActivity(context, 0,
                    Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP),
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
                views.setOnClickPendingIntent(R.id.widget_root, open)
                views.setContentDescription(R.id.widget_root, "课间，$week，${next?.name.orEmpty()}，$whenText，${next?.room.orEmpty()}。点击打开应用")
                manager.updateAppWidget(id, views)
            }
            // Inexact alarms require no exact-alarm permission. The launcher/OS may
            // defer refreshes; a 30-minute provider refresh is also configured.
            val midnight = Calendar.getInstance().apply {
                add(Calendar.DAY_OF_MONTH, 1)
                set(Calendar.HOUR_OF_DAY, 0); set(Calendar.MINUTE, 0)
                set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0)
            }.timeInMillis
            val boundary = upcoming.flatMap { listOf(it.start, it.end) }.filter { it > now }.minOrNull()
            val refresh = minOf(midnight, boundary ?: midnight)
            (context.getSystemService(Context.ALARM_SERVICE) as AlarmManager)
                .setAndAllowWhileIdle(AlarmManager.RTC, refresh, refreshIntent(context))
        }

        private fun refreshIntent(context: Context) = PendingIntent.getBroadcast(
            context, 1, Intent(context, ScheduleWidget::class.java).setAction(REFRESH),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)

        private fun readSnapshot(context: Context): Snapshot? = try {
            val source = context.getSharedPreferences(STORE, Context.MODE_PRIVATE).getString(KEY, null)
            source?.let { Snapshot(JSONObject(it)) }
        } catch (_: Exception) { null }

        private fun format(pattern: String, milliseconds: Long) =
            SimpleDateFormat(pattern, Locale.CHINA).format(Date(milliseconds))
    }
}

private data class WidgetLesson(val name: String, val room: String, val date: String,
    val start: Long, val end: Long, val changed: Boolean)

private class Snapshot(json: JSONObject) {
    val isDemo = json.optBoolean("isDemo")
    private val firstMonday = json.getString("firstMonday")
    private val weekCount = json.getInt("weekCount")
    val lessons: List<WidgetLesson>
    init {
        require(json.getInt("version") == 1)
        val parser = SimpleDateFormat("yyyy-MM-dd'T'HH:mm", Locale.US).apply { isLenient = false }
        val array = json.getJSONArray("lessons")
        lessons = (0 until array.length()).map { index ->
            val item = array.getJSONObject(index)
            val date = item.getString("date")
            WidgetLesson(item.getString("name"), item.getString("room"), date,
                parser.parse("${date}T${item.getString("start")}")!!.time,
                parser.parse("${date}T${item.getString("end")}")!!.time, item.optBoolean("changed"))
        }.sortedBy { it.start }
    }
    fun weekLabel(today: String): String {
        val parser = SimpleDateFormat("yyyy-MM-dd", Locale.US).apply { timeZone = TimeZone.getTimeZone("UTC") }
        val days = (parser.parse(today)!!.time - parser.parse(firstMonday)!!.time) / 86400000L
        val week = Math.floorDiv(days, 7).toInt() + 1
        return when {
            week < 1 -> "学期未开始"
            week > weekCount -> "学期已结束"
            else -> "第 $week 周"
        }
    }
}
