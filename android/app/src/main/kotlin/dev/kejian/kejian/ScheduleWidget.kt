package dev.kejian.kejian

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.res.Configuration
import android.os.Bundle
import android.widget.RemoteViews
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale
import java.util.TimeZone

/** Native RemoteViews work without a Flutter engine or an open app. */
open class ScheduleWidget : AppWidgetProvider() {
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
        val manager = AppWidgetManager.getInstance(context)
        if (providers(context).all { manager.getAppWidgetIds(it).isEmpty() }) {
            (context.getSystemService(Context.ALARM_SERVICE) as AlarmManager).cancel(refreshIntent(context))
        }
    }

    companion object {
        const val STORE = "kejian.widgets"
        const val KEY = "snapshot.v1"
        private const val REFRESH = "dev.kejian.kejian.WIDGET_REFRESH"

        fun providers(context: Context) = listOf(
            ComponentName(context, ScheduleWidget::class.java),
            ComponentName(context, WideScheduleWidget::class.java)
        )

        fun updateAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val widgets = listOf(
                ScheduleWidget::class.java to R.layout.widget_schedule_compact,
                WideScheduleWidget::class.java to R.layout.widget_schedule
            ).flatMap { (provider, layout) ->
                manager.getAppWidgetIds(ComponentName(context, provider)).map { id ->
                    val wide = provider == WideScheduleWidget::class.java
                    val options = manager.getAppWidgetOptions(id)
                    val heightKey = if (context.resources.configuration.orientation == Configuration.ORIENTATION_PORTRAIT)
                        AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT else AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT
                    val height = options.getInt(heightKey)
                    val sizedLayout = if (height in 1..159) {
                        if (wide) R.layout.widget_schedule_dense else R.layout.widget_schedule_compact_dense
                    } else layout
                    Triple(id, sizedLayout, wide)
                }
            }
            if (widgets.isEmpty()) return
            val now = System.currentTimeMillis()
            val snapshot = readSnapshot(context)
            val upcoming = snapshot?.lessons?.filter { it.end > now }.orEmpty()
            val next = upcoming.firstOrNull()
            val following = upcoming.getOrNull(1)
            val today = format("yyyy-MM-dd", now)
            val tomorrow = format("yyyy-MM-dd", Calendar.getInstance().apply { add(Calendar.DAY_OF_MONTH, 1) }.timeInMillis)
            val week = snapshot?.weekLabel(today) ?: "添加你的课程"
            for ((id, layout, wide) in widgets) {
                val views = RemoteViews(context.packageName, layout)
                views.setTextViewText(R.id.widget_date, if (wide) "课间 · ${format("M月d日", now)}" else "课间 · ${format("M/d", now)}")
                val width = manager.getAppWidgetOptions(id).getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH)
                val shortWeek = width in 1..199 && !wide
                views.setTextViewText(R.id.widget_week, if (snapshot?.isDemo == true) {
                    if (shortWeek) "示例" else "$week · 示例"
                } else if (shortWeek) week.replace(" ", "") else week)
                views.setTextViewText(R.id.widget_status, when {
                    snapshot == null -> "先打开课间，同步课表"
                    next == null -> "暂无后续课程"
                    next.start <= now -> "正在上课"
                    else -> if (wide) "下一节课" else "下一节"
                })
                views.setTextViewText(R.id.widget_name, next?.name ?: if (snapshot == null) "打开课间" else "自由时光")
                val whenText = next?.let { timeLabel(it, today) } ?: "点击打开课间"
                views.setTextViewText(R.id.widget_time, next?.let {
                    if (wide) clockLabel(it) else "${dayLabel(it, today, tomorrow)} ${clockLabel(it)}"
                } ?: "点击打开课间")
                views.setTextViewText(R.id.widget_room, next?.let {
                    (if (it.room.isEmpty()) "教室待补充" else it.room) + if (it.changed) " · 已调课" else ""
                } ?: if (snapshot == null) "同步你的课表" else "好好休息，慢慢来")
                views.setTextViewText(R.id.widget_second_status, if (following != null) "再下一节" else "接下来")
                views.setTextViewText(R.id.widget_second_name, following?.name ?: "暂无课程")
                views.setTextViewText(R.id.widget_second_time, following?.let {
                    if (wide) clockLabel(it) else "${dayLabel(it, today, tomorrow)} ${clockLabel(it)}"
                } ?: "暂无后续安排")
                views.setTextViewText(R.id.widget_second_room, following?.let {
                    (it.room.ifEmpty { "教室待补充" }) + if (it.changed) " · 已调课" else ""
                } ?: "留一点时间给自己")
                if (wide) {
                    views.setTextViewText(R.id.widget_day, next?.let { dayLabel(it, today, tomorrow) }.orEmpty())
                    views.setTextViewText(R.id.widget_second_day, following?.let { dayLabel(it, today, tomorrow) }.orEmpty())
                }
                val open = PendingIntent.getActivity(context, 0,
                    Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP),
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
                views.setOnClickPendingIntent(R.id.widget_root, open)
                val followingText = following?.let { "；再下一节，${it.name}，${timeLabel(it, today)}，${it.room}" }.orEmpty()
                views.setContentDescription(R.id.widget_root, "课间，$week，${next?.name.orEmpty()}，$whenText，${next?.room.orEmpty()}$followingText。点击打开应用")
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

        private fun timeLabel(lesson: WidgetLesson, today: String): String {
            val day = if (lesson.date == today) "今天" else format("M/d", lesson.start)
            return "$day ${clockLabel(lesson)}"
        }

        private fun clockLabel(lesson: WidgetLesson) = "${format("HH:mm", lesson.start)}—${format("HH:mm", lesson.end)}"

        private fun dayLabel(lesson: WidgetLesson, today: String, tomorrow: String) = when (lesson.date) {
            today -> "今天"
            tomorrow -> "明天"
            else -> format("M/d", lesson.start)
        }
    }
}

class WideScheduleWidget : ScheduleWidget()

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
