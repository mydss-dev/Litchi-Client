import 'dart:io';

import '../../config/app_identity.dart';

abstract final class AppPaths {
  static String get dataDirectory {
    if (Platform.isWindows) {
      final base =
          Platform.environment['LOCALAPPDATA'] ??
          Platform.environment['APPDATA'] ??
          Directory.systemTemp.path;
      return '$base${Platform.pathSeparator}${AppIdentity.storageDirectoryName}';
    }
    if (Platform.isMacOS) {
      final home = Platform.environment['HOME'];
      final base = home == null || home.isEmpty
          ? Directory.systemTemp.path
          : '$home/Library/Application Support';
      return '$base${Platform.pathSeparator}${AppIdentity.storageDirectoryName}';
    }
    if (Platform.isLinux) {
      final home = Platform.environment['HOME'];
      final xdgDataHome = Platform.environment['XDG_DATA_HOME'];
      final base = xdgDataHome != null && xdgDataHome.isNotEmpty
          ? xdgDataHome
          : home != null && home.isNotEmpty
          ? '$home${Platform.pathSeparator}.local${Platform.pathSeparator}share'
          : Directory.systemTemp.path;
      return '$base${Platform.pathSeparator}${AppIdentity.storageDirectoryName}';
    }
    return '${Directory.systemTemp.path}${Platform.pathSeparator}'
        '${AppIdentity.storageDirectoryName}';
  }
}
