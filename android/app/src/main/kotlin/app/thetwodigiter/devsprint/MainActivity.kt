package app.thetwodigiter.devsprint

import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL = "app.thetwodigiter.devsprint/widget"
        private const val PREFS_NAME = "devsprint_widget"
        private const val STATE_KEY = "state_json"
        private const val ACTION_UPDATE =
            "app.thetwodigiter.devsprint.ACTION_UPDATE_WIDGET"

        fun saveWidgetState(context: Context, stateJson: String) {
            context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                .edit()
                .putString(STATE_KEY, stateJson)
                .apply()

            val intent = Intent(ACTION_UPDATE).apply {
                setPackage(context.packageName)
            }
            context.sendBroadcast(intent)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "updateWidget" -> {
                        val stateJson = call.argument<String>("state")
                        if (stateJson.isNullOrBlank()) {
                            result.error("INVALID_STATE", "Widget state is empty.", null)
                        } else {
                            saveWidgetState(this, stateJson)
                            result.success(null)
                        }
                    }

                    else -> result.notImplemented()
                }
            }
    }
}
