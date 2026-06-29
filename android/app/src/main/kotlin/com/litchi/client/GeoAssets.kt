package com.litchi.client

import android.content.Context
import android.util.Log
import java.io.File

/**
 * Copies the geo databases bundled in the APK's `assets/` into the core home
 * dir ([Context.getFilesDir]) so mihomo can evaluate GEOIP/GEOSITE rules
 * without downloading anything at startup.
 *
 * The panel's Clash config ends with `GEOIP,CN,DIRECT`, which requires
 * `country.mmdb`. Without a local copy the core tries to fetch it from GitHub
 * on first launch; behind a firewall that fails and the core never starts —
 * latency tests and proxying both break. Bundling the files removes that
 * network dependency, the same way Clash Verge / Mihomo Party / FlClash do.
 */
object GeoAssets {
    private const val TAG = "LitchiGeo"

    // Must match the files placed under android/app/src/main/assets/.
    private val files = listOf("country.mmdb", "geosite.dat")

    /** Copies each bundled geo file into [Context.getFilesDir] if missing. */
    fun stage(context: Context) {
        val home = context.filesDir
        for (name in files) {
            val dest = File(home, name)
            if (dest.exists() && dest.length() > 0) continue
            runCatching {
                context.assets.open(name).use { input ->
                    dest.outputStream().use { output -> input.copyTo(output) }
                }
            }.onFailure { Log.w(TAG, "stage $name failed", it) }
        }
    }
}
