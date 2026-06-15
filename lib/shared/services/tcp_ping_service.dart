import 'dart:io';

/// Lightweight TCP-handshake latency probe.
///
/// Used for pre-connect "测速" — especially on Android, where the sing-box core
/// cannot run without establishing the VpnService tunnel, so the Clash API
/// delay test is unavailable until connected. A TCP connect to the node's
/// `server:port` measures reachability + round-trip without needing the core.
///
/// Note: this is the latency to the node *server*, not the real proxied latency
/// (which the Clash API measures once connected). It is good enough to rank and
/// pick a node before turning the tunnel on.
abstract final class TcpPingService {
  static const Duration defaultTimeout = Duration(seconds: 3);

  /// Returns the TCP handshake time in milliseconds, or null if the host is
  /// unreachable / times out.
  static Future<int?> ping(
    String host,
    int port, {
    Duration timeout = defaultTimeout,
  }) async {
    if (host.isEmpty || port <= 0 || port > 65535) return null;
    final stopwatch = Stopwatch()..start();
    Socket? socket;
    try {
      socket = await Socket.connect(host, port, timeout: timeout);
      stopwatch.stop();
      return stopwatch.elapsedMilliseconds;
    } catch (_) {
      return null;
    } finally {
      socket?.destroy();
    }
  }
}
