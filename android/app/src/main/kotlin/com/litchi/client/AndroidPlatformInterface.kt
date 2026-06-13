package com.litchi.client

class AndroidPlatformInterface(private val service: LitchiVpnService) {
    fun autoDetectInterfaceControl(fd: Int) {
        service.protect(fd)
    }

    fun openTun(options: Any?): Int {
        return service.openTun(options)
    }

    fun useProcFS(): Boolean = false

    fun findConnectionOwner(
        ipProtocol: Int,
        sourceAddress: String?,
        sourcePort: Int,
        destinationAddress: String?,
        destinationPort: Int
    ): Int = 0

    fun packageNameByUid(uid: Int): String = ""

    fun uidByPackageName(packageName: String?): Int = 0

    fun writeLog(message: String?) {
        AndroidSingboxEngine.appendLog(message.orEmpty())
    }
}
