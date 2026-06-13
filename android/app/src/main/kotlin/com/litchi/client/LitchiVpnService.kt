package com.litchi.client

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.net.VpnService
import android.os.Build
import android.os.ParcelFileDescriptor

class LitchiVpnService : VpnService() {
    private var tunFd: ParcelFileDescriptor? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                stopCore()
                return START_NOT_STICKY
            }
            ACTION_START -> {
                val config = intent.getStringExtra(EXTRA_CONFIG).orEmpty()
                if (config.isBlank()) {
                    stopCore()
                    return START_NOT_STICKY
                }
                startForeground(NOTIFICATION_ID, buildNotification("Litchi 正在连接"))
                val ok = AndroidSingboxEngine.start(config, this)
                if (!ok) {
                    stopCore()
                    return START_NOT_STICKY
                }
                isRunning = true
                startForeground(NOTIFICATION_ID, buildNotification("Litchi 已连接"))
                return START_STICKY
            }
        }
        stopSelf()
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        stopCore()
        super.onDestroy()
    }

    private fun stopCore() {
        AndroidSingboxEngine.stop()
        runCatching { tunFd?.close() }
        tunFd = null
        isRunning = false
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
        stopSelf()
    }

    fun openTun(options: Any?): Int {
        runCatching { tunFd?.close() }
        val builder = Builder()
            .setSession("Litchi")
            .setMtu(9000)
            .addAddress("172.19.0.1", 30)
            .addDnsServer("1.1.1.1")
            .addRoute("0.0.0.0", 0)
        tunFd = builder.establish()
        return tunFd?.fd ?: -1
    }

    private fun buildNotification(text: String): Notification {
        ensureNotificationChannel()
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
        private const val ACTION_START = "com.litchi.client.START_VPN"
        private const val ACTION_STOP = "com.litchi.client.STOP_VPN"
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
