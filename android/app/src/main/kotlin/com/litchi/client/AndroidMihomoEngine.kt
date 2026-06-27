package com.litchi.client

import android.os.ParcelFileDescriptor
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
        if (tunFd < 0) {
            lastError = "Android VPN interface could not be created"
            return false
        }

        if (!loaded) {
            lastError = lastError.ifBlank { "mihomo Android library could not be loaded" }
            closeDetachedFd(tunFd)
            return false
        }

        val ok = runCatching {
            val error = nativeStart(config, service.filesDir.absolutePath, tunFd, service)
            lastError = error
            error.isBlank()
        }.getOrElse {
            lastError = it.message ?: it.toString()
            Log.e(TAG, "start failed", it)
            false
        }

        if (!ok) {
            closeDetachedFd(tunFd)
        }

        return ok
    }

    private fun closeDetachedFd(fd: Int) {
        if (fd < 0) return
        runCatching {
            ParcelFileDescriptor.adoptFd(fd).close()
        }.onFailure {
            Log.w(TAG, "close detached tun fd failed", it)
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
