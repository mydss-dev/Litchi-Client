import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_config.dart';
import '../shared/services/secure_logger.dart';

/// Fetches brand/API config from OSS and applies it to [AppConfig].
///
/// Only this file needs to be edited when changing the OSS config URL or
/// installing the Ed25519 public key used to verify signed remote config.
abstract final class RemoteConfigService {
  // ── Editable settings ─────────────────────────────────────────────────────

  /// HTTPS config URL compiled into this tenant's package.
  ///
  /// Deliberately empty by default: every tenant must provide its own endpoint.
  static const configUrl = String.fromEnvironment(
    'REMOTE_CONFIG_URL',
    defaultValue: '',
  );

  /// Ed25519 public key, encoded with base64url without padding.
  ///
  /// Generate once with:
  ///   dart run tool/sign_remote_config.dart generate
  ///
  /// Supply this through `REMOTE_CONFIG_PUBLIC_KEY`. Keep the private key
  /// offline. There is deliberately no shared default trust anchor.
  static const publicKeyBase64Url = String.fromEnvironment(
    'REMOTE_CONFIG_PUBLIC_KEY',
    defaultValue: '',
  );

  /// Fallback key for key-rotation scenarios.  When the primary key is
  /// compromised and must be replaced, follow this procedure:
  ///
  /// 1. Generate a new key pair; set the new public key as
  ///    [fallbackPublicKeyBase64Url] and ship a client update.
  /// 2. After enough clients have updated, switch the bot to the new key
  ///    and move the new public key to [publicKeyBase64Url] in the next
  ///    client release.
  /// 3. Clear [fallbackPublicKeyBase64Url] once the old key is fully retired.
  ///
  /// An empty value disables the fallback.
  static const fallbackPublicKeyBase64Url = String.fromEnvironment(
    'REMOTE_CONFIG_FALLBACK_PUBLIC_KEY',
    defaultValue: '',
  );

  // ── Internal settings ─────────────────────────────────────────────────────

  static const _cacheKey = 'remote_config_v1';
  static const _timeout = Duration(seconds: 5);

  /// Maximum time the *first* launch will block on the remote config fetch
  /// before continuing with the compiled default. The fetch still runs to
  /// completion in the background and updates the cache for the next launch.
  static const _firstLaunchBudget = Duration(milliseconds: 1500);

  static bool get isConfigured {
    final uri = Uri.tryParse(configUrl.trim());
    if (uri == null || uri.scheme != 'https' || !uri.hasAuthority) return false;
    try {
      return _base64UrlDecode(publicKeyBase64Url).length == 32;
    } catch (_) {
      return false;
    }
  }

  /// Call once in main(), before runApp().
  ///
  /// Applies cached config immediately (if any), then kicks off a background
  /// HTTP refresh that updates the cache for next launch.
  static Future<void> initialize(SharedPreferences prefs) async {
    if (!isConfigured) {
      SecureLogger.warn(
        'Remote config disabled: tenant HTTPS URL or Ed25519 key is missing',
      );
      return;
    }

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
      } catch (_) {
        // intentional: parse attempt, fallback handled below
      }
    }

    if (applied) {
      // Have a trusted config already — refresh in the background.
      unawaited(_refresh(prefs));
    } else {
      // First launch / no trusted cache: briefly wait for the first fetch so
      // the real API base is set before the app configures its HTTP client,
      // but bound that wait so a slow or blocked OSS endpoint cannot stall the
      // first frame. If it overruns, the fetch keeps running in the background
      // and the compiled default is used for this session; the next launch
      // picks up the cached config.
      final refresh = _refresh(prefs);
      await refresh.timeout(
        _firstLaunchBudget,
        onTimeout: () => unawaited(refresh),
      );
    }
  }

  static Future<void> _refresh(SharedPreferences prefs) async {
    if (!isConfigured) return;
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

      // Also apply to current session.
      AppConfig.applyRemote(config);
    } catch (e) {
      // Network unavailable, JSON malformed, or signature invalid — non-fatal,
      // but record it so a persistently broken remote config is diagnosable.
      SecureLogger.warn('RemoteConfig refresh failed', e);
    } finally {
      client?.close(force: true);
    }
  }

  /// Parses a signed config wrapper.
  ///
  /// Signed format:
  /// {
  ///   "payload_b64": "base64url(utf8(jsonPayload))",
  ///   "signature": "base64url(ed25519_signature(payload_bytes))"
  /// }
  static Future<Map<String, dynamic>?> _parseTrustedConfig(String body) async {
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) return null;
    if (!isConfigured || !_looksSigned(decoded)) return null;
    return _verifySigned(decoded);
  }

  static bool _looksSigned(Map<String, dynamic> json) =>
      json['payload_b64'] is String && json['signature'] is String;

  static Future<Map<String, dynamic>?> _verifySigned(
    Map<String, dynamic> wrapper,
  ) async {
    if (!isConfigured) return null;

    try {
      final payloadB64 = wrapper['payload_b64'] as String;
      final signatureB64 = wrapper['signature'] as String;
      final payloadBytes = _base64UrlDecode(payloadB64);
      final signatureBytes = _base64UrlDecode(signatureB64);

      final algorithm = Ed25519();
      final keys = [
        _base64UrlDecode(publicKeyBase64Url),
        if (fallbackPublicKeyBase64Url.isNotEmpty)
          _base64UrlDecode(fallbackPublicKeyBase64Url),
      ];

      var ok = false;
      for (final keyBytes in keys) {
        final publicKey = SimplePublicKey(keyBytes, type: KeyPairType.ed25519);
        final signature = Signature(signatureBytes, publicKey: publicKey);
        ok = await algorithm.verify(payloadBytes, signature: signature);
        if (ok) break;
      }
      if (!ok) return null;

      final payload = jsonDecode(utf8.decode(payloadBytes));
      if (payload is! Map<String, dynamic>) return null;
      return payload;
    } catch (_) {
      // intentional: parse attempt, fallback handled below
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
