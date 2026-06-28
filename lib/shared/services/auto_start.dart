import 'dart:io';

import 'secure_logger.dart';
import 'windows_registry.dart';

/// Manages the Windows auto-start registry entry for Litchi.
///
/// Writes / removes a REG_SZ value under:
///   HKCU\Software\Microsoft\Windows\CurrentVersion\Run
abstract final class AutoStart {
  static const _key = r'Software\Microsoft\Windows\CurrentVersion\Run';
  static const _name = 'LitchiClient';

  static String get _exePath => Platform.resolvedExecutable;

  /// Register the current executable to launch at Windows startup.
  static Future<void> enable() async {
    if (!Platform.isWindows) return;
    try {
      WindowsRegistry.writeString(_key, _name, '"$_exePath"');
    } catch (e) {
      SecureLogger.debug('auto-start registry add failed', e);
    }
  }

  /// Remove the auto-start registry entry.
  static Future<void> disable() async {
    if (!Platform.isWindows) return;
    try {
      WindowsRegistry.deleteValue(_key, _name);
    } catch (e) {
      SecureLogger.debug('auto-start registry delete failed', e);
    }
  }
}
