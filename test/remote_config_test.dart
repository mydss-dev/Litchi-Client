import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/config/app_config.dart';
import 'package:litchi_client/config/remote_config.dart';

void main() {
  test('uses the production OSS remote config by default', () {
    expect(RemoteConfigService.configUrl, 'https://oss.litchi.cfd/config.json');
    expect(
      RemoteConfigService.publicKeyBase64Url,
      'b0nnSjObRhQe3l2ZOeSacmTbNMI0I4qf4_3g01lTK6I',
    );
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
}
