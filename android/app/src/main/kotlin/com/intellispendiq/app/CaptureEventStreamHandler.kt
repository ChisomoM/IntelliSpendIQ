package com.intellispendiq.app

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel

/**
 * Bridges capture events (incoming SMS, notifications) to Dart.
 *
 * Events are buffered while no Dart listener is attached, so an alert
 * that arrives during startup is delivered rather than dropped — the
 * data-trust requirement applies to the transport too.
 */
object CaptureEventStreamHandler : EventChannel.StreamHandler {

    private const val MAX_BUFFERED_EVENTS = 100

    private val mainHandler = Handler(Looper.getMainLooper())
    private val pending = ArrayDeque<Map<String, Any?>>()
    private var sink: EventChannel.EventSink? = null

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        synchronized(this) {
            sink = events
            while (pending.isNotEmpty()) {
                val event = pending.removeFirst()
                mainHandler.post { sink?.success(event) }
            }
        }
    }

    override fun onCancel(arguments: Any?) {
        synchronized(this) { sink = null }
    }

    fun emit(event: Map<String, Any?>) {
        synchronized(this) {
            val target = sink
            if (target == null) {
                if (pending.size >= MAX_BUFFERED_EVENTS) pending.removeFirst()
                pending.addLast(event)
            } else {
                mainHandler.post { target.success(event) }
            }
        }
    }
}
