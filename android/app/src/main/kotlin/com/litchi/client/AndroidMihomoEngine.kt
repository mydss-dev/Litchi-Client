package com.litchi.client

import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.os.Build
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

    private external fun nativeStartCoreOnly(
        config: String,
        home: String,
    ): String

    private external fun nativeStartVpn(
        tunFd: Int,
        service: LitchiVpnService,
    ): String

    private external fun nativeStopVpn()
    private external fun nativeStop()
    private external fun nativeUpdateDns(servers: String)
    private external fun nativeSetSuspended(suspended: Boolean)
    private external fun nativeCloseConnections()
    private external fun nativeSwitchProxy(group: String, proxy: String): String
    private external fun nativeSetMode(mode: String): String
    private external fun nativeReloadConfig(config: String): String
    private external fun nativeVersion(): String

    fun isAvailable(): Boolean = loaded

    fun startVpn(service: LitchiVpnService, tunFd: Int): Boolean {
        if (tunFd < 0) {
            lastError = "Android VPN interface could not be created"
            return false
        }
        if (!loaded) {
            lastError = lastError.ifBlank { "mihomo Android library could not be loaded" }
            return false
        }

        val ok = runCatching {
            val error = nativeStartVpn(tunFd, service)
            lastError = error
            error.isBlank()
        }.getOrElse {
            lastError = it.message ?: it.toString()
            Log.e(TAG, "startVpn failed", it)
            false
        }

        if (!ok) closeDetachedFd(tunFd)
        return ok
    }

    fun stopVpn() {
        if (loaded) runCatching { nativeStopVpn() }
    }

    fun startCoreOnly(config: String, home: String): Boolean {
        if (!loaded) {
            lastError = lastError.ifBlank { "mihomo Android library could not be loaded" }
            return false
        }

        val ok = runCatching {
            val error = nativeStartCoreOnly(config, home)
            lastError = error
            error.isBlank()
        }.getOrElse {
            lastError = it.message ?: it.toString()
            Log.e(TAG, "startCoreOnly failed", it)
            false
        }

        return ok
    }

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

    fun updateDns(context: Context) {
        if (!loaded) return
        val manager = context.getSystemService(ConnectivityManager::class.java)
        val network = preferredNetwork(manager)
        val servers = network
            ?.let(manager::getLinkProperties)
            ?.dnsServers
            ?.asSequence()
            .orEmpty()
            .mapNotNull { address ->
                address.hostAddress?.let { host ->
                    if (host.contains(':')) "[$host]:53" else "$host:53"
                }
            }
            .distinct()
            .toList()

        runCatching { nativeUpdateDns(servers.joinToString(",")) }
            .onFailure { Log.w(TAG, "update system DNS failed", it) }
    }

    fun preferredNetwork(
        manager: ConnectivityManager,
        candidates: Collection<Network> = manager.allNetworks.asList(),
    ): Network? {
        return candidates
            .asSequence()
            .mapNotNull { network ->
                val capabilities = manager.getNetworkCapabilities(network)
                    ?: return@mapNotNull null
                if (!capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) ||
                    !capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_NOT_VPN)
                ) {
                    return@mapNotNull null
                }
                network to networkScore(capabilities)
            }
            .minByOrNull { it.second }
            ?.first
    }

    private fun networkScore(capabilities: NetworkCapabilities): Int {
        val validationPenalty =
            if (capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED)) 0 else 100
        val transportScore = when {
            capabilities.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) -> 0
            capabilities.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) -> 1
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
                capabilities.hasTransport(NetworkCapabilities.TRANSPORT_USB) -> 2
            capabilities.hasTransport(NetworkCapabilities.TRANSPORT_BLUETOOTH) -> 3
            capabilities.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) -> 4
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.VANILLA_ICE_CREAM &&
                capabilities.hasTransport(NetworkCapabilities.TRANSPORT_SATELLITE) -> 5
            else -> 20
        }
        return validationPenalty + transportScore
    }

    fun setSuspended(suspended: Boolean) {
        if (!loaded) return
        runCatching { nativeSetSuspended(suspended) }
            .onFailure { Log.w(TAG, "update suspend state failed", it) }
    }

    fun closeConnections(): Boolean {
        if (!loaded) return false
        return runCatching {
            nativeCloseConnections()
            true
        }.getOrElse {
            lastError = it.message ?: it.toString()
            Log.e(TAG, "close connections failed", it)
            false
        }
    }

    fun switchProxy(group: String, proxy: String): Boolean {
        if (!loaded) return false
        return runCatching {
            val error = nativeSwitchProxy(group, proxy)
            lastError = error
            error.isBlank()
        }.getOrElse {
            lastError = it.message ?: it.toString()
            Log.e(TAG, "switch proxy failed", it)
            false
        }
    }

    fun setMode(mode: String): Boolean = invokeCoreAction("set mode") {
        nativeSetMode(mode)
    }

    fun reloadConfig(config: String): Boolean = invokeCoreAction("reload config") {
        nativeReloadConfig(config)
    }

    private inline fun invokeCoreAction(
        action: String,
        invoke: () -> String,
    ): Boolean {
        if (!loaded) return false
        return runCatching {
            val error = invoke()
            lastError = error
            error.isBlank()
        }.getOrElse {
            lastError = it.message ?: it.toString()
            Log.e(TAG, "$action failed", it)
            false
        }
    }

    fun version(): String {
        if (!loaded) return "mihomo Android library unavailable"
        return runCatching { nativeVersion() }.getOrDefault("mihomo")
    }

    fun lastError(): String = lastError.ifBlank { "mihomo core is not running" }
}
