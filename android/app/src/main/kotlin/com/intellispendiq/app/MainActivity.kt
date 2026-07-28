package com.intellispendiq.app

import android.content.Intent
import android.provider.Settings
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private companion object {
        const val METHOD_CHANNEL = "com.intellispendiq/capture"
        const val EVENT_CHANNEL = "com.intellispendiq/capture_events"
    }

    private lateinit var smsBridge: SmsInboxBridge
    private var pendingPermissionResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        smsBridge = SmsInboxBridge(applicationContext)

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            .setStreamHandler(CaptureEventStreamHandler)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "hasSmsPermission" -> result.success(smsBridge.hasSmsPermission())

                    "requestSmsPermission" -> {
                        if (smsBridge.hasSmsPermission()) {
                            result.success(true)
                        } else {
                            // Answered in onRequestPermissionsResult.
                            pendingPermissionResult = result
                            SmsInboxBridge.requestSmsPermission(this)
                        }
                    }

                    "readInboxSince" -> {
                        val sinceMs = when (val raw = call.argument<Any>("sinceMs")) {
                            is Int -> raw.toLong()
                            is Long -> raw
                            else -> 0L
                        }
                        result.success(smsBridge.readInboxSince(sinceMs))
                    }

                    "isNotificationAccessGranted" -> {
                        val enabled = Settings.Secure.getString(
                            contentResolver,
                            "enabled_notification_listeners",
                        )
                        result.success(enabled?.contains(packageName) == true)
                    }

                    "requestNotificationAccess" -> {
                        // Notification access cannot be granted programmatically;
                        // deep-link the user into system settings.
                        startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS))
                        result.success(null)
                    }

                    else -> result.notImplemented()
                }
            }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != SmsInboxBridge.SMS_PERMISSION_REQUEST_CODE) return

        pendingPermissionResult?.success(smsBridge.hasSmsPermission())
        pendingPermissionResult = null
    }
}
