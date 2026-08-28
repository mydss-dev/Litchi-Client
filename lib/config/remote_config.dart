import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

import 'app_config.dart';
import 'app_identity.dart';
import '../shared/services/secure_logger.dart';
import '../shared/services/signed_payload_verifier.dart';

/// Fetches brand/API config from OSS and applies it to [AppConfig].
///
/// Only this file needs to be edited when changing the OSS config URL or
/// installing the Ed25519 public key used to verify signed remote config.
abstract final class RemoteConfigService {
  /// Self-hosted setup: pass these at build time via
  /// --dart-define=REMOTE_CONFIG_URL=... --dart-define=REMOTE_CONFIG_PUBLIC_KEY=...
  ///
  /// [configUrl] is the HTTPS URL of the signed remote config (`config.json`),
  /// which lives at the R2 bucket root alongside `update.json`. The client
  /// derives the update-manifest URL as its sibling of [configUrl].
  ///
  /// [publicKeyBase64Url] is the Ed25519 public key (base64url, unpadded) that
  /// verifies the remote config only — never the update manifest. Both the URL
  /// and the key must be set for remote config to be enabled; a missing or
  /// invalid key disables it entirely (fail closed).
  ///
  /// Generate the keypair once with:
  ///   dart run tool/sign_remote_config.dart generate
  ///
  /// Store the public key in a CI variable (REMOTE_CONFIG_PUBLIC_KEY) and keep
  /// the private key offline.
  static const configUrl = String.fromEnvironment('REMOTE_CONFIG_URL');
  static const publicKeyBase64Url =
      String.fromEnvironment('REMOTE_CONFIG_PUBLIC_KEY');

  /// Previous Ed25519 public key, accepted alongside [publicKeyBase64Url]
  /// during key rotation so configs signed with the outgoing key keep verifying
  /// while new releases (which bake in the incoming key) roll out. Empty when
  /// no rotation is in progress.
  static const previousPublicKeyBase64Url =
      String.fromEnvironment('REMOTE_CONFIG_PREVIOUS_PUBLIC_KEY');

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
      return SignedPayloadVerifier.base64UrlDecode(publicKeyBase64Url).length ==
          32;
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

  /// Parses and verifies a signed config wrapper, accepting only the
  /// remote-config trust keys. Returns the decoded payload map, or null when
  /// the body is malformed, unsigned, or its signature does not verify.
  static Future<Map<String, dynamic>?> _parseTrustedConfig(String body) async {
    if (!isConfigured) return null;
    return verifyAndParse(body);
  }

  /// Verifies [body] against [publicKeysBase64Url] (defaults to the compiled
  /// remote-config trust keys).
  ///
  /// Exposed for tests to lock in trust-domain isolation: a remote-config
  /// payload must verify only with the remote-config key, never the
  /// update-manifest key.
  static Future<Map<String, dynamic>?> verifyAndParse(
    String body, {
    List<String>? publicKeysBase64Url,
  }) {
    return SignedPayloadVerifier.verifyAndParse(
      body: body,
      publicKeysBase64Url: publicKeysBase64Url ?? _trustedKeys,
    );
  }

  static List<String> get _trustedKeys => <String>[
    publicKeyBase64Url,
    if (previousPublicKeyBase64Url.trim().isNotEmpty)
      previousPublicKeyBase64Url,
  ];
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
