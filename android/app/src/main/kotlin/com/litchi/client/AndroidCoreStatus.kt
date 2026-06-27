package com.litchi.client

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel

object AndroidCoreStatus {
    private val mainHandler = Handler(Looper.getMainLooper())
    private var sink: EventChannel.EventSink? = null
    private var lastStatus: Map<String, Any?> = mapOf(
        "status" to "stopped",
        "layer" to "core",
        "error" to ""
    )

    fun setEventSink(eventSink: EventChannel.EventSink?) {
        sink = eventSink
        eventSink?.success(lastStatus)
    }

    fun emit(status: String, layer: String, error: String = "") {
        val payload = mapOf(
            "status" to status,
            "layer" to layer,
            "error" to error
        )
        lastStatus = payload
        mainHandler.post {
            sink?.success(payload)
        }
    }
}
