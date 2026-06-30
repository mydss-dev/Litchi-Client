import 'dart:io';

import 'package:crypto/crypto.dart';

import '../../config/app_config.dart';
import '../models/app_models.dart';
import 'secure_logger.dart';

/// Checks for updates by reading [AppConfig.updateVersion] — which is set by
/// the OSS remote config. If the OSS payload includes `update_version`,
/// `update_download_url`, and `update_sha256`, the app shows an update banner.
///
/// No separate HTTP fetch. One OSS config file delivers both brand/api config
/// and the latest version info.
abstract final class UpdateService {
  /// Returns [UpdateInfo] if the OSS config declares a newer version than the
  /// currently running one, or null when disabled / already up-to-date.
  static UpdateInfo? check() {
    if (!AppConfig.updatesEnabled) return null;
    final latest = AppConfig.updateVersion.trim();
    if (latest.isEmpty) return null;
    final downloadUrl = AppConfig.updateDownloadUrl.trim();
    if (downloadUrl.isEmpty) return null;
    final expectedHash = AppConfig.updateSha256.trim().toLowerCase();
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(expectedHash)) {
      SecureLogger.warn(
        'Update metadata ignored: update_sha256 is missing or invalid',
      );
      return null;
    }

    if (!_isNewer(latest, AppConfig.currentVersion)) return null;

    return UpdateInfo(
      version: latest,
      downloadUrl: downloadUrl,
      changelog: AppConfig.updateChangelog.trim(),
      sha256: expectedHash,
    );
  }

  /// Downloads and verifies the installer, then opens it.
  ///
  /// [onProgress] receives bytes received / total bytes (both ints, total may
  /// be -1 when unknown).  Call only on desktop — Android uses a different
  /// channel (Google Play / APK sideload).
  static Future<String> downloadAndInstall(
    UpdateInfo info, {
    void Function(int received, int total)? onProgress,
  }) async {
    if (!Platform.isWindows && !Platform.isMacOS) {
      throw UnsupportedError('In-app installer launch is desktop-only');
    }
    final path = await downloadVerifiedInstaller(info, onProgress: onProgress);
    try {
      if (Platform.isWindows) {
        await Process.start(path, [], mode: ProcessStartMode.detached);
      } else if (Platform.isMacOS) {
        await Process.run('open', [path]);
      }
      return path;
    } catch (e) {
      await _deleteIfExists(File(path));
      SecureLogger.debug('update installer launch failed', e);
      rethrow;
    }
  }

  /// Streams an installer to disk while incrementally calculating SHA-256.
  ///
  /// The expected digest is mandatory. Partial or mismatched files are deleted.
  static Future<String> downloadVerifiedInstaller(
    UpdateInfo info, {
    void Function(int received, int total)? onProgress,
  }) async {
    if (!info.hasHash) {
      throw StateError('更新信息缺少有效的 SHA-256，已拒绝下载安装包');
    }

    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    File? file;
    IOSink? output;
    try {
      final request = await client.getUrl(Uri.parse(info.downloadUrl));
      final response = await request.close();

      if (response.statusCode != 200) {
        throw Exception('下载失败: HTTP ${response.statusCode}');
      }

      final contentLength = response.contentLength;
      final ext = switch (Platform.operatingSystem) {
        'windows' => '.exe',
        'macos' => '.dmg',
        _ => throw UnsupportedError('Installer download is desktop-only'),
      };
      final safeVersion = info.version.replaceAll(
        RegExp(r'[^a-zA-Z0-9._-]'),
        '_',
      );
      final safeAppName = AppConfig.appName
          .trim()
          .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]+'), '-')
          .replaceAll(RegExp(r'^[.\s-]+|[.\s-]+$'), '');
      final installerPrefix = safeAppName.isEmpty ? 'Client' : safeAppName;
      file = File(
        '${Directory.systemTemp.path}${Platform.pathSeparator}'
        '$installerPrefix-Setup-$safeVersion$ext',
      );
      output = file.openWrite(mode: FileMode.writeOnly);

      final digestSink = _DigestSink();
      final hashInput = sha256.startChunkedConversion(digestSink);
      var received = 0;
      await for (final chunk in response) {
        output.add(chunk);
        hashInput.add(chunk);
        received += chunk.length;
        onProgress?.call(received, contentLength);
      }
      await output.flush();
      await output.close();
      output = null;
      hashInput.close();

      final digest = digestSink.value.toString();
      if (digest != info.sha256.toLowerCase()) {
        throw Exception('安装包校验失败，文件可能已损坏。\n期望: ${info.sha256}\n实际: $digest');
      }

      return file.path;
    } catch (e) {
      if (output != null) {
        try {
          await output.close();
        } catch (_) {
          // Preserve the original download/verification error.
        }
      }
      if (file != null) await _deleteIfExists(file);
      SecureLogger.debug('update download failed', e);
      rethrow;
    } finally {
      client.close(force: true);
    }
  }

  static Future<void> _deleteIfExists(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } catch (e) {
      SecureLogger.debug('failed to delete partial update', e);
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

class _DigestSink implements Sink<Digest> {
  Digest? _digest;

  Digest get value => _digest ?? (throw StateError('SHA-256 not finalized'));

  @override
  void add(Digest data) => _digest = data;

  @override
  void close() {}
}
