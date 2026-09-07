import 'dart:io';

import '../../config/app_identity.dart';

/// Lightweight preflight for Windows TUN mode.
///
/// Two auto-route TUN clients fighting over the same routing/DNS stack can
/// leave Windows in a black-hole state. Only interfaces that are currently
/// visible with addresses are inspected, so merely having Clash/Mihomo or
/// another VPN installed does not block Litchi.
abstract final class WindowsTunConflictDetector {
  static const _clientNameHints = <String>[
    'clash',
    'mihomo',
    'meta',
    'sing-box',
    'singbox',
    'hiddify',
    'nekobox',
    'v2rayn',
  ];

  static Future<String?> findActiveConflict() async {
    if (!Platform.isWindows) return null;

    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        includeLinkLocal: true,
        type: InternetAddressType.any,
      );
      for (final interface in interfaces) {
        final name = interface.name.trim();
        final normalized = name.toLowerCase();
        if (normalized == AppIdentity.tunInterfaceAlias.toLowerCase()) {
          continue;
        }

        final hasFakeIpRange = interface.addresses.any(_isBenchmarkFakeIp);
        final knownTunClient = _clientNameHints.any(normalized.contains);
        final genericTunAlias =
            normalized == 'tun' ||
            normalized.startsWith('tun-') ||
            normalized.startsWith('tun ');
        if (!hasFakeIpRange && !knownTunClient && !genericTunAlias) continue;

        if (normalized == AppIdentity.legacyTunInterfaceAlias.toLowerCase()) {
          return '旧版 Litchi TUN（$name）';
        }
        return name.isEmpty ? '其他 TUN/VPN' : name;
      }
    } catch (_) {
      // A failed probe must not block a legitimate connection attempt. The
      // native TUN start still reports the concrete route/adapter error.
    }
    return null;
  }

  static bool _isBenchmarkFakeIp(InternetAddress address) {
    if (address.type != InternetAddressType.IPv4) return false;
    final bytes = address.rawAddress;
    if (bytes.length != 4 || bytes[0] != 198) return false;
    // RFC 2544 benchmark range 198.18.0.0/15, commonly used by Clash Fake-IP.
    return bytes[1] == 18 || bytes[1] == 19;
  }
}
