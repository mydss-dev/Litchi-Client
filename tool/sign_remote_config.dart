import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';

Future<void> main(List<String> args) async {
  if (args.isEmpty || args.first == 'help' || args.first == '--help') {
    _usage();
    return;
  }

  switch (args.first) {
    case 'generate':
      await _generate();
      return;
    case 'sign':
      if (args.length != 4) {
        stderr.writeln('sign requires: <payload.json> <private_key> <public_key>');
        _usage();
        exitCode = 64;
        return;
      }
      await _sign(
        payloadPath: args[1],
        privateKeyB64: args[2],
        publicKeyB64: args[3],
      );
      return;
    default:
      stderr.writeln('Unknown command: ${args.first}');
      _usage();
      exitCode = 64;
  }
}

Future<void> _generate() async {
  final algorithm = Ed25519();
  final keyPair = await algorithm.newKeyPair();
  final privateKeyBytes = await keyPair.extractPrivateKeyBytes();
  final publicKey = await keyPair.extractPublicKey();

  stdout.writeln('PRIVATE_KEY=${_b64(privateKeyBytes)}');
  stdout.writeln('PUBLIC_KEY=${_b64(publicKey.bytes)}');
  stdout.writeln('');
  stdout.writeln('Put PUBLIC_KEY into RemoteConfigVerifier._publicKeyBase64Url.');
  stdout.writeln('Keep PRIVATE_KEY offline. Never commit it.');
}

Future<void> _sign({
  required String payloadPath,
  required String privateKeyB64,
  required String publicKeyB64,
}) async {
  final raw = await File(payloadPath).readAsString();
  final decoded = jsonDecode(raw);
  if (decoded is! Map<String, dynamic>) {
    stderr.writeln('payload must be a JSON object');
    exitCode = 65;
    return;
  }

  // Minify before signing. The exact bytes are embedded as payload_b64, so the
  // client verifies the same bytes and does not need canonical JSON sorting.
  final payloadBytes = utf8.encode(jsonEncode(decoded));
  final publicKey = SimplePublicKey(
    _b64decode(publicKeyB64),
    type: KeyPairType.ed25519,
  );
  final keyPair = SimpleKeyPairData(
    _b64decode(privateKeyB64),
    publicKey: publicKey,
    type: KeyPairType.ed25519,
  );

  final signature = await Ed25519().sign(payloadBytes, keyPair: keyPair);
  const encoder = JsonEncoder.withIndent('  ');
  stdout.writeln(encoder.convert({
    'payload_b64': _b64(payloadBytes),
    'signature': _b64(signature.bytes),
  }));
}

void _usage() {
  stdout.writeln('''
Usage:
  dart run tool/sign_remote_config.dart generate
  dart run tool/sign_remote_config.dart sign <payload.json> <private_key> <public_key>

Example payload.json:
  {
    "api_base": "https://api.example.com",
    "update_check_url": "https://oss.example.com/update.json",
    "invite_url_base": "https://example.com",
    "min_version": "1.2.0"
  }
''');
}

String _b64(List<int> bytes) => base64Url.encode(bytes).replaceAll('=', '');

List<int> _b64decode(String raw) {
  final normalized = raw.trim().replaceAll('-', '+').replaceAll('_', '/');
  final padded = normalized.padRight(
    normalized.length + ((4 - normalized.length % 4) % 4),
    '=',
  );
  return base64.decode(padded);
}
