package app.thetwodigiter.devsprint

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.view.View
import android.widget.RemoteViews
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale

class DevSprintWidgetProvider : AppWidgetProvider() {
    companion object {
        private val successColors = intArrayOf(
            Color.rgb(198, 239, 206), Color.rgb(135, 218, 151),
            Color.rgb(72, 190, 104), Color.rgb(35, 145, 70)
        )
        private val failedColors = intArrayOf(
            Color.rgb(255, 218, 218), Color.rgb(255, 170, 170),
            Color.rgb(240, 105, 105), Color.rgb(190, 55, 55)
        )

        fun updateAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val component = android.content.ComponentName(context, DevSprintWidgetProvider::class.java)
            manager.getAppWidgetIds(component).forEach { updateWidget(context, manager, it) }
        }

        private fun updateWidget(context: Context, manager: AppWidgetManager, widgetId: Int) {
            val options = manager.getAppWidgetOptions(widgetId)
            val minWidth = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 320)
            val minHeight = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 180)
            val compact = minWidth < 280 || minHeight < 180
            val layout = if (compact) R.layout.widget_dev_sprint_compact else R.layout.widget_dev_sprint
            val views = RemoteViews(context.packageName, layout)
            val state = WidgetState.load(context)
            val now = Calendar.getInstance()
            val monthKey = state.optString("month", SimpleDateFormat("yyyy-MM", Locale.US).format(now.time))
            val parts = monthKey.split("-")
            val year = parts.getOrNull(0)?.toIntOrNull() ?: now.get(Calendar.YEAR)
            val month = (parts.getOrNull(1)?.toIntOrNull() ?: now.get(Calendar.MONTH) + 1) - 1
            val monthCalendar = Calendar.getInstance().apply {
                set(year, month, 1, 0, 0, 0); set(Calendar.MILLISECOND, 0)
            }
            views.setTextViewText(R.id.widget_month, SimpleDateFormat("MMMM", Locale.getDefault()).format(monthCalendar.time))
            views.setTextViewText(R.id.widget_completed, state.optInt("completed", 0).toString())
            views.setTextViewText(R.id.widget_failed, state.optInt("failed", 0).toString())
            views.setTextViewText(R.id.widget_average, if (state.optInt("averageScore", 0) > 0) state.optInt("averageScore").toString() else "—")
            views.setTextViewText(R.id.widget_focused, WidgetState.formatMinutes(state.optInt("focusedMinutes", 0)))
            if (!compact) views.setTextViewText(R.id.widget_practice, state.optString("mostPracticed", "No activity yet"))

            val days = state.optJSONObject("days") ?: org.json.JSONObject()
            views.removeAllViews(R.id.widget_heatmap_grid)
            val firstDay = monthCalendar.get(Calendar.DAY_OF_WEEK)
            val offset = (firstDay + 5) % 7
            val daysInMonth = monthCalendar.getActualMaximum(Calendar.DAY_OF_MONTH)
            val cellCount = if (compact) 21 else 42
            for (cellIndex in 0 until cellCount) {
                val cell = RemoteViews(context.packageName, R.layout.widget_day_cell)
                val dayNumber = cellIndex - offset + 1
                if (dayNumber in 1..daysInMonth) {
                    val key = String.format(Locale.US, "%04d-%02d-%02d", year, month + 1, dayNumber)
                    val status = days.optString(key, "")
                    val intensity = days.optInt("${key}_intensity", 1).coerceIn(1, 4)
                    cell.setTextViewText(R.id.widget_day_cell_text, dayNumber.toString())
                    cell.setViewVisibility(R.id.widget_day_cell_text, View.VISIBLE)
                    val bg = when (status) { "success" -> successColors[intensity - 1]; "failed" -> failedColors[intensity - 1]; else -> Color.rgb(48,48,52) }
                    val fg = when (status) { "success" -> Color.rgb(20,72,38); "failed" -> Color.rgb(92,24,24); else -> Color.rgb(150,150,155) }
                    cell.setInt(R.id.widget_day_cell, "setBackgroundColor", bg)
                    cell.setTextColor(R.id.widget_day_cell_text, fg)
                } else {
                    cell.setViewVisibility(R.id.widget_day_cell_text, View.INVISIBLE)
                    cell.setInt(R.id.widget_day_cell, "setBackgroundColor", Color.TRANSPARENT)
                }
                views.addView(R.id.widget_heatmap_grid, cell)
            }
            WidgetState.setClick(views, context, R.id.widget_root, 1001)
            manager.updateAppWidget(widgetId, views)
        }
    }

    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        ids.forEach { updateWidget(context, manager, it) }
    }

    override fun onAppWidgetOptionsChanged(context: Context, manager: AppWidgetManager, widgetId: Int, newOptions: android.os.Bundle) {
        super.onAppWidgetOptionsChanged(context, manager, widgetId, newOptions)
        updateWidget(context, manager, widgetId)
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == WidgetState.ACTION_UPDATE) updateAll(context)
    }

    override fun onEnabled(context: Context) { super.onEnabled(context); updateAll(context) }
}
