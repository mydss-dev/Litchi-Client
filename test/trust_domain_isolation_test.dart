import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/config/remote_config.dart';
import 'package:litchi_client/shared/services/signed_payload_verifier.dart';
import 'package:litchi_client/shared/services/update_manifest_verifier.dart';
import 'package:litchi_client/shared/services/update_service.dart';

/// Locks in P0-2: the remote-config and update-manifest trust roots are
/// independent. A payload signed by one key must never verify against the other
/// trust root's verifier.
void main() {
  late _Key remoteKey;
  late _Key updateKey;
  late _Key oldRemoteKey;
  late _Key oldUpdateKey;

  setUpAll(() async {
    remoteKey = await _generate();
    updateKey = await _generate();
    oldRemoteKey = await _generate();
    oldUpdateKey = await _generate();
  });

  test('remote config verifies with remote key, not update key', () async {
    final payload = {'app_name': 'litchi'};
    final remoteSigned = await _sign(payload, remoteKey);
    final updateSigned = await _sign(payload, updateKey);

    expect(
      await RemoteConfigService.verifyAndParse(
        remoteSigned,
        publicKeysBase64Url: [remoteKey.public],
      ),
      isNotNull,
    );
    expect(
      await RemoteConfigService.verifyAndParse(
        updateSigned,
        publicKeysBase64Url: [remoteKey.public],
      ),
      isNull,
    );
  });

  test('update manifest verifies with update key, not remote key', () async {
    final payload = {'update_version': '2.0.0'};
    final updateSigned = await _sign(payload, updateKey);
    final remoteSigned = await _sign(payload, remoteKey);

    expect(
      await UpdateManifestVerifier.verifyAndParse(
        updateSigned,
        publicKeysBase64Url: [updateKey.public],
      ),
      isNotNull,
    );
    expect(
      await UpdateManifestVerifier.verifyAndParse(
        remoteSigned,
        publicKeysBase64Url: [updateKey.public],
      ),
      isNull,
    );
  });

  test('remote config accepts the previous rotation key', () async {
    final body = await _sign({'api_prefix': '/api'}, oldRemoteKey);
    expect(
      await RemoteConfigService.verifyAndParse(
        body,
        publicKeysBase64Url: [remoteKey.public, oldRemoteKey.public],
      ),
      isNotNull,
    );
  });

  test('update manifest accepts the previous rotation key', () async {
    final body = await _sign({'update_version': '2.0.0'}, oldUpdateKey);
    expect(
      await UpdateManifestVerifier.verifyAndParse(
        body,
        publicKeysBase64Url: [updateKey.public, oldUpdateKey.public],
      ),
      isNotNull,
    );
  });

  test('a tampered signature is rejected', () async {
    final body = await _sign({'app_name': 'litchi'}, remoteKey);
    final decoded = jsonDecode(body) as Map<String, dynamic>;
    final signature = decoded['signature'] as String;
    final tamperedFirst = signature[0] == 'A' ? 'B' : 'A';
    final bad = jsonEncode({
      ...decoded,
      'signature': tamperedFirst + signature.substring(1),
    });

    expect(
      await RemoteConfigService.verifyAndParse(
        bad,
        publicKeysBase64Url: [remoteKey.public],
      ),
      isNull,
    );
  });

  test('a malformed public key is skipped without throwing', () async {
    final body = await _sign({'app_name': 'litchi'}, remoteKey);
    expect(
      await RemoteConfigService.verifyAndParse(
        body,
        publicKeysBase64Url: ['!!!not-a-key!!!'],
      ),
      isNull,
    );
  });

  test('a malformed payload is rejected', () async {
    final body = jsonEncode({
      'payload_b64': '%%%not-base64%%%',
      'signature': _b64(List<int>.filled(64, 1)),
    });
    expect(
      await RemoteConfigService.verifyAndParse(
        body,
        publicKeysBase64Url: [remoteKey.public],
      ),
      isNull,
    );
  });

  test('an empty trust-key list fails closed', () async {
    final body = await _sign({'app_name': 'litchi'}, remoteKey);
    expect(
      await SignedPayloadVerifier.verifyAndParse(
        body: body,
        publicKeysBase64Url: const [],
      ),
      isNull,
    );
  });

  test('update-manifest verifier is disabled without a compiled key', () {
    expect(UpdateManifestVerifier.isConfigured, isFalse);
  });

  test('manifest URL resolution requires HTTPS and defaults to update.json', () {
    expect(
      UpdateService.resolveManifestUrl(
        configUrl: 'http://cdn.example.com/config.json',
      ),
      isEmpty,
    );
    expect(
      UpdateService.resolveManifestUrl(
        configUrl: 'https://cdn.example.com/config.json',
      ),
      'https://cdn.example.com/update.json',
    );
  });
}

class _Key {
  _Key(this.private, this.public);
  final String private;
  final String public;
}

Future<_Key> _generate() async {
  final keyPair = await Ed25519().newKeyPair();
  final private = await keyPair.extractPrivateKeyBytes();
  final public = await keyPair.extractPublicKey();
  return _Key(_b64(private), _b64(public.bytes));
}

Future<String> _sign(Map<String, dynamic> payload, _Key key) async {
  final payloadBytes = utf8.encode(jsonEncode(payload));
  final publicKey = SimplePublicKey(
    _b64decode(key.public),
    type: KeyPairType.ed25519,
  );
  final signingKey = SimpleKeyPairData(
    _b64decode(key.private),
    publicKey: publicKey,
    type: KeyPairType.ed25519,
  );
  final signature = await Ed25519().sign(payloadBytes, keyPair: signingKey);
  return jsonEncode({
    'payload_b64': _b64(payloadBytes),
    'signature': _b64(signature.bytes),
  });
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
