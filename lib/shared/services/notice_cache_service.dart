import 'dart:convert';
import 'dart:io';

import '../models/api_models.dart';
import 'app_paths.dart';

/// Best-effort disk cache for notices, mirroring [NodeCacheService]'s UI tier.
///
/// Notices are non-sensitive, so a single plain-JSON file is enough. It lets
/// the banner render instantly from the previous fetch while the panel's
/// `/user/notice/fetch` call is still in flight, and keeps the last known
/// notices when the server is briefly unreachable.
abstract final class NoticeCacheService {
  static String get _cachePath =>
      '${AppPaths.dataDirectory}${Platform.pathSeparator}notices_cache.json';

  static Future<void> save(List<NoticeModel> notices) async {
    try {
      final file = File(_cachePath);
      await file.parent.create(recursive: true);
      await file.writeAsString(
        jsonEncode(notices.map((n) => n.toJson()).toList()),
        flush: true,
      );
    } catch (_) {
      // intentional: best-effort cache, failure is safe to ignore
    }
  }

  static Future<List<NoticeModel>> load() async {
    try {
      final file = File(_cachePath);
      if (!file.existsSync()) return [];
      final list = jsonDecode(await file.readAsString()) as List;
      return list
          .map((e) => NoticeModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      // intentional: best-effort cache, failure is safe to ignore
      return [];
    }
  }

  static Future<void> clear() async {
    try {
      final file = File(_cachePath);
      if (file.existsSync()) await file.delete();
    } catch (_) {
      // intentional: best-effort cache, failure is safe to ignore
    }
  }
}
