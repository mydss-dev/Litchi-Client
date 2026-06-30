package com.litchi.client

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.ServiceInfo
import android.net.ConnectivityManager
import android.net.LinkProperties
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.net.VpnService
import android.os.Build
import android.os.PowerManager

class LitchiVpnService : VpnService() {
    private var tunFd: Int = -1
    private var currentConfig: String = ""
    private var networkCallbackRegistered: Boolean = false
    private var powerReceiverRegistered: Boolean = false
    private var stopHandled: Boolean = false
    private val underlyingNetworks = linkedSetOf<Network>()
    private val connectivityManager: ConnectivityManager?
        get() = getSystemService(ConnectivityManager::class.java)
    private val powerReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            updateSuspendState()
        }
    }
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
                stopHandled = false
                if (isRunning) {
                    startCoreForeground("${getString(R.string.app_name)} connected")
                    AndroidCoreStatus.emit("running", "vpn")
                    return START_NOT_STICKY
                }
                registerNetworkCallback()
                registerPowerReceiver()
                startCoreForeground("${getString(R.string.app_name)} connecting")
                AndroidCoreStatus.emit("starting", "vpn")
                val fd = openTun()
                // Attach TUN to already-running core — does NOT restart the core.
                val ok = AndroidMihomoEngine.startVpn(this, fd)
                if (!ok) {
                    tunFd = -1
                    AndroidCoreStatus.emit("error", "vpn", AndroidMihomoEngine.lastError())
                    stopVpnLayer(emitStopped = false)
                    return START_NOT_STICKY
                }
                isRunning = true
                updateSuspendState()
                startCoreForeground("${getString(R.string.app_name)} connected")
                AndroidCoreStatus.emit("running", "vpn")
                return START_NOT_STICKY
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
        unregisterPowerReceiver()
        AndroidMihomoEngine.setSuspended(false)
        // The detached TUN descriptor is consumed by the native sing-tun
        // listener. AndroidMihomoEngine also closes it when native startup
        // fails, so Kotlin must never adopt/close the same descriptor again.
        AndroidMihomoEngine.stopVpn()
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
        AndroidMihomoEngine.stop()
        if (emitStopped) AndroidCoreStatus.emit("stopped", "core")
    }

    private fun openTun(): Int {
        if (tunFd >= 0) return tunFd
        val builder = Builder()
            .setSession(getString(R.string.app_name))
            .setMtu(DEFAULT_MTU)
            .addAddress("172.19.0.1", 30)
            .addDnsServer("172.19.0.2")
            .addRoute("0.0.0.0", 0)
            .addAddress("fdfe:dcba:9876::1", 126)
            .addDnsServer("fdfe:dcba:9876::2")
            .addRoute("::", 0)
            .setBlocking(false)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            builder.setMetered(false)
        }
        tunFd = builder.establish()?.detachFd() ?: -1
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
                .setSmallIcon(R.mipmap.ic_launcher)
                .setContentTitle(getString(R.string.app_name))
                .setContentText(text)
                .setContentIntent(contentIntent)
                .setOngoing(true)
                .addAction(android.R.drawable.ic_menu_close_clear_cancel, "Disconnect", stopIntent)
                .build()
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
                .setSmallIcon(R.mipmap.ic_launcher)
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
                AndroidMihomoEngine.preferredNetwork(it, underlyingNetworks)
            }
        }
        runCatching { setUnderlyingNetworks(network?.let { arrayOf(it) }) }
        AndroidMihomoEngine.updateDns(this)
    }

    private fun updateSuspendState() {
        val power = getSystemService(PowerManager::class.java)
        val suspended = !power.isInteractive && power.isDeviceIdleMode
        AndroidMihomoEngine.setSuspended(suspended)
    }

    private fun registerPowerReceiver() {
        if (powerReceiverRegistered) return
        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_SCREEN_ON)
            addAction(Intent.ACTION_SCREEN_OFF)
            addAction(PowerManager.ACTION_DEVICE_IDLE_MODE_CHANGED)
        }
        runCatching {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                registerReceiver(powerReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
            } else {
                @Suppress("DEPRECATION")
                registerReceiver(powerReceiver, filter)
            }
        }.onSuccess {
            powerReceiverRegistered = true
            updateSuspendState()
        }
    }

    private fun unregisterPowerReceiver() {
        if (!powerReceiverRegistered) return
        powerReceiverRegistered = false
        runCatching { unregisterReceiver(powerReceiver) }
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
        private const val DEFAULT_MTU = 1500

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
