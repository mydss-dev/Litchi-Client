import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/shared/services/local_port_allocator.dart';

void main() {
  test('keeps the preferred port when it is available', () async {
    final probe = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = probe.port;
    await probe.close();

    expect(await LocalPortAllocator.choose(preferred: port), port);
  });

  test('chooses another port when the preferred port is occupied', () async {
    final occupied = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(occupied.close);

    final selected = await LocalPortAllocator.choose(preferred: occupied.port);

    expect(selected, isNot(occupied.port));
    final verification = await ServerSocket.bind(
      InternetAddress.loopbackIPv4,
      selected,
    );
    await verification.close();
  });
}
