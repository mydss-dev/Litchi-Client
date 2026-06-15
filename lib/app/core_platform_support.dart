import 'dart:io';

abstract final class CorePlatformSupport {
  static bool get isAndroid => Platform.isAndroid;
  static bool get isWindows => Platform.isWindows;

  static bool get supportsCurrentPlatform =>
      supportsPlatform(isWindows: isWindows, isAndroid: isAndroid);

  static bool supportsPlatform({
    required bool isWindows,
    required bool isAndroid,
  }) {
    return isWindows || isAndroid;
  }

  static bool processRunningFor({
    required bool isAndroid,
    required bool androidRunning,
    required bool desktopRunning,
  }) {
    return isAndroid ? androidRunning : desktopRunning;
  }
}
