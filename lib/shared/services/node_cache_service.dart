import 'dart:convert';
import 'dart:io';

import '../models/app_models.dart';
import 'app_paths.dart';
import 'credentials_storage.dart';
import 'protected_cache_cleanup.dart';

/// Stores node caches in two tiers:
///
/// 1. UI cache: non-sensitive fields only, safe to keep as plain JSON.
/// 2. Secure cache: complete native outbound payload, platform-protected.
///
/// The UI cache keeps the app responsive for display-only fallback. The secure
/// cache lets the client still connect when the panel/API is temporarily
/// unreachable without leaving proxy credentials in plain text on disk.
abstract final class NodeCacheService {
  static String get _baseDirPath => AppPaths.dataDirectory;

  static String get _uiCachePath =>
      '$_baseDirPath${Platform.pathSeparator}nodes_cache.json';
  static String get _secureCachePath =>
      '$_baseDirPath${Platform.pathSeparator}secure_nodes_cache.dpapi';
  static String get _legacyCachePath =>
      '$_baseDirPath${Platform.pathSeparator}nodes_cache.json';
  static const String _secureSlot = 'secure_nodes_cache';

  // Data loading deliberately does not await every cache save. Queue writes and
  // deletion so a pending save cannot recreate credentials after logout.
  static Future<void> _pendingMutation = Future<void>.value();

  static Future<void> save(List<NodeModel> nodes) {
    final realNodes = nodes.where((n) => !n.isAuto).toList();
    return _pendingMutation = _pendingMutation.then((_) async {
      await Future.wait([_saveUiCache(realNodes), _saveSecureCache(realNodes)]);
    });
  }

  /// Loads secure cache first because it preserves native outbounds for
  /// actual core startup. Falls back to display-only UI cache when the secure
  /// cache cannot be decrypted or does not exist.
  static Future<List<NodeModel>> load() async {
    await _pendingMutation;
    final secure = await _loadSecureCache();
    if (secure.isNotEmpty) return secure;
    return _loadUiCache();
  }

  static Future<void> clear() {
    return _pendingMutation = _pendingMutation.then((_) async {
      for (final path in [_uiCachePath, _secureCachePath]) {
        try {
          final file = File(path);
          if (file.existsSync()) await file.delete();
        } catch (_) {
          // Best effort: continue to revoke the separate secure-storage slot.
        }
      }
      try {
        await ProtectedCacheCleanup.deleteSlot(_secureSlot);
      } catch (_) {
        // Logout must still complete if the OS key store is unavailable.
      }
    });
  }

  static Future<void> _saveUiCache(List<NodeModel> nodes) async {
    try {
      final file = File(_uiCachePath);
      await file.parent.create(recursive: true);
      await file.writeAsString(
        jsonEncode(nodes.map(_toPublicJson).toList()),
        flush: true,
      );
    } catch (_) {
      // intentional: best-effort cache, failure is safe to ignore
    }
  }

  static Future<void> _saveSecureCache(List<NodeModel> nodes) async {
    try {
      final payload = jsonEncode(nodes.map((n) => n.toJson()).toList());
      final encrypted = await CredentialsStorage.protectString(
        payload,
        slot: _secureSlot,
      );
      if (encrypted == null || encrypted.isEmpty) return;
      final file = File(_secureCachePath);
      await file.parent.create(recursive: true);
      await file.writeAsString(encrypted, flush: true);
    } catch (_) {
      // intentional: best-effort cache, failure is safe to ignore
    }
  }

  static Future<List<NodeModel>> _loadSecureCache() async {
    try {
      final file = File(_secureCachePath);
      if (!file.existsSync()) {
        return await _migrateLegacyPlainCacheIfPresent();
      }
      final encrypted = (await file.readAsString()).trim();
      if (encrypted.isEmpty) return [];
      final decrypted = await CredentialsStorage.unprotectString(encrypted);
      if (decrypted == null || decrypted.isEmpty) return [];
      return _decodeNodeList(decrypted);
    } catch (_) {
      // intentional: best-effort cache, failure is safe to ignore
      return [];
    }
  }

  static Future<List<NodeModel>> _loadUiCache() async {
    try {
      final file = File(_uiCachePath);
      if (!file.existsSync()) return [];
      return _decodeNodeList(await file.readAsString());
    } catch (_) {
      // intentional: best-effort cache, failure is safe to ignore
      return [];
    }
  }

  /// One-time migration from the old plain JSON cache.
  static Future<List<NodeModel>> _migrateLegacyPlainCacheIfPresent() async {
    try {
      final file = File(_legacyCachePath);
      if (!file.existsSync()) return [];
      final nodes = _decodeNodeList(await file.readAsString());
      if (nodes.isEmpty) return [];
      if (nodes.any((n) => n.hasConfig)) await save(nodes);
      return nodes;
    } catch (_) {
      // intentional: best-effort cache, failure is safe to ignore
      return [];
    }
  }

  static List<NodeModel> _decodeNodeList(String raw) {
    final list = jsonDecode(raw) as List;
    return list
        .map((e) => NodeModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Map<String, dynamic> _toPublicJson(NodeModel n) => {
    'id': n.id,
    'name': n.name,
    'flag': n.flag,
    'code': n.code,
    'englishName': n.englishName,
    'tags': n.tags,
    'favorite': n.favorite,
    'region': n.region.name,
    'server': '',
    'port': 0,
    'isAuto': n.isAuto,
  };
}
