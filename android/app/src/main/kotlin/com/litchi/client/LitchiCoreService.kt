package com.litchi.client

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build

/**
 * Non-VPN foreground service that runs the mihomo core without TUN.
 *
 * The core is always loaded on Android so that latency tests, node switching,
 * and mode changes work instantly without a VPN permission prompt.  When the
 * user taps "connect" the VPN layer ([LitchiVpnService]) attaches on top of
 * the already-running core.
 */
class LitchiCoreService : Service() {

    override fun onBind(intent: Intent?) = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                AndroidCoreStatus.emit("stopping")
                stopCore()
                return START_NOT_STICKY
            }

            ACTION_START -> {
                val config = intent.getStringExtra(EXTRA_CONFIG).orEmpty()
                if (config.isBlank()) {
                    AndroidCoreStatus.emit("error", "Android core config is empty")
                    stopCore(emitStopped = false)
                    return START_NOT_STICKY
                }
                if (isRunning && currentConfig == config) {
                    startCoreForeground()
                    AndroidCoreStatus.emit("running")
                    return START_NOT_STICKY
                }
                currentConfig = config
                startCoreForeground()
                AndroidCoreStatus.emit("starting")
                val ok = AndroidMihomoEngine.startCoreOnly(config, filesDir.absolutePath)
                if (!ok) {
                    AndroidCoreStatus.emit("error", AndroidMihomoEngine.lastError())
                    stopCore(emitStopped = false)
                    return START_NOT_STICKY
                }
                isRunning = true
                startCoreForeground()
                AndroidCoreStatus.emit("running")
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
        AndroidMihomoEngine.stop()
        currentConfig = ""
        isRunning = false
        if (emitStopped) AndroidCoreStatus.emit("stopped")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
        stopSelf()
    }

    private fun startCoreForeground() {
        val notification = buildNotification()
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

    private fun buildNotification(): Notification {
        ensureNotificationChannel()
        val text = if (LitchiVpnService.isRunning) "Litchi VPN connected"
            else "Litchi core ready"
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
                .setSmallIcon(R.mipmap.ic_launcher)
                .setContentTitle("Litchi")
                .setContentText(text)
                .setOngoing(true)
                .build()
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
                .setSmallIcon(R.mipmap.ic_launcher)
                .setContentTitle("Litchi")
                .setContentText(text)
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

        private var currentConfig: String = ""

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
