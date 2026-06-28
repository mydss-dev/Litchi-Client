import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/app/core_error_message_service.dart';

void main() {
  test('constants contain expected Chinese keywords', () {
    expect(CoreErrorMessageService.noAvailableNodes, contains('没有可用节点'));
    expect(CoreErrorMessageService.configBuildFailed, contains('生成配置失败'));
    expect(CoreErrorMessageService.restartClient, contains('连接失败'));
    expect(CoreErrorMessageService.missingCore, contains('mihomo'));
    expect(CoreErrorMessageService.permissionDenied, contains('管理员'));
    expect(CoreErrorMessageService.androidStartFailed, contains('Android'));
    expect(CoreErrorMessageService.unexpectedCoreExit, contains('异常退出'));
  });

  test('maps Windows permission failures to admin hint', () {
    expect(
      CoreErrorMessageService.windowsStartException('Access is denied'),
      CoreErrorMessageService.permissionDenied,
    );
    expect(
      CoreErrorMessageService.windowsStartException('permission denied'),
      CoreErrorMessageService.permissionDenied,
    );
  });

  test('maps generic Windows start failures to restart hint', () {
    expect(
      CoreErrorMessageService.windowsStartException('unexpected failure'),
      CoreErrorMessageService.restartClient,
    );
  });

  test('preserves platform last errors when available', () {
    expect(
      CoreErrorMessageService.processStartFailure('custom core error'),
      'custom core error',
    );
    expect(
      CoreErrorMessageService.androidStartFailure('vpn permission denied'),
      'vpn permission denied',
    );
  });

  test('uses default platform messages when last error is empty', () {
    expect(
      CoreErrorMessageService.processStartFailure(''),
      CoreErrorMessageService.missingCore,
    );
    expect(
      CoreErrorMessageService.androidStartFailure(''),
      CoreErrorMessageService.androidStartFailed,
    );
  });
}
