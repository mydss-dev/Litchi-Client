import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/shared/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('removes the legacy close-connections preference', () async {
    SharedPreferences.setMockInitialValues({
      'close_connections_on_switch': false,
    });

    await SettingsService.load();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey('close_connections_on_switch'), isFalse);
  });
}
