import 'dart:io';

typedef TunInterfaceProbe = Future<Iterable<String>> Function();

/// Waits until the operating system exposes the TUN interface requested by
/// mihomo. A responsive controller alone is not sufficient: mihomo can keep
/// its API alive even when creation of the virtual adapter failed.
abstract final class TunInterfaceVerifier {
  static Future<bool> waitUntilReady({
    String interfaceName = 'Litchi',
    Duration timeout = const Duration(seconds: 5),
    Duration pollInterval = const Duration(milliseconds: 200),
    TunInterfaceProbe? probe,
  }) async {
    final readNames = probe ?? _interfaceNames;
    final expected = interfaceName.toLowerCase();
    final deadline = DateTime.now().add(timeout);

    do {
      try {
        final names = await readNames();
        if (names.any((name) => name.toLowerCase() == expected)) return true;
      } catch (_) {
        // The interface list can briefly fail while the adapter is being added.
      }
      if (DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(pollInterval);
      }
    } while (DateTime.now().isBefore(deadline));

    return false;
  }

  static Future<Iterable<String>> _interfaceNames() async {
    final interfaces = await NetworkInterface.list(
      includeLoopback: false,
      includeLinkLocal: true,
      type: InternetAddressType.any,
    );
    return interfaces.map((item) => item.name);
  }
}
