import 'dart:io';

typedef TunInterfaceProbe = Future<Iterable<String>> Function();

/// Waits until the operating system exposes the TUN interface requested by
/// mihomo. A responsive controller alone is not sufficient: mihomo can keep
/// its API alive even when creation of the virtual adapter failed.
abstract final class TunInterfaceVerifier {
  static Future<bool> waitUntilReady({
    String interfaceName = 'Litchi',
    bool matchPrefix = false,
    Set<String> excludedNames = const {},
    Duration timeout = const Duration(seconds: 5),
    Duration pollInterval = const Duration(milliseconds: 200),
    TunInterfaceProbe? probe,
  }) async {
    final readNames = probe ?? _interfaceNames;
    final expected = interfaceName.toLowerCase();
    final excluded = excludedNames.map((name) => name.toLowerCase()).toSet();
    final deadline = DateTime.now().add(timeout);

    do {
      try {
        final names = await readNames();
        if (names.any((name) {
          final normalized = name.toLowerCase();
          if (excluded.contains(normalized)) return false;
          return matchPrefix
              ? normalized.startsWith(expected)
              : normalized == expected;
        })) {
          return true;
        }
      } catch (_) {
        // The interface list can briefly fail while the adapter is being added.
      }
      if (DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(pollInterval);
      }
    } while (DateTime.now().isBefore(deadline));

    return false;
  }

  static Future<Set<String>> matchingInterfaceNames({
    required String interfaceName,
    bool matchPrefix = false,
  }) async {
    final expected = interfaceName.toLowerCase();
    final names = await _interfaceNames();
    return names.where((name) {
      final normalized = name.toLowerCase();
      return matchPrefix
          ? normalized.startsWith(expected)
          : normalized == expected;
    }).toSet();
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
