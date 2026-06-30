import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/config/app_config.dart';
import 'package:litchi_client/config/remote_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('has no shared remote-config trust anchor by default', () {
    expect(RemoteConfigService.configUrl, isEmpty);
    expect(RemoteConfigService.publicKeyBase64Url, isEmpty);
    expect(RemoteConfigService.isConfigured, isFalse);
  });

  test('fail-closed defaults do not apply an unsigned cached config', () async {
    final originalName = AppConfig.appName;
    addTearDown(() => AppConfig.appName = originalName);
    SharedPreferences.setMockInitialValues({
      'remote_config_v1': '{"app_name":"untrusted"}',
    });
    final prefs = await SharedPreferences.getInstance();

    await RemoteConfigService.initialize(prefs);

    expect(AppConfig.appName, originalName);
  });

  test('notifies long-lived services only when effective config changes', () {
    final originalName = AppConfig.appName;
    addTearDown(() => AppConfig.appName = originalName);
    final before = AppConfig.revision.value;
    final changedName = '${originalName}_remote_test';

    AppConfig.applyRemote({'app_name': changedName});
    expect(AppConfig.appName, changedName);
    expect(AppConfig.revision.value, before + 1);

    AppConfig.applyRemote({'app_name': changedName});
    expect(AppConfig.revision.value, before + 1);
  });

  test('anti-rollback accepts migration then rejects older payloads', () {
    expect(
      RemoteConfigVersionPolicy.accepts(candidate: null, acceptedVersion: 0),
      isTrue,
    );
    expect(
      RemoteConfigVersionPolicy.accepts(candidate: 12, acceptedVersion: 12),
      isTrue,
    );
    expect(
      RemoteConfigVersionPolicy.accepts(candidate: 11, acceptedVersion: 12),
      isFalse,
    );
    expect(
      RemoteConfigVersionPolicy.accepts(candidate: null, acceptedVersion: 12),
      isFalse,
    );
  });
}
