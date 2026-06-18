import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../shared/config/app_config.dart';
import '../shared/services/secure_logger.dart';

/// Fetches brand/API config from OSS and applies it to [AppConfig].
///
/// Only this file needs to be edited when changing the OSS config URL or
/// installing the Ed25519 public key used to verify signed remote config.
abstract final class RemoteConfigService {
  // ── Editable settings ─────────────────────────────────────────────────────

  /// OSS URL for the remote config wrapper or legacy JSON config.
  static const configUrl = 'https://oss.litchi.cfd/config.json';

  /// Ed25519 public key, encoded with base64url without padding.
  ///
  /// Generate once with:
  ///   dart run tool/sign_remote_config.dart generate
  ///
  /// Put PUBLIC_KEY here. Keep PRIVATE_KEY offline and never commit it.
  /// While this is left as the placeholder value, unsigned legacy config is
  /// still accepted for rollout compatibility.
  static const publicKeyBase64Url =
      'czOhtYixrTNEZF0sqhVKoggOtRgmrZNThJryRaJBTBk';

  // ── Internal settings ─────────────────────────────────────────────────────

  static const _cacheKey = 'remote_config_v1';
  static const _timeout = Duration(seconds: 5);

  static bool get _requiresSignature =>
      publicKeyBase64Url.isNotEmpty &&
      !publicKeyBase64Url.startsWith('REPLACE_WITH_');

  /// Call once in main(), before runApp().
  ///
  /// Applies cached config immediately (if any), then kicks off a background
  /// HTTP refresh that updates the cache for next launch.
  static Future<void> initialize(SharedPreferences prefs) async {
    // 1. Apply trusted cache immediately so the first frame is correct.
    final cached = prefs.getString(_cacheKey);
    var applied = false;
    if (cached != null) {
      try {
        final config = await _parseTrustedConfig(cached);
        if (config != null) {
          AppConfig.applyRemote(config);
          applied = true;
        }
      } catch (_) {}
    }

    if (applied) {
      // Have a trusted config already — refresh in the background.
      unawaited(_refresh(prefs));
    } else {
      // First launch / no trusted cache: AWAIT the first fetch (bounded by
      // _timeout) so the real API base is set before the app configures its
      // HTTP client. Otherwise it falls back to the compiled default domain,
      // which may be blocked — leaving login stuck until a restart.
      await _refresh(prefs);
    }
  }

  static Future<void> _refresh(SharedPreferences prefs) async {
    HttpClient? client;
    try {
      client = HttpClient()..connectionTimeout = _timeout;
      final request = await client
          .getUrl(Uri.parse(configUrl))
          .timeout(_timeout);
      request.headers.set('Accept', 'application/json');

      final response = await request.close().timeout(_timeout);
      if (response.statusCode != 200) return;

      final body = await response
          .transform(const Utf8Decoder())
          .join()
          .timeout(_timeout);

      final config = await _parseTrustedConfig(body);
      if (config == null) return;

      // Persist the original trusted body for next launch. For signed config,
      // this keeps the signature wrapper so cache is re-verified on every start.
      await prefs.setString(_cacheKey, body);

      // Also apply to current session (colors/text update live if widgets rebuild).
      AppConfig.applyRemote(config);
    } catch (e) {
      // Network unavailable, JSON malformed, or signature invalid — non-fatal,
      // but record it so a persistently broken remote config is diagnosable.
      SecureLogger.warn('RemoteConfig refresh failed', e);
    } finally {
      client?.close(force: true);
    }
  }

  /// Parses a legacy config or a signed wrapper.
  ///
  /// Signed format:
  /// {
  ///   "payload_b64": "base64url(utf8(jsonPayload))",
  ///   "signature": "base64url(ed25519_signature(payload_bytes))"
  /// }
  static Future<Map<String, dynamic>?> _parseTrustedConfig(String body) async {
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) return null;

    if (_looksSigned(decoded)) {
      return _verifySigned(decoded);
    }

    if (_requiresSignature) return null;
    return decoded;
  }

  static bool _looksSigned(Map<String, dynamic> json) =>
      json['payload_b64'] is String && json['signature'] is String;

  static Future<Map<String, dynamic>?> _verifySigned(
    Map<String, dynamic> wrapper,
  ) async {
    if (!_requiresSignature) return null;

    try {
      final payloadB64 = wrapper['payload_b64'] as String;
      final signatureB64 = wrapper['signature'] as String;
      final payloadBytes = _base64UrlDecode(payloadB64);
      final signatureBytes = _base64UrlDecode(signatureB64);
      final publicKeyBytes = _base64UrlDecode(publicKeyBase64Url);

      final algorithm = Ed25519();
      final publicKey = SimplePublicKey(
        publicKeyBytes,
        type: KeyPairType.ed25519,
      );
      final signature = Signature(signatureBytes, publicKey: publicKey);
      final ok = await algorithm.verify(payloadBytes, signature: signature);
      if (!ok) return null;

      final payload = jsonDecode(utf8.decode(payloadBytes));
      if (payload is! Map<String, dynamic>) return null;
      return payload;
    } catch (_) {
      return null;
    }
  }

  static List<int> _base64UrlDecode(String raw) {
    final normalized = raw.trim().replaceAll('-', '+').replaceAll('_', '/');
    final padded = normalized.padRight(
      normalized.length + ((4 - normalized.length % 4) % 4),
      '=',
    );
    return base64.decode(padded);
  }
}
