package com.litchi.client

import android.content.Context
import android.os.Build
import android.util.Log
import io.nekohasekai.libbox.CommandServer
import io.nekohasekai.libbox.CommandServerHandler
import io.nekohasekai.libbox.Libbox
import io.nekohasekai.libbox.OverrideOptions
import io.nekohasekai.libbox.SetupOptions
import io.nekohasekai.libbox.SystemProxyStatus

object AndroidSingBoxEngine : CommandServerHandler {
    private const val TAG = "LitchiSingBox"
    private lateinit var platform: AndroidSingBoxPlatform
    private var server: CommandServer? = null
    private var coreConfig = ""
    private var activeConfig = ""
    private var errorMessage = ""

    @Synchronized
    fun initialize(context: Context) {
        if (server != null) return
        val app = context.applicationContext
        val working = app.getExternalFilesDir(null) ?: app.filesDir
        Libbox.setup(SetupOptions().apply {
            basePath = app.filesDir.absolutePath
            workingPath = working.absolutePath
            tempPath = app.cacheDir.absolutePath
            fixAndroidStack = BuildConfig.DEBUG ||
                Build.VERSION.SDK_INT in Build.VERSION_CODES.N..Build.VERSION_CODES.N_MR1 ||
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.P
            commandServerListenPort = 0
            commandServerSecret = ""
            logMaxLines = 500
            debug = BuildConfig.DEBUG
        })
        platform = AndroidSingBoxPlatform(app)
        server = CommandServer(this, platform).also { it.start() }
    }

    fun isAvailable(): Boolean = runCatching { Libbox.version() }.isSuccess

    @Synchronized
    fun startCoreOnly(context: Context, config: String): Boolean = invoke("start core") {
        initialize(context)
        platform.attachVpn(null)
        server!!.startOrReloadService(config, OverrideOptions())
        coreConfig = config
        activeConfig = config
    }

    @Synchronized
    fun startVpn(context: Context, service: LitchiVpnService, config: String): Boolean =
        invoke("start VPN") {
            initialize(context)
            platform.attachVpn(service)
            server!!.startOrReloadService(config, OverrideOptions())
            activeConfig = config
        }

    @Synchronized
    fun stopVpn(): Boolean = invoke("stop VPN") {
        platform.attachVpn(null)
        if (coreConfig.isNotBlank()) {
            server?.startOrReloadService(coreConfig, OverrideOptions())
            activeConfig = coreConfig
        } else {
            server?.closeService()
            activeConfig = ""
        }
    }

    @Synchronized
    fun reloadConfig(config: String): Boolean = invoke("reload config") {
        server?.startOrReloadService(config, OverrideOptions())
            ?: error("sing-box command server is unavailable")
        activeConfig = config
        if (platformIsCoreOnly()) coreConfig = config
    }

    @Synchronized
    fun stop() {
        runCatching { server?.closeService() }
        runCatching { server?.close() }
        server = null
        coreConfig = ""
        activeConfig = ""
        errorMessage = ""
    }

    fun isRunning(): Boolean = server != null && activeConfig.isNotBlank()
    fun version(): String = runCatching { Libbox.version() }.getOrDefault("sing-box unavailable")
    fun lastError(): String = errorMessage.ifBlank { "sing-box core is not running" }

    private fun platformIsCoreOnly(): Boolean = !LitchiVpnService.isRunning

    private inline fun invoke(action: String, block: () -> Unit): Boolean = runCatching {
        block()
        errorMessage = ""
        true
    }.getOrElse {
        errorMessage = it.message ?: it.toString()
        Log.e(TAG, "$action failed", it)
        false
    }

    override fun serviceStop() = stop()
    override fun serviceReload() {
        if (activeConfig.isNotBlank()) reloadConfig(activeConfig)
    }
    override fun getSystemProxyStatus(): SystemProxyStatus = SystemProxyStatus().apply {
        available = false
        enabled = false
    }
    override fun setSystemProxyEnabled(enabled: Boolean) = Unit
    override fun writeDebugMessage(message: String) {
        Log.d(TAG, message)
    }
}
