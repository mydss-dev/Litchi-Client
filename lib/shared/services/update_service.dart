import 'dart:io';

import 'package:crypto/crypto.dart';

import '../../config/app_config.dart';
import '../models/app_models.dart';
import 'secure_logger.dart';

/// Checks for updates by reading [AppConfig.updateVersion] — which is set by
/// the OSS remote config. If the OSS payload includes `update_version`,
/// `update_download_url`, and optionally `update_changelog` / `update_sha256`,
/// the app shows an update banner.
///
/// No separate HTTP fetch. One OSS config file delivers both brand/api config
/// and the latest version info.
abstract final class UpdateService {
  /// Returns [UpdateInfo] if the OSS config declares a newer version than the
  /// currently running one, or null when disabled / already up-to-date.
  static UpdateInfo? check() {
    final latest = AppConfig.updateVersion.trim();
    if (latest.isEmpty) return null;
    final downloadUrl = AppConfig.updateDownloadUrl.trim();
    if (downloadUrl.isEmpty) return null;

    if (!_isNewer(latest, AppConfig.currentVersion)) return null;

    return UpdateInfo(
      version: latest,
      downloadUrl: downloadUrl,
      changelog: AppConfig.updateChangelog.trim(),
      sha256: AppConfig.updateSha256.trim().toLowerCase(),
    );
  }

  /// Downloads the installer to a temp file, optionally verifies its SHA-256
  /// hash, then opens it.  Returns the path on success; throws on failure.
  ///
  /// [onProgress] receives bytes received / total bytes (both ints, total may
  /// be -1 when unknown).  Call only on desktop — Android uses a different
  /// channel (Google Play / APK sideload).
  static Future<String> downloadAndInstall(
    UpdateInfo info, {
    void Function(int received, int total)? onProgress,
  }) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
    try {
      final request = await client.getUrl(Uri.parse(info.downloadUrl));
      final response = await request.close();

      if (response.statusCode != 200) {
        throw Exception('下载失败: HTTP ${response.statusCode}');
      }

      final contentLength = response.contentLength;

      final bytes = <int>[];
      var received = 0;
      await for (final chunk in response) {
        bytes.addAll(chunk);
        received += chunk.length;
        onProgress?.call(received, contentLength);
      }

      // ── Integrity check ────────────────────────────────────────────────────
      if (info.hasHash) {
        final digest = sha256.convert(bytes).toString();
        if (digest != info.sha256) {
          throw Exception(
            '安装包校验失败，文件可能已损坏。\n期望: ${info.sha256}\n实际: $digest',
          );
        }
      }

      // ── Write to temp file ─────────────────────────────────────────────────
      final ext = Platform.isWindows ? '.exe' : '.dmg';
      final tmp = Directory.systemTemp;
      final file = File(
        '${tmp.path}${Platform.pathSeparator}Litchi-Setup-${info.version}$ext',
      );
      await file.writeAsBytes(bytes);

      // ── Launch installer ───────────────────────────────────────────────────
      if (Platform.isWindows) {
        await Process.start(file.path, [], mode: ProcessStartMode.detached);
      } else if (Platform.isMacOS) {
        // macOS: open the DMG
        await Process.run('open', [file.path]);
      }

      return file.path;
    } catch (e) {
      SecureLogger.debug('update download failed', e);
      rethrow;
    } finally {
      client.close();
    }
  }

  static bool _isNewer(String latest, String current) {
    final l = latest.split('.').map((s) => int.tryParse(s) ?? 0).toList();
    final c = current.split('.').map((s) => int.tryParse(s) ?? 0).toList();
    for (int i = 0; i < 3; i++) {
      final lv = i < l.length ? l[i] : 0;
      final cv = i < c.length ? c[i] : 0;
      if (lv > cv) return true;
      if (lv < cv) return false;
    }
    return false;
  }
}
