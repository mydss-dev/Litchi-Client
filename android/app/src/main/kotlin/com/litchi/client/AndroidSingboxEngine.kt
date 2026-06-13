package com.litchi.client

import android.net.VpnService
import java.lang.reflect.Proxy

object AndroidSingboxEngine {
    private var lastError: String = ""
    private var boxService: Any? = null
    private val logs = ArrayDeque<String>()
    private const val MAX_LOGS = 300

    fun isAvailable(): Boolean {
        val clazz = libboxClass()
        if (clazz == null) {
            lastError = "Android 核心库未打包，请加入 sing-box libbox AAR 后再启动"
            return false
        }
        val hasCommandServer = clazz.methods.any {
            it.name.equals("newCommandServer", ignoreCase = true)
        }
        if (!hasCommandServer) {
            lastError = "libbox 已检测到，但未找到 newCommandServer API"
            return false
        }
        return true
    }

    fun version(): String {
        if (!isAvailable()) return "未打包 Android 核心库"
        return runCatching {
            val clazz = libboxClass() ?: return@runCatching "未打包 Android 核心库"
            val method = clazz.methods.firstOrNull {
                it.name.equals("Version", ignoreCase = true) && it.parameterTypes.isEmpty()
            }
            method?.invoke(null)?.toString() ?: "libbox 已加载"
        }.getOrElse {
            "libbox 已加载"
        }
    }

    fun start(configJson: String, service: VpnService): Boolean {
        if (!isAvailable()) return false
        stop()
        return runCatching {
            val clazz = libboxClass() ?: error("libbox not found")
            setupLibbox(clazz, service as LitchiVpnService)
            val newCommandServer = clazz.methods.firstOrNull {
                it.name.equals("newCommandServer", ignoreCase = true) &&
                    it.parameterTypes.size == 2
            } ?: error("newCommandServer API not found")
            val handler = newCommandServerProxy(newCommandServer.parameterTypes[0])
            val platform = newPlatformProxy(
                newCommandServer.parameterTypes[1],
                AndroidPlatformInterface(service)
            )
            val instance = newCommandServer.invoke(null, handler, platform)
            val start = instance.javaClass.methods.firstOrNull {
                it.name.equals("start", ignoreCase = true) && it.parameterTypes.isEmpty()
            } ?: error("CommandServer.start API not found")
            start.invoke(instance)
            val reload = instance.javaClass.methods.firstOrNull {
                it.name.equals("startOrReloadService", ignoreCase = true) &&
                    it.parameterTypes.size == 2
            } ?: error("CommandServer.startOrReloadService API not found")
            reload.invoke(instance, configJson, null)
            boxService = instance
            lastError = ""
            true
        }.getOrElse {
            lastError = it.message ?: it.toString()
            appendLog("start failed: $lastError")
            false
        }
    }

    fun stop() {
        val service = boxService
        boxService = null
        if (service != null) {
            runCatching {
                val method = service.javaClass.methods.firstOrNull {
                    it.name.equals("closeService", ignoreCase = true) && it.parameterTypes.isEmpty()
                }
                method?.invoke(service)
                val close = service.javaClass.methods.firstOrNull {
                    it.name.equals("close", ignoreCase = true) && it.parameterTypes.isEmpty()
                }
                close?.invoke(service)
            }
        }
    }

    fun appendLog(message: String) {
        if (message.isBlank()) return
        synchronized(logs) {
            logs.addLast(message)
            while (logs.size > MAX_LOGS) logs.removeFirst()
        }
    }

    fun recentLogs(): String = synchronized(logs) { logs.joinToString("\n") }

    fun lastError(): String {
        if (lastError.isEmpty()) {
            lastError = "Android 核心未启动"
        }
        return lastError
    }

    private fun libboxClass(): Class<*>? {
        val names = listOf(
            "libbox.Libbox",
            "io.nekohasekai.libbox.Libbox"
        )
        for (name in names) {
            val clazz = runCatching { Class.forName(name) }.getOrNull()
            if (clazz != null) return clazz
        }
        return null
    }

    private fun setupLibbox(clazz: Class<*>, service: LitchiVpnService) {
        val setup = clazz.methods.firstOrNull {
            it.name.equals("setup", ignoreCase = true) && it.parameterTypes.size == 1
        } ?: return
        val optionsClass = setup.parameterTypes[0]
        val options = optionsClass.getDeclaredConstructor().newInstance()
        invokeSetter(options, "setBasePath", service.filesDir.absolutePath)
        invokeSetter(options, "setWorkingPath", service.filesDir.absolutePath)
        invokeSetter(options, "setTempPath", service.cacheDir.absolutePath)
        invokeSetter(options, "setCommandServerListenPort", 0)
        invokeSetter(options, "setLogMaxLines", 300L)
        setup.invoke(null, options)
    }

    private fun invokeSetter(target: Any, name: String, value: Any) {
        val method = target.javaClass.methods.firstOrNull {
            it.name == name && it.parameterTypes.size == 1
        } ?: return
        method.invoke(target, value)
    }

    private fun newCommandServerProxy(interfaceClass: Class<*>): Any {
        return Proxy.newProxyInstance(
            interfaceClass.classLoader,
            arrayOf(interfaceClass)
        ) { _, method, args ->
            when (method.name) {
                "serviceStop" -> {
                    boxService = null
                    null
                }
                "serviceReload" -> null
                "writeDebugMessage" -> {
                    appendLog(args?.getOrNull(0)?.toString().orEmpty())
                    null
                }
                "setSystemProxyEnabled" -> null
                "getSystemProxyStatus" -> null
                else -> defaultValue(method.returnType)
            }
        }
    }

    private fun newPlatformProxy(interfaceClass: Class<*>, platform: AndroidPlatformInterface): Any {
        if (!interfaceClass.isInterface) return platform
        return Proxy.newProxyInstance(
            interfaceClass.classLoader,
            arrayOf(interfaceClass)
        ) { _, method, args ->
            when (method.name) {
                "autoDetectInterfaceControl" -> {
                    platform.autoDetectInterfaceControl((args?.getOrNull(0) as? Number)?.toInt() ?: -1)
                    null
                }
                "openTun" -> platform.openTun(args?.getOrNull(0))
                "useProcFS" -> platform.useProcFS()
                "findConnectionOwner" -> null
                "packageNameByUid" -> platform.packageNameByUid((args?.getOrNull(0) as? Number)?.toInt() ?: 0)
                "uidByPackageName" -> platform.uidByPackageName(args?.getOrNull(0)?.toString())
                "writeLog" -> {
                    platform.writeLog(args?.getOrNull(0)?.toString())
                    null
                }
                else -> defaultValue(method.returnType)
            }
        }
    }

    private fun defaultValue(type: Class<*>): Any? {
        return when (type) {
            java.lang.Boolean.TYPE -> false
            java.lang.Byte.TYPE -> 0.toByte()
            java.lang.Short.TYPE -> 0.toShort()
            java.lang.Integer.TYPE -> 0
            java.lang.Long.TYPE -> 0L
            java.lang.Float.TYPE -> 0f
            java.lang.Double.TYPE -> 0.0
            java.lang.Character.TYPE -> 0.toChar()
            else -> null
        }
    }
}
