import 'dart:io';

/// Measures TCP-handshake latency to a proxy server.
/// Returns milliseconds, or 9999 on timeout / unreachable.
class LatencyTester {
  static const int timeout = 3000; // ms
  static const int unreachable = 9999;

  static Future<int> ping(String host, int port) async {
    if (host.isEmpty || port == 0) return unreachable;
    final sw = Stopwatch()..start();
    try {
      final socket = await Socket.connect(
        host,
        port,
        timeout: const Duration(milliseconds: timeout),
      );
      sw.stop();
      socket.destroy();
      return sw.elapsedMilliseconds;
    } catch (_) {
      return unreachable;
    }
  }
}
