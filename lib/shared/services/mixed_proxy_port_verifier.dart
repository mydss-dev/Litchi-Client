import 'dart:async';
import 'dart:io';

/// Confirms that the local mixed-port is serving the SOCKS5 protocol.
///
/// A plain TCP connect is not enough: another process could win the port race
/// after allocation and make a dead system-proxy setup look healthy.
abstract final class MixedProxyPortVerifier {
  static Future<bool> waitUntilReady({
    required int port,
    int attempts = 6,
    Duration retryDelay = const Duration(milliseconds: 100),
    Duration handshakeTimeout = const Duration(milliseconds: 500),
  }) async {
    for (var attempt = 0; attempt < attempts; attempt++) {
      if (await isReady(port: port, timeout: handshakeTimeout)) return true;
      if (attempt + 1 < attempts) await Future<void>.delayed(retryDelay);
    }
    return false;
  }

  static Future<bool> isReady({
    required int port,
    Duration timeout = const Duration(milliseconds: 500),
  }) async {
    Socket? socket;
    StreamSubscription<List<int>>? subscription;
    try {
      socket = await Socket.connect(
        InternetAddress.loopbackIPv4,
        port,
        timeout: timeout,
      );
      final response = <int>[];
      final completed = Completer<bool>();
      subscription = socket.listen(
        (chunk) {
          response.addAll(chunk);
          if (response.length >= 2 && !completed.isCompleted) {
            completed.complete(response[0] == 0x05 && response[1] == 0x00);
          }
        },
        onError: (_) {
          if (!completed.isCompleted) completed.complete(false);
        },
        onDone: () {
          if (!completed.isCompleted) completed.complete(false);
        },
        cancelOnError: true,
      );

      // SOCKS5 greeting: version 5, one auth method, no authentication.
      socket.add(const [0x05, 0x01, 0x00]);
      await socket.flush();
      return await completed.future.timeout(timeout, onTimeout: () => false);
    } catch (_) {
      return false;
    } finally {
      await subscription?.cancel();
      socket?.destroy();
    }
  }
}
