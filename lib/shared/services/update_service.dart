import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../models/app_models.dart';

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
    if (AppConfig.updateCheckUrl.isEmpty) return null;
    try {
      final res = await _dio.get<Map<String, dynamic>>(AppConfig.updateCheckUrl);
      final data = res.data;
      if (data == null) return null;
      final latest = data['version']?.toString() ?? '';
      if (!_isNewer(latest, AppConfig.currentVersion)) return null;
      return UpdateInfo(
        version: latest,
        downloadUrl: data['download_url']?.toString() ?? '',
        changelog: data['changelog']?.toString() ?? '',
      );
    } catch (_) {
      return null;
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
