import 'dart:io';

abstract final class CorePlatformSupport {
  static bool get isAndroid => Platform.isAndroid;
  static bool get isWindows => Platform.isWindows;
  static bool get isMacOS => Platform.isMacOS;

  /// Desktop platforms that manage a bundled mihomo subprocess + system proxy.
  static bool get isDesktop => isWindows || isMacOS;

  static bool get supportsCurrentPlatform => supportsPlatform(
    isWindows: isWindows,
    isMacOS: isMacOS,
    isAndroid: isAndroid,
  );

  static bool supportsPlatform({
    required bool isWindows,
    required bool isMacOS,
    required bool isAndroid,
  }) {
    return isWindows || isMacOS || isAndroid;
  }

  static bool processRunningFor({
    required bool isAndroid,
    required bool androidRunning,
    required bool desktopRunning,
  }) {
    return isAndroid ? androidRunning : desktopRunning;
  }
}
