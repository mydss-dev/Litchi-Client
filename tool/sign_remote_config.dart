import 'dart:io';

import 'signing_common.dart';

/// Signs config.json with the config Ed25519 keypair.
///
/// This signer must ONLY ever use the config keys — never the
/// update-manifest keys. Use tool/sign_update_manifest.dart for update.json.
Future<void> main(List<String> args) async {
  if (args.isEmpty || args.first == 'help' || args.first == '--help') {
    _usage();
    return;
  }

  switch (args.first) {
    case 'generate':
      await generateKeyPair();
      return;
    case 'sign':
      if (args.length != 4) {
        stderr.writeln(
          'sign requires: <config.json|payload.json> <private_key> <public_key>',
        );
        _usage();
        exitCode = 64;
        return;
      }
      await signPayloadFile(
        payloadPath: args[1],
        privateKeyB64: args[2],
        publicKeyB64: args[3],
      );
      return;
    case 'sign-env':
      if (args.length != 2) {
        stderr.writeln('sign-env requires: <config.json|payload.json>');
        _usage();
        exitCode = 64;
        return;
      }
      final privateKey = Platform.environment['CONFIG_PRIVATE_KEY'];
      final publicKey = Platform.environment['CONFIG_PUBLIC_KEY'];
      if (privateKey == null ||
          privateKey.isEmpty ||
          publicKey == null ||
          publicKey.isEmpty) {
        stderr.writeln(
          'Set CONFIG_PRIVATE_KEY and CONFIG_PUBLIC_KEY.',
        );
        exitCode = 64;
        return;
      }
      await signPayloadFile(
        payloadPath: args[1],
        privateKeyB64: privateKey,
        publicKeyB64: publicKey,
      );
      return;
    default:
      stderr.writeln('Unknown command: ${args.first}');
      _usage();
      exitCode = 64;
  }
}

void _usage() {
  stdout.writeln('''
Usage:
  dart run tool/sign_remote_config.dart generate
  dart run tool/sign_remote_config.dart sign <config.json|payload.json> <private_key> <public_key>
  dart run tool/sign_remote_config.dart sign-env <config.json|payload.json>

sign-env reads CONFIG_PRIVATE_KEY and CONFIG_PUBLIC_KEY.
''');
}
