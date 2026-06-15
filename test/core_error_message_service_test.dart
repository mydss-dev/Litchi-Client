import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/app/core_error_message_service.dart';

void main() {
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
      CoreErrorMessageService.missingSingBox,
    );
    expect(
      CoreErrorMessageService.androidStartFailure(''),
      CoreErrorMessageService.androidStartFailed,
    );
  });
}
