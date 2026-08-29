import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'app_paths.dart';

/// Copies the embedded sing-box rule sets (geosite-cn / geoip-cn) out of the
/// Flutter asset bundle into the directory the native core resolves relative
/// `rule_set` paths against.
///
/// The config references them as `rule_sets/<name>.srs`; the base directory is
/// the core's working directory on desktop (`AppPaths.dataDirectory`) and
/// libbox's working path on Android. Shipping them as assets instead of
/// downloading from a CDN at startup keeps bootstrapping fully offline.
abstract final class RuleSetAssets {
  static const List<String> assetPaths = [
    'assets/rule_sets/geosite-cn.srs',
    'assets/rule_sets/geoip-cn.srs',
  ];

  /// Directory that holds the extracted `.srs` files, matching the working
  /// directory the native core uses for relative paths.
  static Future<Directory> targetDirectory() async {
    final base = await _coreWorkingDirectory();
    return Directory('${base.path}${Platform.pathSeparator}rule_sets');
  }

  static Future<Directory> _coreWorkingDirectory() async {
    if (Platform.isAndroid) {
      // Mirrors AndroidSingBoxEngine.initialize(): getExternalFilesDir(null)
      // falling back to filesDir. On Android, getApplicationSupportDirectory()
      // maps to filesDir (getApplicationDocumentsDirectory() would map to the
      // filesDir/flutter subdirectory, which libbox does not use).
      final external = await getExternalStorageDirectory();
      if (external != null) return external;
      return getApplicationSupportDirectory();
    }
    return Directory(AppPaths.dataDirectory);
  }

  /// Extracts every rule set asset into [targetDirectory] when missing or out
  /// of date. Idempotent and cheap — safe to call before each core start.
  static Future<void> ensureProvisioned() async {
    final dir = await targetDirectory();
    await dir.create(recursive: true);
    for (final asset in assetPaths) {
      final name = asset.substring(asset.lastIndexOf('/') + 1);
      final target = File('${dir.path}${Platform.pathSeparator}$name');
      final data = await rootBundle.load(asset);
      final bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      if (await target.exists()) {
        if (await target.length() == bytes.length) continue;
      }
      await target.writeAsBytes(bytes, flush: true);
    }
  }
}
