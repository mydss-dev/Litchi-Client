import 'dart:io';

import '../shared/models/app_models.dart';

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

  static NetworkMode normalizeNetworkModeForPlatform({
    required NetworkMode requested,
    required bool isWindows,
    required bool isMacOS,
    required bool isAndroid,
  }) {
    if (isAndroid) return NetworkMode.tun;
    if (isMacOS) return NetworkMode.system;
    return requested;
  }

  static NetworkMode normalizeNetworkMode(NetworkMode requested) =>
      normalizeNetworkModeForPlatform(
        requested: requested,
        isWindows: isWindows,
        isMacOS: isMacOS,
        isAndroid: isAndroid,
      );

  static bool supportsNetworkMode(NetworkMode mode) =>
      normalizeNetworkMode(mode) == mode;
}
