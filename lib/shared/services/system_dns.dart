import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

import '../../config/app_identity.dart';
import 'secure_logger.dart';

/// Reads the operating system's configured DNS servers.
///
/// On Windows this uses `GetNetworkParams` (the global resolver) and
/// `GetAdaptersAddresses` (per-adapter) from iphlpapi.dll. The list is
/// captured *before* the TUN bridge re-points the system resolver at its
/// gateway (172.19.0.2), so the main core's `dns-local` can be pinned to the
/// real upstream instead of resolving CN domains through a dead address.
abstract final class SystemDns {
  SystemDns._();

  static const int _success = 0;
  static const int _bufferOverflow = 111;
  static const int _ipAddrStringLength = 16;

  static const int _afInet = 2;
  static const int _flagsSkipAddressLists = 0x1 | 0x2 | 0x4;
  static const int _ifTypeSoftwareLoopback = 24;
  static const int _ifOperStatusUp = 1;

  static final DynamicLibrary _iphlpapi = DynamicLibrary.open('iphlpapi.dll');

  static final _getNetworkParams = _iphlpapi.lookupFunction<
    Int32 Function(Pointer<_FixedInfo>, Pointer<Uint32>),
    int Function(Pointer<_FixedInfo>, Pointer<Uint32>)
  >('GetNetworkParams');

  static final _getAdaptersAddresses = _iphlpapi.lookupFunction<
    Uint32 Function(
      Uint32,
      Uint32,
      Pointer<Void>,
      Pointer<_AdapterAddresses>,
      Pointer<Uint32>,
    ),
    int Function(int, int, Pointer<Void>, Pointer<_AdapterAddresses>, Pointer<Uint32>)
  >('GetAdaptersAddresses');

  /// Returns the system's IPv4 DNS server addresses, deduplicated and in the
  /// order the system prefers them. Empty on non-Windows or on failure, in
  /// which case callers fall back to sing-box's `type: local`.
  static List<String> readServers() {
    if (!Platform.isWindows) return const <String>[];
    final size = calloc<Uint32>();
    try {
      if (_getNetworkParams(nullptr, size) != _bufferOverflow) {
        return const <String>[];
      }
      final required = size.value;
      if (required <= 0) return const <String>[];
      final buffer = calloc<Uint8>(required);
      try {
        size.value = required;
        if (_getNetworkParams(buffer.cast<_FixedInfo>(), size) != _success) {
          return const <String>[];
        }
        return filterDnsServers(_readServerList(buffer.cast<_FixedInfo>().ref));
      } finally {
        calloc.free(buffer);
      }
    } catch (error) {
      SecureLogger.debug('system DNS read failed', error);
      return const <String>[];
    } finally {
      calloc.free(size);
    }
  }

  /// Returns the IPv4 DNS servers configured on the currently-up physical
  /// adapters, skipping loopback and the app's own TUN adapter.
  ///
  /// Unlike [readServers] — which reports the *global* resolver through
  /// `GetNetworkParams` and therefore returns the TUN gateway (172.19.0.2)
  /// once the bridge re-points it — this walks `GetAdaptersAddresses` per
  /// adapter, so it still sees the real Wi-Fi / hotspot upstream after a
  /// network switch while TUN is active.
  static List<String> readPhysicalDnsServers() {
    if (!Platform.isWindows) return const <String>[];
    final size = calloc<Uint32>();
    try {
      if (_getAdaptersAddresses(
            _afInet,
            _flagsSkipAddressLists,
            nullptr,
            nullptr,
            size,
          ) !=
          _bufferOverflow) {
        return const <String>[];
      }
      final required = size.value;
      if (required <= 0) return const <String>[];
      final buffer = calloc<Uint8>(required);
      try {
        size.value = required;
        final rc = _getAdaptersAddresses(
          _afInet,
          _flagsSkipAddressLists,
          nullptr,
          buffer.cast<_AdapterAddresses>(),
          size,
        );
        if (rc != _success) return const <String>[];
        return filterDnsServers(_walkAdapters(buffer.cast<_AdapterAddresses>()));
      } finally {
        calloc.free(buffer);
      }
    } catch (error) {
      SecureLogger.debug('physical interface DNS read failed', error);
      return const <String>[];
    } finally {
      calloc.free(size);
    }
  }

  static Iterable<String> _walkAdapters(Pointer<_AdapterAddresses> first) {
    final result = <String>[];
    var adapter = first;
    var guard = 0;
    while (adapter != nullptr && guard < 64) {
      final info = adapter.ref;
      if (info.ifType != _ifTypeSoftwareLoopback &&
          info.operStatus == _ifOperStatusUp &&
          !_isOwnTunAdapter(info.friendlyName)) {
        _collectDnsServers(info.firstDnsServerAddress, result);
      }
      adapter = info.next;
      guard++;
    }
    return result;
  }

  static bool _isOwnTunAdapter(Pointer<Utf16> friendlyName) {
    if (friendlyName == nullptr) return false;
    return friendlyName.toDartString() == AppIdentity.tunInterfaceAlias;
  }

  static void _collectDnsServers(
    Pointer<_DnsServerAddress> first,
    List<String> out,
  ) {
    var node = first;
    var guard = 0;
    while (node != nullptr && guard < 16) {
      final address = node.ref.address;
      final lpSockaddr = address.lpSockaddr;
      if (lpSockaddr != nullptr && address.iSockaddrLength >= 8) {
        final bytes = lpSockaddr.asTypedList(address.iSockaddrLength);
        final family = bytes[0] | (bytes[1] << 8);
        if (family == _afInet) {
          out.add('${bytes[4]}.${bytes[5]}.${bytes[6]}.${bytes[7]}');
        }
      }
      node = node.ref.next;
      guard++;
    }
  }

  /// Reduces raw resolver addresses to deduplicated IPv4 literals.
  ///
  /// Kept pure and static so it is unit-testable without touching FFI. Loopback
  /// addresses are retained: a local DNS forwarder is a legitimate upstream.
  static List<String> filterDnsServers(Iterable<String> raw) {
    final seen = <String>{};
    final result = <String>[];
    for (final value in raw) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) continue;
      final address = InternetAddress.tryParse(trimmed);
      if (address == null || address.type != InternetAddressType.IPv4) {
        continue;
      }
      if (seen.add(trimmed)) result.add(trimmed);
    }
    return result;
  }

  static List<String> _readServerList(_FixedInfo info) {
    final result = <String>[];
    var node = info.currentDnsServer;
    var guard = 0;
    while (node != nullptr && guard < 16) {
      result.add(_readAscii(node.ref.ipAddress));
      node = node.ref.next;
      guard++;
    }
    return result;
  }

  static String _readAscii(Array<Uint8> bytes) {
    final buffer = StringBuffer();
    for (var i = 0; i < _ipAddrStringLength; i++) {
      final byte = bytes[i];
      if (byte == 0) break;
      buffer.writeCharCode(byte);
    }
    return buffer.toString();
  }
}

final class _FixedInfo extends Struct {
  @Array(132)
  external Array<Uint8> hostName;

  @Array(132)
  external Array<Uint8> domainName;

  external Pointer<_IpAddrString> currentDnsServer;

  external _IpAddrString dnsServerList;

  @Uint32()
  external int nodeType;

  @Array(260)
  external Array<Uint8> scopeId;

  @Uint32()
  external int enableRouting;

  @Uint32()
  external int enableProxy;

  @Uint32()
  external int enableDns;
}

final class _IpAddrString extends Struct {
  external Pointer<_IpAddrString> next;

  @Array(16)
  external Array<Uint8> ipAddress;

  @Array(16)
  external Array<Uint8> ipMask;

  @Uint32()
  external int context;
}

// IP_ADAPTER_ADDRESSES (Vista+ layout, x64). Only the fields needed to locate
// the per-adapter DNS server list, the operational status, the interface type
// and the friendly name are declared; the intervening members are retained as
// placeholders so every following offset matches the real struct.
final class _AdapterAddresses extends Struct {
  @Uint32()
  external int length;

  @Uint32()
  external int ifIndex;

  external Pointer<_AdapterAddresses> next;

  external Pointer<Uint8> adapterName;

  external Pointer<Uint8> firstUnicastAddress;

  external Pointer<Uint8> firstAnycastAddress;

  external Pointer<Uint8> firstMulticastAddress;

  external Pointer<_DnsServerAddress> firstDnsServerAddress;

  external Pointer<Utf16> dnsSuffix;

  external Pointer<Utf16> description;

  external Pointer<Utf16> friendlyName;

  @Array(8)
  external Array<Uint8> physicalAddress;

  @Uint32()
  external int physicalAddressLength;

  @Uint32()
  external int flags;

  @Uint32()
  external int mtu;

  @Uint32()
  external int ifType;

  @Uint32()
  external int operStatus;
}

// IP_ADAPTER_DNS_SERVER_ADDRESS: the head of an adapter's DNS server list.
final class _DnsServerAddress extends Struct {
  @Uint32()
  external int length;

  @Uint32()
  external int ifIndex;

  external Pointer<_DnsServerAddress> next;

  external _SockaddrAddress address;
}

// SOCKET_ADDRESS: a raw sockaddr pointer plus its byte length.
final class _SockaddrAddress extends Struct {
  external Pointer<Uint8> lpSockaddr;

  @Int32()
  external int iSockaddrLength;
}
