import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_config.dart';
import 'app_identity.dart';
import '../shared/services/secure_logger.dart';

/// Fetches brand/API config from OSS and applies it to [AppConfig].
///
/// Only this file needs to be edited when changing the OSS config URL or
/// installing the Ed25519 public key used to verify signed remote config.
abstract final class RemoteConfigService {
  // Self-hosted setup: pass these at build time via
  // --dart-define=REMOTE_CONFIG_URL=... --dart-define=REMOTE_CONFIG_PUBLIC_KEY=...
  // Everything else is read from the signed JSON stored at [configUrl], which
  // must live at the R2 bucket root (the client derives the update-manifest URL
  // as its sibling).
  ///
  /// [configUrl] is the HTTPS URL of the signed config JSON. [publicKeyBase64Url]
  /// is the Ed25519 public key (base64url, unpadded) that verifies it and the
  /// update manifest. Both must be set for remote config to be enabled —
  /// a missing or invalid key disables it entirely (fail closed).
  ///
  /// Generate the keypair once with:
  ///   dart run tool/sign_remote_config.dart generate
  ///
  /// Store the public key in a CI secret (REMOTE_CONFIG_PUBLIC_KEY) and keep
  /// the private key offline.
  static const configUrl = String.fromEnvironment('REMOTE_CONFIG_URL');
  static const publicKeyBase64Url =
      String.fromEnvironment('REMOTE_CONFIG_PUBLIC_KEY');

  // ── Internal settings ─────────────────────────────────────────────────────

  static String get _cacheKey => AppIdentity.preferenceKey('remote_config_v1');
  static String get _versionKey =>
      AppIdentity.preferenceKey('remote_config_version');
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
        'Remote config disabled: OSS HTTPS URL or Ed25519 key is missing',
      );
      return;
    }

    // 1. Apply trusted cache immediately so the first frame is correct.
    final cached = prefs.getString(_cacheKey);
    var acceptedVersion = prefs.getInt(_versionKey) ?? 0;
    var applied = false;
    if (cached != null) {
      try {
        final config = await _parseTrustedConfig(cached);
        if (config != null &&
            RemoteConfigVersionPolicy.accepts(
              candidate: config['config_version'],
              acceptedVersion: acceptedVersion,
            )) {
          AppConfig.applyRemote(config);
          acceptedVersion = RemoteConfigVersionPolicy.versionOf(
            config['config_version'],
          );
          if (acceptedVersion > 0) {
            await prefs.setInt(_versionKey, acceptedVersion);
          }
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
      final acceptedVersion = prefs.getInt(_versionKey) ?? 0;
      if (!RemoteConfigVersionPolicy.accepts(
        candidate: config['config_version'],
        acceptedVersion: acceptedVersion,
      )) {
        SecureLogger.warn('RemoteConfig rejected a rolled-back payload');
        return;
      }

      // Persist the original trusted body for next launch. For signed config,
      // this keeps the signature wrapper so cache is re-verified on every start.
      await prefs.setString(_cacheKey, body);
      final nextVersion = RemoteConfigVersionPolicy.versionOf(
        config['config_version'],
      );
      if (nextVersion > acceptedVersion) {
        await prefs.setInt(_versionKey, nextVersion);
      }

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

  /// Fetches and verifies another signed JSON payload with the configured
  /// compiled trust key. Used by the independently published update manifest.
  static Future<Map<String, dynamic>?> fetchTrustedPayload(String url) async {
    if (!isConfigured) return null;
    final uri = Uri.tryParse(url.trim());
    if (uri == null || uri.scheme != 'https' || !uri.hasAuthority) return null;

    HttpClient? client;
    try {
      client = HttpClient()..connectionTimeout = _timeout;
      final request = await client.getUrl(uri).timeout(_timeout);
      request.headers
        ..set('Accept', 'application/json')
        ..set('Cache-Control', 'no-cache');
      final response = await request.close().timeout(_timeout);
      if (response.statusCode != 200) return null;
      final body = await response
          .transform(const Utf8Decoder())
          .join()
          .timeout(_timeout);
      return await _parseTrustedConfig(body);
    } catch (e) {
      SecureLogger.warn('Signed payload fetch failed', e);
      return null;
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

      final publicKey = SimplePublicKey(
        _base64UrlDecode(publicKeyBase64Url),
        type: KeyPairType.ed25519,
      );
      final signature = Signature(signatureBytes, publicKey: publicKey);
      final ok = await Ed25519().verify(payloadBytes, signature: signature);
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

abstract final class RemoteConfigVersionPolicy {
  static int versionOf(Object? value) {
    if (value is int) return value > 0 ? value : 0;
    if (value is num) {
      final version = value.toInt();
      return version > 0 && value == version ? version : 0;
    }
    if (value is String) {
      final version = int.tryParse(value.trim()) ?? 0;
      return version > 0 ? version : 0;
    }
    return 0;
  }

  static bool accepts({
    required Object? candidate,
    required int acceptedVersion,
  }) {
    final version = versionOf(candidate);
    if (acceptedVersion <= 0) return true;
    return version >= acceptedVersion;
  }
}
