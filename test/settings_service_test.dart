import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/shared/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'closes old connections after a node or mode change by default',
    () async {
      expect((await SettingsService.load()).closeConnectionsOnSwitch, isTrue);
    },
  );

  test('persists the close-connections preference', () async {
    SettingsService.setCloseConnectionsOnSwitch(false);
    await Future<void>.delayed(Duration.zero);

    expect((await SettingsService.load()).closeConnectionsOnSwitch, isFalse);
  });
}
