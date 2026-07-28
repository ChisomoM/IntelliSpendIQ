package com.intellispendiq.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony

/**
 * Forwards incoming SMS to the Dart event sink while the app is running.
 *
 * This is a convenience path only: the launch-time inbox diff in
 * [SmsInboxBridge] remains the source of truth, because OEM ROMs drop
 * or delay these broadcasts (plan risk #10). Messages missed here are
 * picked up by the next backfill.
 */
class SmsReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context?, intent: Intent?) {
        if (intent?.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) return

        // Multipart messages arrive as several PDUs; concatenate the body
        // per originating address so a long alert is not split in two.
        val bodies = mutableMapOf<String, StringBuilder>()
        var timestamp = System.currentTimeMillis()

        for (message in Telephony.Sms.Intents.getMessagesFromIntent(intent) ?: emptyArray()) {
            val address = message.originatingAddress ?: continue
            bodies.getOrPut(address) { StringBuilder() }.append(message.messageBody ?: "")
            timestamp = message.timestampMillis
        }

        for ((address, body) in bodies) {
            CaptureEventStreamHandler.emit(
                mapOf(
                    "channel" to "sms",
                    "id" to null,
                    "address" to address,
                    "body" to body.toString(),
                    "date" to timestamp,
                ),
            )
        }
    }
}
