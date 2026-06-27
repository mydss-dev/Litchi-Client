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
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.net.VpnService
import android.os.Build

class LitchiVpnService : VpnService() {
    private var tunFd: Int = -1
    private var currentConfig: String = ""
    private var stopReceiverRegistered: Boolean = false
    private var networkCallbackRegistered: Boolean = false
    private val underlyingNetworks = linkedSetOf<Network>()
    private val connectivityManager: ConnectivityManager?
        get() = getSystemService(ConnectivityManager::class.java)
    private val stopReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == ACTION_STOP) stopCore()
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
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                AndroidCoreStatus.emit(layer = "vpn", status = "stopping")
                stopCore()
                return START_NOT_STICKY
            }

            ACTION_START -> {
                val config = intent.getStringExtra(EXTRA_CONFIG).orEmpty()
                if (config.isBlank()) {
                    AndroidCoreStatus.emit(layer = "vpn", status = "error", "Android core config is empty")
                    stopCore(emitStopped = false)
                    return START_NOT_STICKY
                }
                if (isRunning && currentConfig == config) {
                    registerStopReceiver()
                    startCoreForeground("Litchi connected")
                    AndroidCoreStatus.emit(layer = "vpn", status = "running")
                    return START_NOT_STICKY
                }
                currentConfig = config
                registerStopReceiver()
                registerNetworkCallback()
                startCoreForeground("Litchi connecting")
                AndroidCoreStatus.emit(layer = "vpn", status = "starting")
                val fd = openTun()
                val ok = AndroidMihomoEngine.start(config, this, fd)
                if (!ok) {
                    tunFd = -1
                    AndroidCoreStatus.emit(layer = "vpn", status = "error", AndroidMihomoEngine.lastError())
                    stopCore(emitStopped = false)
                    return START_NOT_STICKY
                }
                isRunning = true
                startCoreForeground("Litchi connected")
                AndroidCoreStatus.emit(layer = "vpn", status = "running")
                return START_NOT_STICKY
            }
        }
        stopSelf()
        return START_NOT_STICKY
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        stopCore()
        super.onTaskRemoved(rootIntent)
    }

    override fun onDestroy() {
        stopCore()
        super.onDestroy()
    }

    private fun stopCore(emitStopped: Boolean = true) {
        unregisterNetworkCallback()
        unregisterStopReceiver()
        AndroidMihomoEngine.stopVpn()
        tunFd = -1
        runCatching { setUnderlyingNetworks(null) }
        currentConfig = ""
        isRunning = false
        if (emitStopped) AndroidCoreStatus.emit(layer = "vpn", status = "stopped")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
        stopSelf()
    }

    private fun openTun(): Int {
        if (tunFd >= 0) return tunFd
        val builder = Builder()
            .setSession("Litchi")
            .setMtu(DEFAULT_MTU)
            .addAddress("172.19.0.1", 30)
            .addDnsServer("172.19.0.2")
            .addRoute("0.0.0.0", 0)
            .addAddress("fdfe:dcba:9876::1", 126)
            .addDnsServer("fdfe:dcba:9876::2")
            .addRoute("::", 0)
            .setBlocking(false)

        tunFd = builder.establish()?.detachFd() ?: -1
        updateUnderlyingNetworks()
        return tunFd
    }

    private fun buildNotification(text: String): Notification {
        ensureNotificationChannel()
        val stopIntent = PendingIntent.getBroadcast(
            this,
            0,
            Intent(ACTION_STOP).setPackage(packageName),
            PendingIntent.FLAG_UPDATE_CURRENT or immutableFlag()
        )
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
                .setSmallIcon(R.mipmap.ic_launcher)
                .setContentTitle("Litchi")
                .setContentText(text)
                .setOngoing(true)
                .addAction(android.R.drawable.ic_menu_close_clear_cancel, "Disconnect", stopIntent)
                .build()
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
                .setSmallIcon(R.mipmap.ic_launcher)
                .setContentTitle("Litchi")
                .setContentText(text)
                .setOngoing(true)
                .addAction(android.R.drawable.ic_menu_close_clear_cancel, "Disconnect", stopIntent)
                .build()
        }
    }

    private fun startCoreForeground(text: String) {
        val notification = buildNotification(text)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
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
            "Litchi Core",
            NotificationManager.IMPORTANCE_LOW
        )
        manager.createNotificationChannel(channel)
    }

    private fun registerStopReceiver() {
        if (stopReceiverRegistered) return
        runCatching {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                registerReceiver(
                    stopReceiver,
                    IntentFilter(ACTION_STOP),
                    Context.RECEIVER_NOT_EXPORTED
                )
            } else {
                @Suppress("DEPRECATION")
                registerReceiver(stopReceiver, IntentFilter(ACTION_STOP))
            }
        }.onSuccess { stopReceiverRegistered = true }
    }

    private fun unregisterStopReceiver() {
        if (!stopReceiverRegistered) return
        stopReceiverRegistered = false
        runCatching { unregisterReceiver(stopReceiver) }
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
        val networks = synchronized(underlyingNetworks) {
            underlyingNetworks.toTypedArray().takeIf { it.isNotEmpty() }
        }
        runCatching { setUnderlyingNetworks(networks) }
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
