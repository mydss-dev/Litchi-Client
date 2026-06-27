import '../../config/app_config.dart';
import '../models/app_models.dart';

/// Checks for updates by reading [AppConfig.updateVersion] — which is set by
/// the OSS remote config. If the OSS payload includes `update_version`,
/// `update_download_url`, and optionally `update_changelog`, the app shows an
/// update banner.
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
    );
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
