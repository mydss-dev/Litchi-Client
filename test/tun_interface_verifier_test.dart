import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/shared/services/tun_interface_verifier.dart';

void main() {
  test('returns true when the requested TUN interface appears', () async {
    var attempts = 0;
    final ready = await TunInterfaceVerifier.waitUntilReady(
      timeout: const Duration(milliseconds: 100),
      pollInterval: Duration.zero,
      probe: () async {
        attempts += 1;
        return attempts < 2 ? const ['Ethernet'] : const ['Ethernet', 'Litchi'];
      },
    );

    expect(ready, isTrue);
    expect(attempts, 2);
  });

  test('returns false when the TUN interface never appears', () async {
    final ready = await TunInterfaceVerifier.waitUntilReady(
      timeout: Duration.zero,
      pollInterval: Duration.zero,
      probe: () async => const ['Ethernet'],
    );

    expect(ready, isFalse);
  });
}
