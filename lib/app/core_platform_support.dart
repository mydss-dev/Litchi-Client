import 'dart:io';

import '../shared/models/app_models.dart';

abstract final class CorePlatformSupport {
  static bool get isAndroid => Platform.isAndroid;
  static bool get isWindows => Platform.isWindows;
  static bool get isMacOS => Platform.isMacOS;
  static bool get isLinux => Platform.isLinux;

  /// Desktop platforms that load the bundled sing-box dynamic library.
  static bool get isDesktop => isWindows || isMacOS || isLinux;

  static bool get supportsCurrentPlatform => supportsPlatform(
    isWindows: isWindows,
    isMacOS: isMacOS,
    isAndroid: isAndroid,
    isLinux: isLinux,
  );

  static bool supportsPlatform({
    required bool isWindows,
    required bool isMacOS,
    required bool isAndroid,
    bool isLinux = false,
  }) {
    return isWindows || isMacOS || isAndroid || isLinux;
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
    bool isLinux = false,
  }) {
    if (isAndroid) return NetworkMode.tun;
    // Linux system-proxy integration is not implemented; TUN is functional.
    if (isLinux) return NetworkMode.tun;
    return requested;
  }

  static NetworkMode normalizeNetworkMode(NetworkMode requested) =>
      normalizeNetworkModeForPlatform(
        requested: requested,
        isWindows: isWindows,
        isMacOS: isMacOS,
        isAndroid: isAndroid,
        isLinux: isLinux,
      );

  static bool supportsNetworkMode(NetworkMode mode) =>
      normalizeNetworkMode(mode) == mode;
}
