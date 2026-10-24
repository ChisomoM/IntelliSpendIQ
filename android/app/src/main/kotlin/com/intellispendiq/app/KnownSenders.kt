package com.intellispendiq.app

import android.content.Context

/**
 * The sender IDs the parsers recognize, mirrored from Dart.
 *
 * The receiver sees every SMS the phone gets, and starting a Flutter
 * engine is not free. Checking the sender here first means a message
 * from a friend never wakes the pipeline. Dart owns the list (built-in
 * providers plus the user's custom senders) and publishes it whenever it
 * may have changed; this is only a cache of it.
 */
object KnownSenders {

    private const val PREFS = "intellispendiq_capture"
    private const val KEY = "known_senders"

    fun store(context: Context, senders: Collection<String>) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .putStringSet(KEY, senders.toSet())
            .apply()
    }

    /**
     * Same normalization as `Ids.normalizeSender` in Dart: strip `+`,
     * spaces and dashes, then lowercase.
     */
    private fun normalize(sender: String): String =
        sender.replace(Regex("[+\\s\\-]"), "").lowercase()

    /**
     * True when [address] is a known sender, or when the list has never
     * been published yet. Failing open matters: a first install that
     * receives an SMS before the app is opened must not drop it.
     */
    fun isKnown(context: Context, address: String): Boolean {
        val known = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getStringSet(KEY, null) ?: return true
        return normalize(address) in known
    }
}
