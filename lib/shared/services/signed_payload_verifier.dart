import 'dart:convert';

import 'package:cryptography/cryptography.dart';

/// Key-agnostic Ed25519 verification of the signed JSON envelope shared by the
/// remote-config and update-manifest trust domains.
///
/// This helper holds NO trust anchor of its own: callers pass the exact public
/// keys they trust. [RemoteConfigService] passes only the remote-config keys and
/// [UpdateManifestVerifier] passes only the update-manifest keys, so the two
/// trust roots can never be crossed through this helper.
abstract final class SignedPayloadVerifier {
  /// Verifies [body] against any one of [publicKeysBase64Url] and returns the
  /// decoded payload map.
  ///
  /// Envelope format:
  /// {
  ///   "payload_b64": "base64url(utf8(jsonPayload))",
  ///   "signature": "base64url(ed25519_signature(payload_bytes))"
  /// }
  ///
  /// Returns null on malformed JSON, a missing/typed signature wrapper, an
  /// undecodable payload, or a signature that no trusted key verifies.
  static Future<Map<String, dynamic>?> verifyAndParse({
    required String body,
    required List<String> publicKeysBase64Url,
  }) async {
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } catch (_) {
      return null;
    }
    if (decoded is! Map<String, dynamic>) return null;
    if (decoded['payload_b64'] is! String ||
        decoded['signature'] is! String) {
      return null;
    }

    final List<int> payloadBytes;
    final List<int> signatureBytes;
    try {
      payloadBytes = base64UrlDecode(decoded['payload_b64'] as String);
      signatureBytes = base64UrlDecode(decoded['signature'] as String);
    } catch (_) {
      return null;
    }

    if (!await verifySignature(
      payloadBytes: payloadBytes,
      signatureBytes: signatureBytes,
      publicKeysBase64Url: publicKeysBase64Url,
    )) {
      return null;
    }

    try {
      final payload = jsonDecode(utf8.decode(payloadBytes));
      if (payload is! Map<String, dynamic>) return null;
      return payload;
    } catch (_) {
      return null;
    }
  }

  /// Verifies [signatureBytes] over [payloadBytes] against any one of
  /// [publicKeysBase64Url]. Empty or undecodable keys are skipped.
  static Future<bool> verifySignature({
    required List<int> payloadBytes,
    required List<int> signatureBytes,
    required List<String> publicKeysBase64Url,
  }) async {
    for (final keyB64 in publicKeysBase64Url) {
      final trimmed = keyB64.trim();
      if (trimmed.isEmpty) continue;
      try {
        final publicKey = SimplePublicKey(
          base64UrlDecode(trimmed),
          type: KeyPairType.ed25519,
        );
        final signature = Signature(signatureBytes, publicKey: publicKey);
        if (await Ed25519().verify(payloadBytes, signature: signature)) {
          return true;
        }
      } catch (_) {
        // invalid key encoding or signature length — try the next trusted key
      }
    }
    return false;
  }

  /// Decodes an unpadded base64url string. Used for both keys and the envelope
  /// payload/signature fields.
  static List<int> base64UrlDecode(String raw) {
    final normalized = raw.trim().replaceAll('-', '+').replaceAll('_', '/');
    final padded = normalized.padRight(
      normalized.length + ((4 - normalized.length % 4) % 4),
      '=',
    );
    return base64.decode(padded);
  }
}
