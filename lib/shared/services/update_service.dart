import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../models/app_models.dart';
import 'api_client.dart';
import 'secure_logger.dart';

abstract final class UpdateService {
  static final _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );

  /// Fetches the version manifest and returns [UpdateInfo] if a newer version
  /// is available, or null if the check is disabled / already up-to-date.
  static Future<UpdateInfo?> check() async {
    // Preferred: update info embedded in the (signed) remote config — no extra
    // network fetch, one source of truth.
    if (AppConfig.latestVersion.isNotEmpty) {
      if (!_isNewer(AppConfig.latestVersion, AppConfig.currentVersion)) {
        return null;
      }
      return UpdateInfo(
        version: AppConfig.latestVersion,
        downloadUrl: AppConfig.downloadUrl,
        changelog: AppConfig.changelog,
      );
    }

    // Fallback: legacy separate manifest at updateCheckUrl.
    if (AppConfig.updateCheckUrl.isEmpty) return null;
    final manifestUri = Uri.tryParse(AppConfig.updateCheckUrl);
    if (manifestUri == null ||
        (manifestUri.scheme != 'https' && manifestUri.scheme != 'http')) {
      SecureLogger.debug('Skip update check: invalid manifest url');
      return null;
    }
    try {
      final res = await _getWithRetry(manifestUri.toString());
      final data = res.data;
      if (data == null) return null;
      final latest = data['version']?.toString() ?? '';
      if (!_isNewer(latest, AppConfig.currentVersion)) return null;
      return UpdateInfo(
        version: latest,
        downloadUrl: data['download_url']?.toString() ?? '',
        changelog: data['changelog']?.toString() ?? '',
      );
    } catch (e) {
      SecureLogger.debug('Update check failed', e);
      return null;
    }
  }

  static Future<Response<Map<String, dynamic>>> _getWithRetry(
    String url,
  ) async {
    var attempt = 0;
    while (true) {
      try {
        return await _dio.get<Map<String, dynamic>>(url);
      } on DioException catch (e) {
        if (attempt >= ApiClient.maxGetRetries ||
            !ApiClient.isRetriableGetError(e)) {
          rethrow;
        }
        attempt += 1;
        await Future.delayed(Duration(milliseconds: 250 * attempt));
      }
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
