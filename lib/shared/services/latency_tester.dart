import 'dart:io';

/// Measures TCP-handshake latency to a proxy server.
/// Used when the core is not running to give a basic reachability indicator.
/// Returns milliseconds, or [unreachable] on timeout / error.
class LatencyTester {
  static const int unreachable = 9999;
  static const int _timeout    = 3000;

  static Future<int> ping(String host, int port) async {
    if (host.isEmpty || port == 0) return unreachable;
    final sw = Stopwatch()..start();
    try {
      final socket = await Socket.connect(
        host,
        port,
        timeout: const Duration(milliseconds: _timeout),
      );
      sw.stop();
      socket.destroy();
      return sw.elapsedMilliseconds;
    } catch (_) {
      return unreachable;
    }
  }
}
