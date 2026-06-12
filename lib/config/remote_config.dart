import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

import '../shared/config/app_config.dart';
import 'remote_config_verifier.dart';

/// Fetches brand/API config from OSS and applies it to [AppConfig].
///
/// Strategy: load from cache first (instant, no flash), then refresh in
/// background so the next launch gets the latest values.
abstract final class RemoteConfigService {
  static const _url = 'https://oss.qingniaojiasu.top/config.json';
  static const _cacheKey = 'remote_config_v1';
  static const _timeout = Duration(seconds: 5);

  /// Call once in main(), before runApp().
  ///
  /// Applies cached config immediately (if any), then kicks off a background
  /// HTTP refresh that updates the cache for next launch.
  static Future<void> initialize(SharedPreferences prefs) async {
    // 1. Apply trusted cache immediately so the first frame is correct.
    final cached = prefs.getString(_cacheKey);
    if (cached != null) {
      try {
        final config = await RemoteConfigVerifier.parseTrustedConfig(cached);
        if (config != null) AppConfig.applyRemote(config);
      } catch (_) {}
    }

    // 2. Refresh in background — intentionally not awaited.
    unawaited(_refresh(prefs));
  }

  static Future<void> _refresh(SharedPreferences prefs) async {
    HttpClient? client;
    try {
      client = HttpClient()..connectionTimeout = _timeout;
      final request = await client.getUrl(Uri.parse(_url)).timeout(_timeout);
      request.headers.set('Accept', 'application/json');

      final response = await request.close().timeout(_timeout);
      if (response.statusCode != 200) return;

      final body = await response
          .transform(const Utf8Decoder())
          .join()
          .timeout(_timeout);

      final config = await RemoteConfigVerifier.parseTrustedConfig(body);
      if (config == null) return;

      // Persist the original trusted body for next launch. For signed config,
      // this keeps the signature wrapper so cache is re-verified on every start.
      await prefs.setString(_cacheKey, body);

      // Also apply to current session (colors/text update live if widgets rebuild).
      AppConfig.applyRemote(config);
    } catch (_) {
      // Network unavailable, JSON malformed, or signature invalid — ignore.
    } finally {
      client?.close(force: true);
    }
  }
}
