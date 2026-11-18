package io.github.trucefiles.editor

import android.content.Intent
import android.net.Uri
import android.os.Environment
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Hosts the app, answers the Dart side's storage access questions, and
 * shows the app over the lock screen while an alarm shows.
 */
class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ALARM_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "showOverLock" -> {
                        showOverLock(call.arguments as Boolean)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, STORAGE_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "hasAccess" -> result.success(Environment.isExternalStorageManager())
                    "requestAccess" -> {
                        openAccessSettings()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /** Opens the system page where the user allows all-files access. */
    private fun openAccessSettings() {
        startActivity(
            Intent(
                Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION,
                Uri.parse("package:$packageName"),
            ),
        )
    }

    /**
     * Shows the app over the lock screen and turns the screen on, or no
     * longer: only while an alarm shows, so notes never show there.
     */
    private fun showOverLock(show: Boolean) {
        setShowWhenLocked(show)
        setTurnScreenOn(show)
    }

    private companion object {
        const val STORAGE_CHANNEL = "io.github.trucefiles.editor/storage_access"
        const val ALARM_CHANNEL = "io.github.trucefiles.editor/alarm_window"
    }
}
