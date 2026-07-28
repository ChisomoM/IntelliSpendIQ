package com.intellispendiq.app

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import android.provider.Telephony
import androidx.core.content.ContextCompat

/**
 * Reads the SMS inbox via the `content://sms/inbox` content provider.
 *
 * Native code only captures and forwards `{id, address, body, date}` —
 * all parsing stays in Dart so parser unit tests never need a device.
 */
class SmsInboxBridge(private val context: Context) {

    fun hasSmsPermission(): Boolean =
        ContextCompat.checkSelfPermission(context, Manifest.permission.READ_SMS) ==
            PackageManager.PERMISSION_GRANTED

    /**
     * Returns inbox messages received at or after [sinceMs], newest first.
     * Returns an empty list when the permission has not been granted —
     * the Dart side treats that as "nothing captured", never as an error
     * that could drop data silently.
     */
    fun readInboxSince(sinceMs: Long): List<Map<String, Any?>> {
        if (!hasSmsPermission()) return emptyList()

        val projection = arrayOf(
            Telephony.Sms._ID,
            Telephony.Sms.ADDRESS,
            Telephony.Sms.BODY,
            Telephony.Sms.DATE,
        )
        val messages = mutableListOf<Map<String, Any?>>()

        context.contentResolver.query(
            Telephony.Sms.Inbox.CONTENT_URI,
            projection,
            "${Telephony.Sms.DATE} >= ?",
            arrayOf(sinceMs.toString()),
            "${Telephony.Sms.DATE} DESC",
        )?.use { cursor ->
            val idIndex = cursor.getColumnIndexOrThrow(Telephony.Sms._ID)
            val addressIndex = cursor.getColumnIndexOrThrow(Telephony.Sms.ADDRESS)
            val bodyIndex = cursor.getColumnIndexOrThrow(Telephony.Sms.BODY)
            val dateIndex = cursor.getColumnIndexOrThrow(Telephony.Sms.DATE)

            while (cursor.moveToNext()) {
                messages.add(
                    mapOf(
                        "id" to cursor.getString(idIndex),
                        "address" to cursor.getString(addressIndex),
                        "body" to (cursor.getString(bodyIndex) ?: ""),
                        "date" to cursor.getLong(dateIndex),
                    ),
                )
            }
        }
        return messages
    }

    companion object {
        const val SMS_PERMISSION_REQUEST_CODE = 4201

        fun requestSmsPermission(activity: Activity) {
            activity.requestPermissions(
                arrayOf(Manifest.permission.READ_SMS, Manifest.permission.RECEIVE_SMS),
                SMS_PERMISSION_REQUEST_CODE,
            )
        }
    }
}
