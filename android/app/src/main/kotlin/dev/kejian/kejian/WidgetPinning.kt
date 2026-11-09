package dev.kejian.kejian

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.os.Build

/** The launcher owns the confirmation UI. An accepted request is not a pin. */
object WidgetPinning {
    fun status(context: Context): Map<String, Any> {
        val manager = AppWidgetManager.getInstance(context)
        val providers = ScheduleWidget.providers(context)
        return mapOf(
            "registered" to providers.all { provider -> manager.installedProviders.any { it.provider == provider } },
            "pinSupported" to (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
                manager.isRequestPinAppWidgetSupported),
            "installedCount" to providers.sumOf { manager.getAppWidgetIds(it).size }
        )
    }

    fun request(context: Context, wide: Boolean = false): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return false
        val manager = AppWidgetManager.getInstance(context)
        if (!manager.isRequestPinAppWidgetSupported) return false
        val provider = ComponentName(context, if (wide) WideScheduleWidget::class.java else ScheduleWidget::class.java)
        check(manager.installedProviders.any { it.provider == provider })
        return manager.requestPinAppWidget(provider, null, null)
    }
}
