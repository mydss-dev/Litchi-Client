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

  test('supports macOS utun interface prefixes', () async {
    final ready = await TunInterfaceVerifier.waitUntilReady(
      interfaceName: 'utun',
      matchPrefix: true,
      timeout: Duration.zero,
      probe: () async => const ['lo0', 'utun7'],
    );

    expect(ready, isTrue);
  });

  test('ignores utun interfaces that existed before core startup', () async {
    final ready = await TunInterfaceVerifier.waitUntilReady(
      interfaceName: 'utun',
      matchPrefix: true,
      excludedNames: const {'utun0', 'utun1'},
      timeout: Duration.zero,
      probe: () async => const ['utun0', 'utun1', 'utun2'],
    );

    expect(ready, isTrue);
  });
}
