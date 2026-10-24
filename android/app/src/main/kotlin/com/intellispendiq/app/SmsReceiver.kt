package com.intellispendiq.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony

/**
 * Forwards incoming SMS to the Dart event sink while the app is running.
 *
 * When the app is not running this also starts a headless engine
 * ([BackgroundCapture]) so the message is processed immediately. Either
 * way it is a convenience path only: the launch-time inbox diff in
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

        val payloads = bodies.map { (address, body) ->
            mapOf(
                "channel" to "sms",
                "id" to null,
                "address" to address,
                "body" to body.toString(),
                "date" to timestamp,
            )
        }

        // Whether the app is running decides who handles the message.
        // Sampled before emitting, because emit() buffers when nobody is
        // listening and that must not look like a listener.
        val appIsRunning = CaptureEventStreamHandler.hasListener()
        for (payload in payloads) CaptureEventStreamHandler.emit(payload)

        // App closed: emit() only buffered the messages in memory, which
        // the process may not outlive. Run them through Dart now, in a
        // headless engine, so the transaction is saved and the user is
        // nudged while they still remember. Ingest is idempotent, so the
        // buffered copy, a later backfill, or both arriving too is harmless.
        val worthProcessing = payloads.filter {
            context != null && KnownSenders.isKnown(context, it["address"] as String)
        }
        if (!appIsRunning && context != null && worthProcessing.isNotEmpty()) {
            val pending = goAsync()
            BackgroundCapture.run(context, worthProcessing.map { "ingest" to it }) {
                pending.finish()
            }
        }
    }
}
