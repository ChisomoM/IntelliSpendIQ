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
 * broadcast, or for a tap on the floating card ([NudgeOverlay]).
 *
 * Parsing, the encrypted database and the categorizer all live in Dart
 * (README: parsing stays in Dart), so the receiver cannot do this alone.
 * Dart calls `ready` once its handler is registered; this side answers
 * by sending each queued call (`ingest` for a message, `categorize` for
 * a tap on the floating card), then tears the engine down. Dart can also
 * call `showOverlay` back while it runs.
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

    /**
     * Runs each of [calls] (a Dart method name and its arguments) in order,
     * then calls [onDone] with whatever Dart answered to each. The list is
     * shorter than [calls] if the run timed out or failed part way.
     *
     * Must be called on the main thread, which is where receivers run.
     */
    fun run(
        context: Context,
        calls: List<Pair<String, Map<String, Any?>>>,
        onDone: (List<Any?>) -> Unit,
    ) {
        val app = context.applicationContext
        val handler = Handler(Looper.getMainLooper())
        var engine: FlutterEngine? = null
        var finished = false
        val results = mutableListOf<Any?>()

        fun finish() {
            if (finished) return
            finished = true
            handler.removeCallbacksAndMessages(null)
            engine?.destroy()
            engine = null
            onDone(results)
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
                when (call.method) {
                    "ready" -> {
                        result.success(null)
                        sendNext(channel, calls.iterator(), results, ::finish)
                    }

                    // Dart asks for the floating card; it is drawn here so it
                    // outlives this engine.
                    "showOverlay" -> result.success(
                        NudgeOverlay.show(app, call.arguments as? Map<*, *> ?: emptyMap<Any, Any>()),
                    )

                    else -> result.notImplemented()
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
        remaining: Iterator<Pair<String, Map<String, Any?>>>,
        results: MutableList<Any?>,
        finish: () -> Unit,
    ) {
        if (!remaining.hasNext()) {
            finish()
            return
        }
        val (method, arguments) = remaining.next()
        fun next(answer: Any?) {
            results.add(answer)
            sendNext(channel, remaining, results, finish)
        }
        channel.invokeMethod(
            method,
            arguments,
            object : MethodChannel.Result {
                override fun success(result: Any?) = next(result)

                override fun error(code: String, message: String?, details: Any?) {
                    Log.w(TAG, "Dart reported $code: $message")
                    next("error")
                }

                override fun notImplemented() = next("notImplemented")
            },
        )
    }
}
