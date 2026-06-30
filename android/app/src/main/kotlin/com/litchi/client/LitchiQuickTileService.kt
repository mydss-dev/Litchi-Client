package com.litchi.client

import android.content.Intent
import android.content.Context
import android.net.VpnService
import android.os.Build
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService

class LitchiQuickTileService : TileService() {
    override fun onStartListening() {
        super.onStartListening()
        updateTile()
    }

    override fun onClick() {
        super.onClick()
        if (LitchiVpnService.isRunning) {
            QuickTileState.markDisconnected(this)
            LitchiVpnService.stop(this)
            qsTile?.state = Tile.STATE_INACTIVE
            qsTile?.updateTile()
            return
        }

        val config = LitchiCoreService.activeConfig()
        if (config.isBlank() || VpnService.prepare(this) != null) {
            openClient()
            return
        }

        if (LitchiVpnService.start(this, config)) {
            QuickTileState.clearDisconnected(this)
            qsTile?.state = Tile.STATE_ACTIVE
            qsTile?.updateTile()
        } else {
            openClient()
        }
    }

    private fun updateTile() {
        qsTile?.apply {
            label = getString(R.string.app_name)
            state = if (LitchiVpnService.isRunning) {
                Tile.STATE_ACTIVE
            } else {
                Tile.STATE_INACTIVE
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                subtitle = getString(
                    if (LitchiVpnService.isRunning) {
                        R.string.quick_tile_connected
                    } else {
                        R.string.quick_tile_disconnected
                    }
                )
            }
            updateTile()
        }
    }

    private fun openClient() {
        val intent = packageManager.getLaunchIntentForPackage(packageName)
            ?.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            ?: return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            startActivityAndCollapse(intent)
        } else {
            @Suppress("DEPRECATION")
            startActivity(intent)
        }
    }
}

internal object QuickTileState {
    private const val PREFS = "client_native_state"
    private const val DISCONNECTED = "quick_tile_disconnected"

    fun markDisconnected(context: Context) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .putBoolean(DISCONNECTED, true)
            .apply()
    }

    fun clearDisconnected(context: Context) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .remove(DISCONNECTED)
            .apply()
    }

    fun consumeDisconnected(context: Context): Boolean {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val value = prefs.getBoolean(DISCONNECTED, false)
        if (value) prefs.edit().remove(DISCONNECTED).apply()
        return value
    }
}
