import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/shared/services/android_core_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('litchi/android_core');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test(
    'VPN permission wait times out instead of hanging connection UI',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            channel,
            (_) => Completer<Object?>().future,
          );
      final manager = AndroidCoreManager(
        vpnPermissionTimeout: const Duration(milliseconds: 20),
      );

      expect(await manager.startVpn('{}'), isFalse);
      expect(manager.lastError, contains('超时'));
    },
  );
}
