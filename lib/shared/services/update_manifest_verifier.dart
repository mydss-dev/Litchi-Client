import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'secure_logger.dart';
import 'signed_payload_verifier.dart';

/// Independent trust root for the signed update manifest (`update-v2.json`).
///
/// The update manifest is verified exclusively against [publicKeyBase64Url] and,
/// during signing-key rotation, [previousPublicKeyBase64Url]. It must NEVER fall
/// back to the remote-config key — doing so would re-join the two trust roots
/// that P0-2 separates.
abstract final class UpdateManifestVerifier {
  /// Current Ed25519 public key (base64url, unpadded) that verifies the update
  /// manifest. Set at build time via `--dart-define=UPDATE_PUBLIC_KEY=...`.
  /// Manifest-based updates are disabled until this is a valid 32-byte key.
  static const publicKeyBase64Url = String.fromEnvironment('UPDATE_PUBLIC_KEY');

  /// Previous update-signing Ed25519 public key, accepted alongside
  /// [publicKeyBase64Url] during key rotation. Empty when no rotation is in
  /// progress.
  static const previousPublicKeyBase64Url =
      String.fromEnvironment('UPDATE_PREVIOUS_PUBLIC_KEY');

  static const _timeout = Duration(seconds: 5);

  static bool get isConfigured {
    try {
      return SignedPayloadVerifier.base64UrlDecode(
        publicKeyBase64Url,
      ).length == 32;
    } catch (_) {
      return false;
    }
  }

  /// Fetches and verifies the signed update manifest at [url] against the
  /// update-signing trust root only. Returns null on any failure (fail closed).
  static Future<Map<String, dynamic>?> fetchVerifiedPayload(String url) async {
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
      return await verifyAndParse(body);
    } catch (e) {
      SecureLogger.warn('Update manifest fetch failed', e);
      return null;
    } finally {
      client?.close(force: true);
    }
  }

  /// Verifies a signed manifest [body] against [publicKeysBase64Url] (defaults
  /// to the compiled update-signing trust keys).
  ///
  /// Exposed for tests to lock in trust-domain isolation: an update manifest
  /// must verify only with the update-signing key, never the remote-config key.
  @visibleForTesting
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
