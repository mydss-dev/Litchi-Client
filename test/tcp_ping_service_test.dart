import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/shared/services/tcp_ping_service.dart';

void main() {
  test('returns a non-negative latency for a reachable port', () async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close());
    server.listen((s) => s.destroy());

    final ms = await TcpPingService.ping('127.0.0.1', server.port);
    expect(ms, isNotNull);
    expect(ms, greaterThanOrEqualTo(0));
  });

  test('returns null for a closed port', () async {
    // Bind then immediately close to obtain a port nothing listens on.
    final probe = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = probe.port;
    await probe.close();

    final ms = await TcpPingService.ping(
      '127.0.0.1',
      port,
      timeout: const Duration(milliseconds: 500),
    );
    expect(ms, isNull);
  });

  test('returns null for invalid input', () async {
    expect(await TcpPingService.ping('', 443), isNull);
    expect(await TcpPingService.ping('127.0.0.1', 0), isNull);
    expect(await TcpPingService.ping('127.0.0.1', 70000), isNull);
  });
}
