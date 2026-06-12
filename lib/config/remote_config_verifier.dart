import 'dart:convert';

import 'package:cryptography/cryptography.dart';

import 'remote_config_settings.dart';

/// Verifies signed remote config files downloaded from OSS.
///
/// Signed format:
///
/// ```json
/// {
///   "payload_b64": "base64url(utf8(jsonPayload))",
///   "signature": "base64url(ed25519_signature(payload_bytes))"
/// }
/// ```
///
/// The client verifies the exact payload bytes before decoding JSON, so signing
/// is not affected by map key order or whitespace changes in the wrapper file.
abstract final class RemoteConfigVerifier {
  /// During rollout, unsigned legacy config is accepted when no public key is
  /// configured. After you upload signed config and set the public key, unsigned
  /// config will be rejected automatically.
  static bool get requiresSignature =>
      RemoteConfigSettings.publicKeyBase64Url.isNotEmpty &&
      !RemoteConfigSettings.publicKeyBase64Url.startsWith('REPLACE_WITH_');

  static Future<Map<String, dynamic>?> parseTrustedConfig(String body) async {
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) return null;

    if (_looksSigned(decoded)) {
      return _verifySigned(decoded);
    }

    if (requiresSignature) return null;
    return decoded;
  }

  static bool _looksSigned(Map<String, dynamic> json) =>
      json['payload_b64'] is String && json['signature'] is String;

  static Future<Map<String, dynamic>?> _verifySigned(
    Map<String, dynamic> wrapper,
  ) async {
    if (!requiresSignature) return null;

    try {
      final payloadB64 = wrapper['payload_b64'] as String;
      final signatureB64 = wrapper['signature'] as String;
      final payloadBytes = _base64UrlDecode(payloadB64);
      final signatureBytes = _base64UrlDecode(signatureB64);
      final publicKeyBytes = _base64UrlDecode(
        RemoteConfigSettings.publicKeyBase64Url,
      );

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
