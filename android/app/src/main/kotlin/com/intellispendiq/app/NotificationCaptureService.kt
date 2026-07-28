package com.intellispendiq.app

import android.app.Notification
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification

/**
 * Secondary capture channel (D22), feature-flagged off by default.
 *
 * Kept so the app has a Play-Store-compatible path later, and so
 * push-only alerts can be captured if any provider stops sending SMS.
 * Forwards to the same raw_captures pipeline as SMS.
 *
 * Android 15+ may redact sensitive notification text, which is why SMS
 * remains the primary channel for this user group.
 */
class NotificationCaptureService : NotificationListenerService() {

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        val notification = sbn?.notification ?: return
        val extras = notification.extras ?: return

        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString()
        val text = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString()
            ?: extras.getCharSequence(Notification.EXTRA_BIG_TEXT)?.toString()
        if (text.isNullOrBlank()) return

        CaptureEventStreamHandler.emit(
            mapOf(
                "channel" to "notification",
                "packageName" to sbn.packageName,
                "title" to title,
                "body" to text,
                "date" to sbn.postTime,
            ),
        )
    }
}
