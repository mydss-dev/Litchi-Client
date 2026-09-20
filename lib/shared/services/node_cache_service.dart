import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import '../models/app_models.dart';
import 'app_paths.dart';
import 'credentials_storage.dart';
import 'protected_cache_cleanup.dart';

/// Stores node caches in two tiers:
///
/// 1. UI cache: non-sensitive fields only, safe to keep as plain JSON.
/// 2. Secure cache: complete native outbound payload, platform-protected and
///    bound to the current session (SHA-256 of authData) so a stale file from
///    a previous account cannot be loaded into another session.
///
/// The UI cache keeps the app responsive for display-only fallback. The secure
/// cache lets the client still connect when the panel/API is temporarily
/// unreachable without leaving proxy credentials in plain text on disk.
abstract final class NodeCacheService {
  static String? _testDirectory;

  /// Isolates cache tests from real user data. Assertions are absent in release
  /// builds, so production callers cannot change the cache directory.
  @visibleForTesting
  static void overrideCacheDirectoryForTesting(String? directory) {
    assert(() {
      _testDirectory = directory;
      return true;
    }());
  }

  static String get _baseDirPath => _testDirectory ?? AppPaths.dataDirectory;

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

  static Future<void> save(List<NodeModel> nodes, String authData) {
    final realNodes = nodes.where((n) => !n.isAuto).toList();
    return _pendingMutation = _pendingMutation.then((_) async {
      await Future.wait([
        _saveUiCache(realNodes),
        _saveSecureCache(realNodes, authData),
      ]);
    });
  }

  /// Loads secure cache first because it preserves native outbounds for
  /// actual core startup. Falls back to display-only UI cache when the secure
  /// cache cannot be decrypted or does not belong to the current session.
  ///
  /// The secure cache is session-bound: if its session fingerprint does not
  /// match [authData], the file is deleted and we fall back to the UI cache.
  static Future<List<NodeModel>> load(String authData) async {
    await _pendingMutation;
    final secure = await _loadSecureCache(authData);
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

  static Future<void> _saveSecureCache(
    List<NodeModel> nodes,
    String authData,
  ) async {
    try {
      final payload = jsonEncode({
        'session': _fingerprint(authData),
        'nodes': nodes.map((n) => n.toJson()).toList(),
      });
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

  static Future<List<NodeModel>> _loadSecureCache(String authData) async {
    try {
      final file = File(_secureCachePath);
      if (!file.existsSync()) {
        return await _migrateLegacyPlainCacheIfPresent(authData);
      }
      final encrypted = (await file.readAsString()).trim();
      if (encrypted.isEmpty) return [];
      final decrypted = await CredentialsStorage.unprotectString(encrypted);
      if (decrypted == null || decrypted.isEmpty) return [];
      final json = jsonDecode(decrypted);
      // Session-bound envelope: { "session": "<sha256(authData)>", "nodes": [...] }
      // Legacy unbound format (raw list) is rejected without returning data —
      // we cannot prove it belongs to the current session, so we fail closed
      // and let the next API refresh repopulate it in the bound format.
      if (json is List) {
        // Legacy unbound payload — delete and return empty.
        try {
          await file.delete();
        } catch (_) {}
        return [];
      }
      if (json is Map<String, dynamic>) {
        if (json['session'] != _fingerprint(authData)) {
          // Belongs to another session — drop it so the next account cannot
          // use the previous account's proxy credentials.
          try {
            await file.delete();
          } catch (_) {}
          return [];
        }
        final nodeList = json['nodes'];
        if (nodeList is List) {
          return nodeList
              .map((e) => NodeModel.fromJson(e as Map<String, dynamic>))
              .toList();
        }
      }
      return [];
    } catch (_) {
      // intentional: best-effort cache, failure is safe to ignore
      return [];
    }
  }

  static Future<List<NodeModel>> _loadUiCache() async {
    try {
      final file = File(_uiCachePath);
      if (!file.existsSync()) return [];
      final nodes = _decodeNodeList(await file.readAsString());
      // The UI cache must NEVER carry connectable credentials. The write path
      // (_toPublicJson) strips server/port/rawOutbound, but we enforce the
      // same guarantee on read so a malicious or stale file cannot inject
      // proxy outbounds into the display (and later into the core).
      return _stripAllCredentials(nodes);
    } catch (_) {
      // intentional: best-effort cache, failure is safe to ignore
      return [];
    }
  }

  /// One-time migration from the old plain JSON cache.
  static Future<List<NodeModel>> _migrateLegacyPlainCacheIfPresent(
    String authData,
  ) async {
    try {
      final file = File(_legacyCachePath);
      if (!file.existsSync()) return [];
      final nodes = _decodeNodeList(await file.readAsString());
      if (nodes.isEmpty) return [];
      if (nodes.any((n) => n.hasConfig)) await save(nodes, authData);
      return _stripAllCredentials(nodes);
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

  /// Returns a copy of [nodes] with all connectable fields stripped.
  ///
  /// Used for the UI-cache read path and for legacy-migration fallback so
  /// plaintext cache files can never be turned into live proxy outbounds.
  static List<NodeModel> _stripAllCredentials(List<NodeModel> nodes) =>
      nodes.map(_stripNodeCredentials).toList();

  /// Returns a copy of [node] with server/port/rawOutbound cleared.
  static NodeModel _stripNodeCredentials(NodeModel n) => NodeModel(
    id: n.id,
    name: n.name,
    flag: n.flag,
    code: n.code,
    englishName: n.englishName,
    tags: n.tags,
    favorite: n.favorite,
    region: n.region,
    server: '',
    port: 0,
    isAuto: n.isAuto,
    rawOutbound: null,
    latency: n.latency,
  );

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

  static String _fingerprint(String authData) =>
      sha256.convert(utf8.encode(authData)).toString();
}
