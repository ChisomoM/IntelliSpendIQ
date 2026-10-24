package com.intellispendiq.app

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel

/**
 * Runs captured messages through the Dart pipeline while the app is not
 * running, by starting a headless Flutter engine for the length of one
 * broadcast.
 *
 * Parsing, the encrypted database and the categorizer all live in Dart
 * (README: parsing stays in Dart), so the receiver cannot do this alone.
 * Dart calls `ready` once its handler is registered; this side answers
 * by sending each payload as an `ingest` call, then tears the engine
 * down.
 *
 * Best effort by design. A broadcast receiver has only a few seconds, so
 * [TIMEOUT_MS] caps the wait. If anything fails or times out, nothing is
 * lost: the message stays in the SMS inbox and the launch-time backfill
 * ingests it (idempotently) on the next open.
 */
object BackgroundCapture {

    private const val TAG = "BackgroundCapture"
    private const val CHANNEL = "com.intellispendiq/capture_background"
    private const val LIBRARY = "package:intellispendiq/background/capture_background.dart"
    private const val ENTRYPOINT = "captureBackgroundMain"

    // Broadcast receivers get roughly ten seconds; leave headroom to
    // return before the system gives up on us.
    private const val TIMEOUT_MS = 8_000L

    /** Must be called on the main thread, which is where receivers run. */
    fun run(context: Context, payloads: List<Map<String, Any?>>, onDone: () -> Unit) {
        val app = context.applicationContext
        val handler = Handler(Looper.getMainLooper())
        var engine: FlutterEngine? = null
        var finished = false

        fun finish() {
            if (finished) return
            finished = true
            handler.removeCallbacksAndMessages(null)
            engine?.destroy()
            engine = null
            onDone()
        }

        try {
            val loader = FlutterInjector.instance().flutterLoader()
            loader.startInitialization(app)
            loader.ensureInitializationComplete(app, null)

            val created = FlutterEngine(app)
            engine = created
            handler.postDelayed({
                Log.w(TAG, "Timed out; the launch backfill will pick the message up")
                finish()
            }, TIMEOUT_MS)

            val channel = MethodChannel(created.dartExecutor.binaryMessenger, CHANNEL)
            channel.setMethodCallHandler { call, result ->
                if (call.method == "ready") {
                    result.success(null)
                    sendNext(channel, payloads.iterator(), ::finish)
                } else {
                    result.notImplemented()
                }
            }

            created.dartExecutor.executeDartEntrypoint(
                DartExecutor.DartEntrypoint(loader.findAppBundlePath(), LIBRARY, ENTRYPOINT),
            )
        } catch (error: Throwable) {
            Log.e(TAG, "Could not start the background engine", error)
            finish()
        }
    }

    private fun sendNext(
        channel: MethodChannel,
        remaining: Iterator<Map<String, Any?>>,
        finish: () -> Unit,
    ) {
        if (!remaining.hasNext()) {
            finish()
            return
        }
        channel.invokeMethod(
            "ingest",
            remaining.next(),
            object : MethodChannel.Result {
                override fun success(result: Any?) = sendNext(channel, remaining, finish)

                override fun error(code: String, message: String?, details: Any?) {
                    Log.w(TAG, "Dart reported $code: $message")
                    sendNext(channel, remaining, finish)
                }

                override fun notImplemented() = sendNext(channel, remaining, finish)
            },
        )
    }
}
