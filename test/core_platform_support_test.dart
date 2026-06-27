import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/app/core_platform_support.dart';
import 'package:litchi_client/shared/models/app_models.dart';

void main() {
  test('supports Windows, macOS and Android core platforms', () {
    expect(
      CorePlatformSupport.supportsPlatform(
        isWindows: true,
        isMacOS: false,
        isAndroid: false,
      ),
      isTrue,
    );
    expect(
      CorePlatformSupport.supportsPlatform(
        isWindows: false,
        isMacOS: true,
        isAndroid: false,
      ),
      isTrue,
    );
    expect(
      CorePlatformSupport.supportsPlatform(
        isWindows: false,
        isMacOS: false,
        isAndroid: true,
      ),
      isTrue,
    );
    expect(
      CorePlatformSupport.supportsPlatform(
        isWindows: false,
        isMacOS: false,
        isAndroid: false,
      ),
      isFalse,
    );
  });

  test('selects Android or desktop process state by platform', () {
    expect(
      CorePlatformSupport.processRunningFor(
        isAndroid: true,
        androidRunning: true,
        desktopRunning: false,
      ),
      isTrue,
    );
    expect(
      CorePlatformSupport.processRunningFor(
        isAndroid: false,
        androidRunning: true,
        desktopRunning: false,
      ),
      isFalse,
    );
  });

  test('normalizes network interception mode by platform', () {
    NetworkMode normalize(
      NetworkMode requested, {
      bool windows = false,
      bool macos = false,
      bool android = false,
    }) => CorePlatformSupport.normalizeNetworkModeForPlatform(
      requested: requested,
      isWindows: windows,
      isMacOS: macos,
      isAndroid: android,
    );

    expect(normalize(NetworkMode.system, android: true), NetworkMode.tun);
    expect(normalize(NetworkMode.tun, macos: true), NetworkMode.system);
    expect(normalize(NetworkMode.tun, windows: true), NetworkMode.tun);
    expect(normalize(NetworkMode.system, windows: true), NetworkMode.system);
  });
}
