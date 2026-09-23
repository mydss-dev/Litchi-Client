import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/shared/services/connectivity_check_service.dart';

void main() {
  test('probe reports ok with latency against a 204 endpoint', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) async {
      request.response.statusCode = 204;
      await request.response.close();
    });
    final result = await ConnectivityCheckService.probe(
      ConnectivityTarget(
        name: 'local',
        url: 'http://127.0.0.1:${server.port}/',
      ),
      timeout: const Duration(seconds: 2),
    );
    expect(result.ok, isTrue);
    expect(result.latencyMs, greaterThanOrEqualTo(0));
  });

  test('probe reports failure against a refused endpoint', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final port = server.port;
    await server.close(force: true);
    final result = await ConnectivityCheckService.probe(
      ConnectivityTarget(name: 'dead', url: 'http://127.0.0.1:$port/'),
      timeout: const Duration(seconds: 2),
    );
    expect(result.ok, isFalse);
    expect(result.latencyMs, -1);
  });

  test('probe reports failure when the endpoint exceeds the timeout',
      () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) async {
      await Future<void>.delayed(const Duration(seconds: 5));
      await request.response.close();
    });
    final result = await ConnectivityCheckService.probe(
      ConnectivityTarget(
        name: 'slow',
        url: 'http://127.0.0.1:${server.port}/',
      ),
      timeout: const Duration(milliseconds: 500),
    );
    expect(result.ok, isFalse);
    expect(result.latencyMs, -1);
  });
}
