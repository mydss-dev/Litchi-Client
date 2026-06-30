import 'dart:io';

import 'package:flutter/services.dart';

import '../../config/app_identity.dart';
import 'core_manager.dart';
import 'secure_logger.dart';

/// Controls the runner-owned dynamic WFP session used by the Windows TUN
/// kill switch. The native session automatically removes all filters if the
/// application process exits.
abstract final class WindowsTunKillSwitch {
  static const _channel = MethodChannel('litchi/windows_wfp');
  static String get interfaceAlias => AppIdentity.tunInterfaceAlias;

  static Future<bool> engage() async {
    if (!Platform.isWindows) return true;
    final mihomoPath = CoreManager.findExecutable();
    if (mihomoPath == null || mihomoPath.isEmpty) return false;
    try {
      return await _channel.invokeMethod<bool>('engage', {
            'mihomoPath': mihomoPath,
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
