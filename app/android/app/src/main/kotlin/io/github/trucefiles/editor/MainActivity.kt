package io.github.trucefiles.editor

import android.content.Intent
import android.net.Uri
import android.os.Environment
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/** Hosts the app and answers the Dart side's storage access questions. */
class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
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

    private companion object {
        const val STORAGE_CHANNEL = "io.github.trucefiles.editor/storage_access"
    }
}
