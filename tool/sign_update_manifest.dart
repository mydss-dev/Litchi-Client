import 'dart:io';

import 'signing_common.dart';

/// Signs the update manifest (update-v2.json) with the update-manifest Ed25519
/// keypair.
///
/// This signer must ONLY ever use the update-manifest keys — never the
/// remote-config keys. Use tool/sign_remote_config.dart for remote_config.json.
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
          'sign requires: <payload.json> <private_key> <public_key>',
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
        stderr.writeln('sign-env requires: <payload.json>');
        _usage();
        exitCode = 64;
        return;
      }
      final privateKey = Platform.environment['UPDATE_PRIVATE_KEY'];
      final publicKey = Platform.environment['UPDATE_PUBLIC_KEY'];
      if (privateKey == null ||
          privateKey.isEmpty ||
          publicKey == null ||
          publicKey.isEmpty) {
        stderr.writeln('Set UPDATE_PRIVATE_KEY and UPDATE_PUBLIC_KEY.');
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
  dart run tool/sign_update_manifest.dart generate
  dart run tool/sign_update_manifest.dart sign <payload.json> <private_key> <public_key>
  dart run tool/sign_update_manifest.dart sign-env <payload.json>

sign-env reads UPDATE_PRIVATE_KEY and UPDATE_PUBLIC_KEY.
''');
}
