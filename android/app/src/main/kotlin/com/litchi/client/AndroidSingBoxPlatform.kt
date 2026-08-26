package com.litchi.client

import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.os.Build
import android.system.OsConstants
import io.nekohasekai.libbox.ConnectionOwner
import io.nekohasekai.libbox.InterfaceUpdateListener
import io.nekohasekai.libbox.Libbox
import io.nekohasekai.libbox.LocalDNSTransport
import io.nekohasekai.libbox.NetworkInterfaceIterator
import io.nekohasekai.libbox.Notification
import io.nekohasekai.libbox.PlatformInterface
import io.nekohasekai.libbox.StringIterator
import io.nekohasekai.libbox.TunOptions
import io.nekohasekai.libbox.WIFIState
import java.net.NetworkInterface
import io.nekohasekai.libbox.NetworkInterface as BoxNetworkInterface

internal class AndroidSingBoxPlatform(private val context: Context) : PlatformInterface {
    @Volatile
    private var vpnService: LitchiVpnService? = null
    private val connectivity = context.getSystemService(ConnectivityManager::class.java)
    private var monitorListener: InterfaceUpdateListener? = null
    private var monitorRegistered = false

    private val networkCallback = object : ConnectivityManager.NetworkCallback() {
        override fun onAvailable(network: Network) = publishDefaultNetwork(network)
        override fun onCapabilitiesChanged(network: Network, capabilities: NetworkCapabilities) =
            publishDefaultNetwork(network)
        override fun onLost(network: Network) = publishDefaultNetwork(connectivity.activeNetwork)
    }

    fun attachVpn(service: LitchiVpnService?) {
        vpnService = service
    }

    override fun localDNSTransport(): LocalDNSTransport? = null

    override fun usePlatformAutoDetectInterfaceControl(): Boolean = true

    override fun autoDetectInterfaceControl(fd: Int) {
        if (vpnService?.protect(fd) != true) error("android: failed to protect socket")
    }

    override fun openTun(options: TunOptions): Int =
        vpnService?.openTunForSingBox(options) ?: error("android: VPN service is unavailable")

    override fun useProcFS(): Boolean = Build.VERSION.SDK_INT < Build.VERSION_CODES.Q

    override fun findConnectionOwner(
        ipProtocol: Int,
        sourceAddress: String,
        sourcePort: Int,
        destinationAddress: String,
        destinationPort: Int,
    ): ConnectionOwner = error("android: connection owner lookup is unavailable")

    override fun startDefaultInterfaceMonitor(listener: InterfaceUpdateListener) {
        monitorListener = listener
        if (!monitorRegistered) {
            connectivity.registerDefaultNetworkCallback(networkCallback)
            monitorRegistered = true
        }
        publishDefaultNetwork(connectivity.activeNetwork)
    }

    override fun closeDefaultInterfaceMonitor(listener: InterfaceUpdateListener) {
        if (monitorListener === listener) monitorListener = null
        if (monitorRegistered) {
            runCatching { connectivity.unregisterNetworkCallback(networkCallback) }
            monitorRegistered = false
        }
    }

    override fun getInterfaces(): NetworkInterfaceIterator {
        val result = mutableListOf<BoxNetworkInterface>()
        for (network in connectivity.allNetworks) {
            val properties = connectivity.getLinkProperties(network) ?: continue
            val capabilities = connectivity.getNetworkCapabilities(network) ?: continue
            val name = properties.interfaceName ?: continue
            val systemInterface = runCatching { NetworkInterface.getByName(name) }.getOrNull() ?: continue
            result += BoxNetworkInterface().apply {
                this.name = name
                index = systemInterface.index
                mtu = runCatching { systemInterface.mtu }.getOrDefault(1500)
                addresses = StringArray(
                    systemInterface.interfaceAddresses.map {
                        "${it.address.hostAddress}/${it.networkPrefixLength}"
                    }.iterator(),
                )
                dnsServer = StringArray(
                    properties.dnsServers.mapNotNull { it.hostAddress }.iterator(),
                )
                flags = OsConstants.IFF_UP or OsConstants.IFF_RUNNING
                type = when {
                    capabilities.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) -> Libbox.InterfaceTypeWIFI
                    capabilities.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) -> Libbox.InterfaceTypeCellular
                    capabilities.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) -> Libbox.InterfaceTypeEthernet
                    else -> Libbox.InterfaceTypeOther
                }
                metered = !capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_NOT_METERED)
            }
        }
        return InterfaceArray(result.iterator())
    }

    override fun underNetworkExtension(): Boolean = false
    override fun includeAllNetworks(): Boolean = false
    override fun readWIFIState(): WIFIState? = null
    override fun systemCertificates(): StringIterator = StringArray(emptyList<String>().iterator())
    override fun clearDNSCache() = Unit
    override fun sendNotification(notification: Notification) = Unit

    private fun publishDefaultNetwork(network: Network?) {
        val listener = monitorListener ?: return
        val properties = network?.let(connectivity::getLinkProperties) ?: return
        val name = properties.interfaceName ?: return
        val index = runCatching { NetworkInterface.getByName(name)?.index ?: -1 }.getOrDefault(-1)
        if (index < 0) return
        val capabilities = connectivity.getNetworkCapabilities(network)
        listener.updateDefaultInterface(
            name,
            index,
            capabilities?.hasCapability(NetworkCapabilities.NET_CAPABILITY_NOT_METERED) == false,
            false,
        )
    }

    private class InterfaceArray(
        private val iterator: Iterator<BoxNetworkInterface>,
    ) : NetworkInterfaceIterator {
        override fun hasNext(): Boolean = iterator.hasNext()
        override fun next(): BoxNetworkInterface = iterator.next()
    }

    internal class StringArray(private val iterator: Iterator<String>) : StringIterator {
        override fun len(): Int = 0
        override fun hasNext(): Boolean = iterator.hasNext()
        override fun next(): String = iterator.next()
    }
}
