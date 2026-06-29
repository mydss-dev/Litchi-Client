import 'package:flutter_test/flutter_test.dart';
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
    });

    await SettingsService.load();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey('close_connections_on_switch'), isFalse);
    expect(prefs.containsKey('dev_mode'), isFalse);
  });
}
