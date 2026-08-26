package com.litchi.client

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.net.ConnectivityManager
import android.net.LinkProperties
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.net.VpnService
import android.os.Build
import io.nekohasekai.libbox.TunOptions

class LitchiVpnService : VpnService() {
    private var tunFd: Int = -1
    private var currentConfig: String = ""
    private var networkCallbackRegistered: Boolean = false
    private var stopHandled: Boolean = false
    private val underlyingNetworks = linkedSetOf<Network>()
    private val connectivityManager: ConnectivityManager?
        get() = getSystemService(ConnectivityManager::class.java)
    private val networkCallback = object : ConnectivityManager.NetworkCallback() {
        override fun onAvailable(network: Network) {
            synchronized(underlyingNetworks) {
                underlyingNetworks.add(network)
            }
            updateUnderlyingNetworks()
        }

        override fun onLost(network: Network) {
            synchronized(underlyingNetworks) {
                underlyingNetworks.remove(network)
            }
            updateUnderlyingNetworks()
        }

        override fun onCapabilitiesChanged(
            network: Network,
            networkCapabilities: NetworkCapabilities
        ) {
            if (!networkCapabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) ||
                !networkCapabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_NOT_VPN)
            ) {
                synchronized(underlyingNetworks) {
                    underlyingNetworks.remove(network)
                }
            } else {
                synchronized(underlyingNetworks) {
                    underlyingNetworks.add(network)
                }
            }
            updateUnderlyingNetworks()
        }

        override fun onLinkPropertiesChanged(
            network: Network,
            linkProperties: LinkProperties
        ) {
            updateUnderlyingNetworks()
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                AndroidCoreStatus.emit("stopping", "vpn")
                stopVpnLayer()
                return START_NOT_STICKY
            }

            ACTION_STOP_ALL -> {
                AndroidCoreStatus.emit("stopping", "vpn")
                LitchiCoreService.stop(this)
                stopVpnLayer()
                return START_NOT_STICKY
            }

            ACTION_START -> {
                val config = intent.getStringExtra(EXTRA_CONFIG).orEmpty()
                if (config.isBlank()) {
                    AndroidCoreStatus.emit("error", "vpn", "sing-box config is empty")
                    stopSelf()
                    return START_NOT_STICKY
                }
                stopHandled = false
                if (isRunning) {
                    startCoreForeground("${getString(R.string.app_name)} connected")
                    AndroidCoreStatus.emit("running", "vpn")
                    return START_REDELIVER_INTENT
                }
                registerNetworkCallback()
                startCoreForeground("${getString(R.string.app_name)} connecting")
                AndroidCoreStatus.emit("starting", "vpn")
                // Attach TUN to already-running core — does NOT restart the core.
                val ok = AndroidSingBoxEngine.startVpn(this, this, config)
                if (!ok) {
                    tunFd = -1
                    AndroidCoreStatus.emit("error", "vpn", AndroidSingBoxEngine.lastError())
                    stopVpnLayer(emitStopped = false)
                    return START_NOT_STICKY
                }
                isRunning = true
                startCoreForeground("${getString(R.string.app_name)} connected")
                AndroidCoreStatus.emit("running", "vpn")
                return START_REDELIVER_INTENT
            }
        }
        stopSelf()
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        stopVpnLayer(emitStopped = isRunning)
        super.onDestroy()
    }

    override fun onRevoke() {
        AndroidCoreStatus.emit("stopping", "vpn")
        stopVpnLayer()
        super.onRevoke()
    }

    /// Tears down only the VPN layer.  Calls native stopVpn so the Go TUN
    /// listener and socket protection are cleaned up; the core listeners
    /// (mixed/http/socks) stay alive.
    private fun stopVpnLayer(emitStopped: Boolean = true) {
        if (stopHandled) return
        stopHandled = true
        unregisterNetworkCallback()
        // libbox owns the detached descriptor after OpenTun returns it.
        AndroidSingBoxEngine.stopVpn()
        tunFd = -1
        runCatching { setUnderlyingNetworks(null) }
        currentConfig = ""
        isRunning = false
        if (emitStopped) AndroidCoreStatus.emit("stopped", "vpn")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
        stopSelf()
    }

    /// Full shutdown — also stops the native core.
    private fun stopCore(emitStopped: Boolean = true) {
        stopVpnLayer(emitStopped = false)
        AndroidSingBoxEngine.stop()
        if (emitStopped) AndroidCoreStatus.emit("stopped", "core")
    }

    internal fun openTunForSingBox(options: TunOptions): Int {
        if (tunFd >= 0) return tunFd
        val builder = Builder()
            .setSession(getString(R.string.app_name))
            .setMtu(options.mtu)

        val inet4 = options.inet4Address
        var hasInet4 = false
        while (inet4.hasNext()) {
            val prefix = inet4.next()
            builder.addAddress(prefix.address(), prefix.prefix())
            hasInet4 = true
        }
        val inet6 = options.inet6Address
        var hasInet6 = false
        while (inet6.hasNext()) {
            val prefix = inet6.next()
            builder.addAddress(prefix.address(), prefix.prefix())
            hasInet6 = true
        }
        if (options.autoRoute) {
            if (hasInet4) builder.addRoute("0.0.0.0", 0)
            if (hasInet6) builder.addRoute("::", 0)
        }
        runCatching { options.dnsServerAddress.value }
            .getOrNull()
            ?.takeIf(String::isNotBlank)
            ?.let(builder::addDnsServer)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) builder.setMetered(false)
        tunFd = builder.establish()?.detachFd() ?: -1
        if (tunFd < 0) error("android: failed to establish VPN interface")
        updateUnderlyingNetworks()
        return tunFd
    }

    private fun buildNotification(text: String): Notification {
        ensureNotificationChannel()
        val contentIntent = PendingIntent.getActivity(
            this,
            NOTIFICATION_ID,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val stopIntent = PendingIntent.getService(
            this,
            0,
            Intent(this, LitchiVpnService::class.java).apply {
                action = ACTION_STOP_ALL
            },
            PendingIntent.FLAG_UPDATE_CURRENT or immutableFlag()
        )
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
                .setSmallIcon(R.mipmap.launcher_icon)
                .setContentTitle(getString(R.string.app_name))
                .setContentText(text)
                .setContentIntent(contentIntent)
                .setOngoing(true)
                .addAction(android.R.drawable.ic_menu_close_clear_cancel, "Disconnect", stopIntent)
                .build()
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
                .setSmallIcon(R.mipmap.launcher_icon)
                .setContentTitle(getString(R.string.app_name))
                .setContentText(text)
                .setContentIntent(contentIntent)
                .setOngoing(true)
                .addAction(android.R.drawable.ic_menu_close_clear_cancel, "Disconnect", stopIntent)
                .build()
        }
    }

    private fun startCoreForeground(text: String) {
        val notification = buildNotification(text)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun ensureNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java)
        val channel = NotificationChannel(
            CHANNEL_ID,
            "${getString(R.string.app_name)} Core",
            NotificationManager.IMPORTANCE_LOW
        )
        manager.createNotificationChannel(channel)
    }

    private fun registerNetworkCallback() {
        if (networkCallbackRegistered) return
        val manager = connectivityManager ?: return
        val request = NetworkRequest.Builder()
            .addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
            .addCapability(NetworkCapabilities.NET_CAPABILITY_NOT_VPN)
            .build()
        runCatching {
            manager.registerNetworkCallback(request, networkCallback)
            synchronized(underlyingNetworks) {
                underlyingNetworks.clear()
                manager.allNetworks.forEach { network ->
                    val capabilities = manager.getNetworkCapabilities(network)
                    if (capabilities != null &&
                        capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) &&
                        capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_NOT_VPN)
                    ) {
                        underlyingNetworks.add(network)
                    }
                }
            }
            updateUnderlyingNetworks()
        }.onSuccess {
            networkCallbackRegistered = true
        }
    }

    private fun unregisterNetworkCallback() {
        if (!networkCallbackRegistered) return
        networkCallbackRegistered = false
        runCatching { connectivityManager?.unregisterNetworkCallback(networkCallback) }
        synchronized(underlyingNetworks) {
            underlyingNetworks.clear()
        }
    }

    private fun updateUnderlyingNetworks() {
        if (tunFd < 0) return
        val manager = connectivityManager
        val network = synchronized(underlyingNetworks) {
            manager?.let {
                underlyingNetworks.firstOrNull { candidate ->
                    it.getNetworkCapabilities(candidate)?.run {
                        hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) &&
                            hasCapability(NetworkCapabilities.NET_CAPABILITY_NOT_VPN)
                    } == true
                }
            }
        }
        runCatching { setUnderlyingNetworks(network?.let { arrayOf(it) }) }
    }


    private fun immutableFlag(): Int {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_IMMUTABLE
        } else {
            0
        }
    }

    companion object {
        private const val ACTION_START = "com.litchi.client.START_VPN"
        private const val ACTION_STOP = "com.litchi.client.STOP_VPN"
        private const val ACTION_STOP_ALL = "com.litchi.client.STOP_ALL"
        private const val EXTRA_CONFIG = "config"
        private const val CHANNEL_ID = "litchi_core"
        private const val NOTIFICATION_ID = 1001

        @Volatile
        var isRunning: Boolean = false
            private set

        fun start(context: Context, config: String): Boolean {
            val intent = Intent(context, LitchiVpnService::class.java).apply {
                action = ACTION_START
                putExtra(EXTRA_CONFIG, config)
            }
            return runCatching {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(intent)
                } else {
                    context.startService(intent)
                }
                true
            }.getOrDefault(false)
        }

        fun stop(context: Context): Boolean {
            val intent = Intent(context, LitchiVpnService::class.java).apply {
                action = ACTION_STOP
            }
            return runCatching {
                context.startService(intent)
                true
            }.getOrDefault(false)
        }
    }
}
