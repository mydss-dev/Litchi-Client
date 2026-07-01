import 'dart:io';

import '../../config/app_identity.dart';
import 'secure_logger.dart';
import 'windows_registry.dart';

/// Manages per-user launch-at-login on Windows and macOS.
///
/// Writes / removes a REG_SZ value under:
///   HKCU\Software\Microsoft\Windows\CurrentVersion\Run
abstract final class AutoStart {
  static const _key = r'Software\Microsoft\Windows\CurrentVersion\Run';
  static String get _name => AppIdentity.autoStartValueName;

  static String get _exePath => Platform.resolvedExecutable;
  static String get _macLaunchAgentLabel =>
      'com.client.${AppIdentity.storageKey}.autostart';

  static String? get _macLaunchAgentPath {
    final home = Platform.environment['HOME'];
    if (home == null || home.isEmpty) return null;
    return '$home/Library/LaunchAgents/$_macLaunchAgentLabel.plist';
  }

  /// Register the current executable to launch at Windows startup.
  static Future<void> enable({bool silent = false}) async {
    try {
      if (Platform.isWindows) {
        WindowsRegistry.writeString(
          _key,
          _name,
          windowsRunCommand(executable: _exePath, silent: silent),
        );
      } else if (Platform.isMacOS) {
        final path = _macLaunchAgentPath;
        if (path == null) return;
        final file = File(path);
        await file.parent.create(recursive: true);
        await file.writeAsString(
          macLaunchAgentPlist(
            label: _macLaunchAgentLabel,
            executable: _exePath,
            silent: silent,
          ),
          flush: true,
        );
      }
    } catch (e) {
      SecureLogger.debug('auto-start enable failed', e);
    }
  }

  /// Remove the auto-start registry entry.
  static Future<void> disable() async {
    try {
      if (Platform.isWindows) {
        WindowsRegistry.deleteValue(_key, _name);
      } else if (Platform.isMacOS) {
        final path = _macLaunchAgentPath;
        if (path == null) return;
        final file = File(path);
        if (await file.exists()) await file.delete();
      }
    } catch (e) {
      SecureLogger.debug('auto-start disable failed', e);
    }
  }

  static String macLaunchAgentPlist({
    required String label,
    required String executable,
    bool silent = false,
  }) {
    final escapedLabel = _xmlEscape(label);
    final escapedExecutable = _xmlEscape(executable);
    return '''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>$escapedLabel</string>
  <key>ProgramArguments</key>
  <array>
    <string>$escapedExecutable</string>
${silent ? '    <string>--silent</string>' : ''}
  </array>
  <key>RunAtLoad</key>
  <true/>
</dict>
</plist>
''';
  }

  static String windowsRunCommand({
    required String executable,
    bool silent = false,
  }) => '"$executable"${silent ? ' --silent' : ''}';

  static String _xmlEscape(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');
}
