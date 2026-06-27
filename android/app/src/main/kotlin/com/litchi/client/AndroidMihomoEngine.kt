package com.litchi.client

import android.util.Log

object AndroidMihomoEngine {
    private const val TAG = "LitchiMihomo"
    private var lastError = ""
    private val loaded = runCatching {
        System.loadLibrary("litchi_core")
    }.onFailure {
        lastError = it.message ?: "mihomo Android library could not be loaded"
        Log.e(TAG, "load failed", it)
    }.isSuccess

    private external fun nativeStart(
        config: String,
        home: String,
        tunFd: Int,
        service: LitchiVpnService,
    ): String

    private external fun nativeStop()
    private external fun nativeVersion(): String

    fun isAvailable(): Boolean = loaded

    fun start(config: String, service: LitchiVpnService, tunFd: Int): Boolean {
        if (!loaded) return false
        if (tunFd < 0) {
            lastError = "Android VPN interface could not be created"
            return false
        }
        return runCatching {
            val error = nativeStart(config, service.filesDir.absolutePath, tunFd, service)
            lastError = error
            error.isBlank()
        }.getOrElse {
            lastError = it.message ?: it.toString()
            Log.e(TAG, "start failed", it)
            false
        }
    }

    fun stop() {
        if (loaded) runCatching { nativeStop() }
    }

    fun version(): String {
        if (!loaded) return "mihomo Android library unavailable"
        return runCatching { nativeVersion() }.getOrDefault("mihomo")
    }

    fun lastError(): String = lastError.ifBlank { "mihomo core is not running" }
}
