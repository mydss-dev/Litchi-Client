import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';

/// Shared Ed25519 helpers for the two release signers.
///
/// Each signer calls these with ITS OWN key material — remote-config vs
/// update-manifest — so a private key never crosses between the two trust
/// domains. This file holds no key of its own and never reads the environment.
Future<void> generateKeyPair() async {
  final keyPair = await Ed25519().newKeyPair();
  final privateKeyBytes = await keyPair.extractPrivateKeyBytes();
  final publicKey = await keyPair.extractPublicKey();

  stdout.writeln('PRIVATE_KEY=${b64(privateKeyBytes)}');
  stdout.writeln('PUBLIC_KEY=${b64(publicKey.bytes)}');
  stdout.writeln('');
  stdout.writeln('Keep PRIVATE_KEY offline. Never commit it.');
}

/// Signs the JSON object at [payloadPath] with [privateKeyB64] and emits the
/// signed envelope to stdout:
///
/// {
///   "payload_b64": "base64url(utf8(jsonPayload))",
///   "signature": "base64url(ed25519_signature(payload_bytes))"
/// }
Future<void> signPayloadFile({
  required String payloadPath,
  required String privateKeyB64,
  required String publicKeyB64,
}) async {
  final decoded = await loadPayload(payloadPath);
  if (decoded is! Map<String, dynamic>) {
    stderr.writeln('payload must be a JSON object');
    exitCode = 65;
    return;
  }

  // Minify before signing. The exact bytes are embedded as payload_b64, so the
  // client verifies the same bytes and does not need canonical JSON sorting.
  final payloadBytes = utf8.encode(jsonEncode(decoded));
  final publicKey = SimplePublicKey(
    b64decode(publicKeyB64),
    type: KeyPairType.ed25519,
  );
  final keyPair = SimpleKeyPairData(
    b64decode(privateKeyB64),
    publicKey: publicKey,
    type: KeyPairType.ed25519,
  );

  final signature = await Ed25519().sign(payloadBytes, keyPair: keyPair);
  const encoder = JsonEncoder.withIndent('  ');
  stdout.writeln(
    encoder.convert({
      'payload_b64': b64(payloadBytes),
      'signature': b64(signature.bytes),
    }),
  );
}

/// Loads a JSON object from a `.json` file, or from a `.js` file that prints
/// JSON to stdout (so configs may contain comments).
Future<Object?> loadPayload(String payloadPath) async {
  if (payloadPath.toLowerCase().endsWith('.js')) {
    final result = await Process.run('node', [payloadPath]);
    if (result.exitCode != 0) {
      stderr.writeln(result.stderr);
      exitCode = result.exitCode;
      return null;
    }
    return jsonDecode('${result.stdout}');
  }

  final raw = await File(payloadPath).readAsString();
  return jsonDecode(raw);
}

String b64(List<int> bytes) => base64Url.encode(bytes).replaceAll('=', '');

List<int> b64decode(String raw) {
  final normalized = raw.trim().replaceAll('-', '+').replaceAll('_', '/');
  final padded = normalized.padRight(
    normalized.length + ((4 - normalized.length % 4) % 4),
    '=',
  );
  return base64.decode(padded);
}
