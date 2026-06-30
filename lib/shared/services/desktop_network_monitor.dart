import 'dart:async';
import 'dart:io';

import 'secure_logger.dart';

class DesktopNetworkMonitor {
  DesktopNetworkMonitor({this.interval = const Duration(seconds: 5)});

  final Duration interval;
  Timer? _timer;
  String? _signature;
  bool _checking = false;
  Future<void> Function()? _onChanged;

  bool get isSupported => Platform.isWindows || Platform.isMacOS;

  Future<void> start(Future<void> Function() onChanged) async {
    if (!isSupported || _timer != null) return;
    _onChanged = onChanged;
    _signature = await currentSignature();
    _timer = Timer.periodic(interval, (_) => unawaited(checkNow()));
  }

  Future<void> checkNow({bool notifyEvenIfUnchanged = false}) async {
    if (!isSupported || _checking) return;
    _checking = true;
    try {
      final next = await currentSignature();
      final changed = _signature != null && next != _signature;
      _signature = next;
      if (changed || notifyEvenIfUnchanged) await _onChanged?.call();
    } catch (error) {
      SecureLogger.debug('desktop network check failed', error);
    } finally {
      _checking = false;
    }
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
    _onChanged = null;
  }

  static Future<String> currentSignature() async {
    final interfaces = await NetworkInterface.list(
      includeLoopback: false,
      includeLinkLocal: false,
      type: InternetAddressType.any,
    );
    final entries = <String>[
      for (final interface in interfaces)
        for (final address in interface.addresses)
          '${interface.name}:${address.type.name}:${address.address}',
    ]..sort();
    return entries.join('|');
  }
}
