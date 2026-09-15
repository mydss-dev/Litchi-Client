import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('SettingsPage delegates to Greenfield Settings', () {
    final source = File(
      'lib/features/settings/settings_page.dart',
    ).readAsStringSync();

    expect(source, contains("import 'greenfield_settings_page.dart';"));
    expect(source, contains('GreenfieldSettingsPage'));
    expect(source, isNot(contains('_SettingsGroup')));
    expect(source, isNot(contains('_DiagnosticButton')));
    expect(source, isNot(contains('_DiagnosticInfoSheet')));
  });

  test('greenfield settings surface keeps a stable runtime marker', () {
    final source = File(
      'lib/features/settings/widgets/greenfield_settings_surface.dart',
    ).readAsStringSync();

    expect(source, contains("ValueKey('greenfield-settings-surface')"));
    expect(source, contains('constraints.maxWidth >= 920'));
    expect(source, isNot(contains('app_locale_preference.dart')));
  });

  test('greenfield settings preserves protected network behavior', () {
    final source = File(
      'lib/features/settings/greenfield_settings_page.dart',
    ).readAsStringSync();

    expect(source, contains('CorePlatformSupport.supportsNetworkMode'));
    expect(source, contains('AppController.checkAdminPrivileges()'));
    expect(source, contains('controller.setNetworkMode(mode)'));
    expect(source, contains('controller.setKillSwitch'));
    expect(source, contains('fixProxy()'));
  });

  test('greenfield diagnostics keeps secure redaction', () {
    final source = File(
      'lib/features/settings/greenfield_settings_page.dart',
    ).readAsStringSync();

    expect(source, contains('SecureLogRedactor.redact'));
    expect(source, contains('diagnosticProxyPort(controller.activeProxyPort)'));
    expect(source, contains('AppConfig.isSecureServer'));
  });
}
