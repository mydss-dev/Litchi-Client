import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/l10n/app_locale_preference.dart';
import 'package:litchi_client/shared/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('removes legacy hidden-settings preferences', () async {
    SharedPreferences.setMockInitialValues({
      'close_connections_on_switch': false,
      'dev_mode': true,
      'node_sort': 'latency',
    });

    await SettingsService.load();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey('close_connections_on_switch'), isFalse);
    expect(prefs.containsKey('dev_mode'), isFalse);
    expect(prefs.containsKey('node_sort'), isFalse);
  });

  test('migrates the legacy localized language label', () async {
    SharedPreferences.setMockInitialValues({'language': '简体中文'});

    final snapshot = await SettingsService.load();

    expect(snapshot.language, AppLocalePreference.simplifiedChinese);
  });

  test('loads the new locale storage keys', () async {
    for (final preference in AppLocalePreference.values) {
      SharedPreferences.setMockInitialValues({
        'language': preference.storageKey,
      });

      final snapshot = await SettingsService.load();

      expect(snapshot.language, preference);
    }
  });

  test(
    'silent startup defaults off and loads an explicit preference',
    () async {
      expect((await SettingsService.load()).silentStart, isFalse);

      SharedPreferences.setMockInitialValues({'silent_start': true});
      expect((await SettingsService.load()).silentStart, isTrue);
    },
  );
}
