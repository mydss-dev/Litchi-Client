package com.litchi.client

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.net.ConnectivityManager
import android.net.LinkProperties
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.os.Build
import org.json.JSONObject

/**
 * Non-VPN foreground service that runs the mihomo core without TUN.
 *
 * The core is always loaded on Android so that latency tests, node switching,
 * and mode changes work instantly without a VPN permission prompt.  When the
 * user taps "connect" the VPN layer ([LitchiVpnService]) attaches on top of
 * the already-running core.
 */
class LitchiCoreService : Service() {
    private var networkCallbackRegistered = false
    private var stopHandled = false
    private val networkCallback = object : ConnectivityManager.NetworkCallback() {
        override fun onAvailable(network: Network) = updateSystemDns()

        override fun onLost(network: Network) = updateSystemDns()

        override fun onCapabilitiesChanged(
            network: Network,
            networkCapabilities: NetworkCapabilities
        ) = updateSystemDns()

        override fun onLinkPropertiesChanged(
            network: Network,
            linkProperties: LinkProperties
        ) = updateSystemDns()
    }

    override fun onBind(intent: Intent?) = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                AndroidCoreStatus.emit("stopping", "core")
                stopCore()
                return START_NOT_STICKY
            }

            ACTION_START -> {
                stopHandled = false
                val config = intent.getStringExtra(EXTRA_CONFIG).orEmpty()
                if (config.isBlank()) {
                    AndroidCoreStatus.emit("error", "core", "Android core config is empty")
                    stopCore(emitStopped = false)
                    return START_NOT_STICKY
                }
                if (isRunning && currentConfig == config) {
                    startCoreForeground()
                    AndroidCoreStatus.emit("running", "core")
                    return START_NOT_STICKY
                }
                currentConfig = config
                controllerPort = readControllerPort(config)
                controllerSecret = readControllerSecret(config)
                registerNetworkCallback()
                startCoreForeground()
                AndroidCoreStatus.emit("starting", "core")
                updateSystemDns()
                // Copy bundled geo databases into the core home dir (filesDir)
                // before the core parses the config, so GEOIP/GEOSITE rules
                // resolve without an at-startup download (which fails behind a
                // firewall and would stop the core from starting).
                GeoAssets.stage(this)
                val ok = AndroidMihomoEngine.startCoreOnly(config, filesDir.absolutePath)
                if (!ok) {
                    AndroidCoreStatus.emit("error", "core", AndroidMihomoEngine.lastError())
                    stopCore(emitStopped = false)
                    return START_NOT_STICKY
                }
                isRunning = true
                startCoreForeground()
                AndroidCoreStatus.emit("running", "core")
                return START_NOT_STICKY
            }
        }
        stopSelf()
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        unregisterNetworkCallback()
        stopCore()
        super.onDestroy()
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        if (!LitchiVpnService.isRunning) {
            stopCore(emitStopped = false)
        }
        super.onTaskRemoved(rootIntent)
    }

    private fun stopCore(emitStopped: Boolean = true) {
        if (stopHandled) return
        stopHandled = true
        unregisterNetworkCallback()
        AndroidMihomoEngine.stop()
        currentConfig = ""
        controllerPort = DEFAULT_CONTROLLER_PORT
        controllerSecret = ""
        isRunning = false
        if (emitStopped) AndroidCoreStatus.emit("stopped", "core")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
        stopSelf()
    }

    private fun updateSystemDns() {
        AndroidMihomoEngine.updateDns(this)
    }

    private fun registerNetworkCallback() {
        if (networkCallbackRegistered) return
        val manager = getSystemService(ConnectivityManager::class.java)
        val request = NetworkRequest.Builder()
            .addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
            .addCapability(NetworkCapabilities.NET_CAPABILITY_NOT_VPN)
            .build()
        runCatching {
            manager.registerNetworkCallback(request, networkCallback)
        }.onSuccess {
            networkCallbackRegistered = true
        }
    }

    private fun unregisterNetworkCallback() {
        if (!networkCallbackRegistered) return
        networkCallbackRegistered = false
        runCatching {
            getSystemService(ConnectivityManager::class.java)
                .unregisterNetworkCallback(networkCallback)
        }
    }

    private fun startCoreForeground() {
        val notification = buildNotification()
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

    private fun buildNotification(): Notification {
        ensureNotificationChannel()
        val text = if (LitchiVpnService.isRunning) "Litchi VPN connected"
            else "Litchi core ready"
        val contentIntent = PendingIntent.getActivity(
            this,
            NOTIFICATION_ID,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
                .setSmallIcon(R.mipmap.ic_launcher)
                .setContentTitle("Litchi")
                .setContentText(text)
                .setContentIntent(contentIntent)
                .setOngoing(true)
                .build()
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
                .setSmallIcon(R.mipmap.ic_launcher)
                .setContentTitle("Litchi")
                .setContentText(text)
                .setContentIntent(contentIntent)
                .setOngoing(true)
                .build()
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

    companion object {
        private const val ACTION_START = "com.litchi.client.START_CORE"
        private const val ACTION_STOP = "com.litchi.client.STOP_CORE"
        private const val EXTRA_CONFIG = "config"
        private const val CHANNEL_ID = "litchi_core_daemon"
        private const val NOTIFICATION_ID = 1000

        @Volatile
        var isRunning: Boolean = false
            private set

        @Volatile
        var controllerPort: Int = DEFAULT_CONTROLLER_PORT
            private set

        @Volatile
        var controllerSecret: String = ""
            private set

        private var currentConfig: String = ""
        private const val DEFAULT_CONTROLLER_PORT = 9090

        private fun readControllerPort(config: String): Int {
            return runCatching {
                val address = JSONObject(config)
                    .optString("external-controller", "")
                address.substringAfterLast(':').toIntOrNull()
                    ?.takeIf { it in 1..65535 }
                    ?: DEFAULT_CONTROLLER_PORT
            }.getOrDefault(DEFAULT_CONTROLLER_PORT)
        }

        private fun readControllerSecret(config: String): String {
            return runCatching {
                JSONObject(config).optString("secret", "")
            }.getOrDefault("")
        }

        fun start(context: Context, config: String): Boolean {
            val intent = Intent(context, LitchiCoreService::class.java).apply {
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
            val intent = Intent(context, LitchiCoreService::class.java).apply {
                action = ACTION_STOP
            }
            return runCatching {
                context.startService(intent)
                true
            }.getOrDefault(false)
        }
    }
}
