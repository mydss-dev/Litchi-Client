import 'dart:io';

/// Manages the Windows auto-start registry entry for Litchi.
///
/// Writes / removes a REG_SZ value under:
///   HKCU\Software\Microsoft\Windows\CurrentVersion\Run
abstract final class AutoStart {
  static const _key = r'HKCU\Software\Microsoft\Windows\CurrentVersion\Run';
  static const _name = 'LitchiClient';

  static String get _exePath => Platform.resolvedExecutable;

  /// Register the current executable to launch at Windows startup.
  static Future<void> enable() async {
    if (!Platform.isWindows) return;
    try {
      await Process.run('reg', [
        'add',
        _key,
        '/v',
        _name,
        '/t',
        'REG_SZ',
        '/d',
        '"$_exePath"',
        '/f',
      ]);
    } catch (_) {}
  }

  /// Remove the auto-start registry entry.
  static Future<void> disable() async {
    if (!Platform.isWindows) return;
    try {
      await Process.run('reg', ['delete', _key, '/v', _name, '/f']);
    } catch (_) {}
  }
}
