import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/shared/services/mixed_proxy_port_verifier.dart';

void main() {
  test('accepts a SOCKS5 no-auth handshake', () async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    server.listen((client) {
      client.listen((request) {
        if (request.length >= 3 &&
            request[0] == 0x05 &&
            request[1] == 0x01 &&
            request[2] == 0x00) {
          client.add(const [0x05, 0x00]);
        }
      });
    });

    expect(await MixedProxyPortVerifier.isReady(port: server.port), isTrue);
  });

  test('rejects an unrelated listener', () async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    server.listen((client) {
      client.listen((_) => client.add(const [0x48, 0x54]));
    });

    expect(await MixedProxyPortVerifier.isReady(port: server.port), isFalse);
  });
}
