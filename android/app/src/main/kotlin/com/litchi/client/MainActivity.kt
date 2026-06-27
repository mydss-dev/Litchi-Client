package com.litchi.client

import android.Manifest
import android.content.ActivityNotFoundException
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.net.VpnService
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var vpnPermissionResult: MethodChannel.Result? = null
    private var pendingPrepareResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "litchi/url_opener"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "openUrl" -> {
                    val url = call.arguments as? String
                    if (url.isNullOrBlank()) {
                        result.success(false)
                        return@setMethodCallHandler
                    }
                    result.success(openUrl(url))
                }
                else -> result.notImplemented()
            }
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "litchi/android_core"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "prepareVpn" -> prepareVpn(result)
                // ── Core-only ────────────────────────────────────────────
                "startCoreOnly" -> {
                    val config = (call.arguments as? Map<*, *>)?.get("config") as? String
                    if (config.isNullOrBlank()) {
                        result.error("invalid_config", "核心配置为空", null)
                        return@setMethodCallHandler
                    }
                    if (!AndroidMihomoEngine.isAvailable()) {
                        result.error(
                            "missing_core",
                            AndroidMihomoEngine.lastError(),
                            null
                        )
                        return@setMethodCallHandler
                    }
                    result.success(LitchiCoreService.start(this, config))
                }
                "stopCore" -> {
                    LitchiVpnService.stop(this)
                    result.success(LitchiCoreService.stop(this))
                }
                "isCoreRunning" -> result.success(LitchiCoreService.isRunning)
                "controllerPort" -> result.success(LitchiCoreService.controllerPort)
                "controllerSecret" -> result.success(LitchiCoreService.controllerSecret)
                // ── VPN ──────────────────────────────────────────────────
                "startVpn" -> {
                    val config = (call.arguments as? Map<*, *>)?.get("config") as? String
                    if (config.isNullOrBlank()) {
                        result.error("invalid_config", "核心配置为空", null)
                        return@setMethodCallHandler
                    }
                    if (!AndroidMihomoEngine.isAvailable()) {
                        result.error(
                            "missing_core",
                            AndroidMihomoEngine.lastError(),
                            null
                        )
                        return@setMethodCallHandler
                    }
                    result.success(LitchiVpnService.start(this, config))
                }
                "stopVpn" -> result.success(LitchiVpnService.stop(this))
                "isVpnRunning" -> result.success(LitchiVpnService.isRunning)
                "switchProxy" -> {
                    val args = call.arguments as? Map<*, *>
                    val group = args?.get("group") as? String
                    val proxy = args?.get("proxy") as? String
                    if (group.isNullOrBlank() || proxy.isNullOrBlank()) {
                        result.error("invalid_proxy", "代理组或节点为空", null)
                    } else {
                        result.success(AndroidMihomoEngine.switchProxy(group, proxy))
                    }
                }
                "setMode" -> {
                    val mode = (call.arguments as? Map<*, *>)?.get("mode") as? String
                    if (mode.isNullOrBlank()) {
                        result.error("invalid_mode", "代理模式为空", null)
                    } else {
                        result.success(AndroidMihomoEngine.setMode(mode))
                    }
                }
                "closeConnections" -> result.success(
                    AndroidMihomoEngine.closeConnections()
                )
                "reloadConfig" -> {
                    val config = (call.arguments as? Map<*, *>)?.get("config") as? String
                    if (config.isNullOrBlank()) {
                        result.error("invalid_config", "核心配置为空", null)
                    } else {
                        result.success(AndroidMihomoEngine.reloadConfig(config))
                    }
                }
                // ── Legacy / shared ──────────────────────────────────────
                "start" -> {
                    val config = (call.arguments as? Map<*, *>)?.get("config") as? String
                    if (config.isNullOrBlank()) {
                        result.error("invalid_config", "核心配置为空", null)
                        return@setMethodCallHandler
                    }
                    if (!AndroidMihomoEngine.isAvailable()) {
                        result.error(
                            "missing_core",
                            AndroidMihomoEngine.lastError(),
                            null
                        )
                        return@setMethodCallHandler
                    }
                    // Legacy: start core-only first, then VPN.
                    val coreOk = LitchiCoreService.start(this, config)
                    if (!coreOk) {
                        result.success(false)
                        return@setMethodCallHandler
                    }
                    result.success(LitchiVpnService.start(this, config))
                }
                "stop" -> {
                    LitchiVpnService.stop(this)
                    result.success(LitchiCoreService.stop(this))
                }
                "isRunning" -> result.success(
                    LitchiCoreService.isRunning || LitchiVpnService.isRunning
                )
                "lastError" -> result.success(AndroidMihomoEngine.lastError())
                "version" -> result.success(AndroidMihomoEngine.version())
                else -> result.notImplemented()
            }
        }
        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "litchi/android_core/status"
        ).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                AndroidCoreStatus.setEventSink(events)
            }

            override fun onCancel(arguments: Any?) {
                AndroidCoreStatus.setEventSink(null)
            }
        })
    }

    @Deprecated("Deprecated in Android API")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQUEST_VPN_PERMISSION) {
            vpnPermissionResult?.success(resultCode == RESULT_OK)
            vpnPermissionResult = null
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == REQUEST_NOTIFICATION_PERMISSION) {
            val result = pendingPrepareResult ?: return
            pendingPrepareResult = null
            continuePrepareVpn(result)
        }
    }

    private fun openUrl(url: String): Boolean {
        return try {
            val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url)).apply {
                addCategory(Intent.CATEGORY_BROWSABLE)
            }
            startActivity(intent)
            true
        } catch (_: ActivityNotFoundException) {
            false
        } catch (_: Exception) {
            false
        }
    }

    private fun prepareVpn(result: MethodChannel.Result) {
        if (requestNotificationPermissionIfNeeded(result)) return
        continuePrepareVpn(result)
    }

    private fun continuePrepareVpn(result: MethodChannel.Result) {
        val intent = VpnService.prepare(this)
        if (intent == null) {
            result.success(true)
            return
        }
        if (vpnPermissionResult != null) {
            result.error("vpn_permission_pending", "VPN 权限请求正在进行中", null)
            return
        }
        vpnPermissionResult = result
        startActivityForResult(intent, REQUEST_VPN_PERMISSION)
    }

    companion object {
        private const val REQUEST_VPN_PERMISSION = 7301
        private const val REQUEST_NOTIFICATION_PERMISSION = 7302
    }

    private fun requestNotificationPermissionIfNeeded(result: MethodChannel.Result): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return false
        if (checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED) {
            return false
        }
        if (pendingPrepareResult != null) {
            result.error("notification_permission_pending", "通知权限请求正在进行中", null)
            return true
        }
        pendingPrepareResult = result
        requestPermissions(
            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
            REQUEST_NOTIFICATION_PERMISSION
        )
        return true
    }
}
