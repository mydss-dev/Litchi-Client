import 'dart:io';

import 'package:flutter/services.dart';

import '../../config/app_identity.dart';
import 'secure_logger.dart';
import 'windows_core_process_manager.dart';

/// Controls the runner-owned dynamic WFP session used by the Windows TUN
/// kill switch. The native session automatically removes all filters if the
/// application process exits.
abstract final class WindowsTunKillSwitch {
  static const _channel = MethodChannel('litchi/windows_wfp');
  static String get interfaceAlias => AppIdentity.tunInterfaceAlias;

  static Future<bool> engage() async {
    if (!Platform.isWindows) return true;

    // The isolated litchi-core.exe owns the real proxy-node sockets. It must be
    // the only application-level WFP bypass. Whitelisting Client.exe would let
    // GUI/API traffic escape outside TUN, while failing to whitelist the core
    // would make the kill switch block the proxy connection itself.
    final corePath = WindowsCoreProcessManager.findExecutable();
    if (corePath == null || corePath.isEmpty || !File(corePath).existsSync()) {
      return false;
    }

    try {
      return await _channel.invokeMethod<bool>('engage', {
            'corePath': corePath,
            'interfaceAlias': interfaceAlias,
          }) ??
          false;
    } on MissingPluginException {
      return false;
    } catch (error) {
      SecureLogger.warn('Windows TUN kill switch engage failed', error);
      return false;
    }
  }

  static Future<void> release() async {
    if (!Platform.isWindows) return;
    try {
      await _channel.invokeMethod<bool>('release');
    } on MissingPluginException {
      // Widget/unit tests do not host the Windows runner channel.
    } catch (error) {
      SecureLogger.warn('Windows TUN kill switch release failed', error);
    }
  }
}
