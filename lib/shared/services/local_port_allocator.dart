import 'dart:io';

/// Chooses a loopback TCP port for a local service.
///
/// The preferred port is kept when available. If another process already owns
/// it, the operating system selects a free ephemeral port instead.
abstract final class LocalPortAllocator {
  static Future<int> choose({required int preferred}) async {
    if (await _isAvailable(preferred)) return preferred;

    ServerSocket? socket;
    try {
      socket = await ServerSocket.bind(
        InternetAddress.loopbackIPv4,
        0,
        shared: false,
      );
      return socket.port;
    } finally {
      await socket?.close();
    }
  }

  static Future<bool> _isAvailable(int port) async {
    ServerSocket? socket;
    try {
      socket = await ServerSocket.bind(
        InternetAddress.loopbackIPv4,
        port,
        shared: false,
      );
      return true;
    } on SocketException {
      return false;
    } finally {
      await socket?.close();
    }
  }
}
