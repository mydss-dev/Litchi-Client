import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

import 'secure_logger.dart';

/// Reads the operating system's configured DNS servers.
///
/// On Windows this uses `GetNetworkParams` from iphlpapi.dll. The list is
/// captured *before* the TUN bridge re-points the system resolver at its
/// gateway (172.19.0.2), so the main core's `dns-local` can be pinned to the
/// real upstream instead of resolving CN domains through a dead address.
abstract final class SystemDns {
  SystemDns._();

  static const int _success = 0;
  static const int _bufferOverflow = 111;
  static const int _ipAddrStringLength = 16;

  static final DynamicLibrary _iphlpapi = DynamicLibrary.open('iphlpapi.dll');

  static final _getNetworkParams = _iphlpapi.lookupFunction<
    Int32 Function(Pointer<_FixedInfo>, Pointer<Uint32>),
    int Function(Pointer<_FixedInfo>, Pointer<Uint32>)
  >('GetNetworkParams');

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
