package app.thetwodigiter.devsprint

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.widget.RemoteViews
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale

object WidgetState {
    const val PREFS_NAME = "devsprint_widget"
    const val STATE_KEY = "state_json"
    const val ACTION_UPDATE = "app.thetwodigiter.devsprint.ACTION_UPDATE_WIDGET"

    fun load(context: Context): JSONObject {
        val raw = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .getString(STATE_KEY, null) ?: return JSONObject()
        return try { JSONObject(raw) } catch (_: Exception) { JSONObject() }
    }

    fun launchIntent(context: Context, requestCode: Int): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        return PendingIntent.getActivity(
            context, requestCode, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    fun formatMinutes(minutes: Int): String {
        if (minutes <= 0) return "0m"
        val hours = minutes / 60
        val mins = minutes % 60
        return if (hours > 0) "${hours}h ${mins}m" else "${mins}m"
    }

    fun setClick(views: RemoteViews, context: Context, rootId: Int, requestCode: Int) {
        views.setOnClickPendingIntent(rootId, launchIntent(context, requestCode))
    }
}
