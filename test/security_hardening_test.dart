import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/config/app_config.dart';
import 'package:litchi_client/shared/services/outbound_parser.dart';
import 'package:litchi_client/shared/services/windows_dpapi.dart';

void main() {
  group('OutboundParser insecure-node policy', () {
    const insecureHy2 = 'hysteria2://pass@example.com:443?insecure=1#node';

    test('keeps tls.insecure when insecure nodes are allowed', () {
      final out = OutboundParser.parse(
        insecureHy2,
        tag: 'n',
        allowInsecure: true,
      );
      expect(out, isNotNull);
      expect((out!['tls'] as Map)['insecure'], isTrue);
    });

    test('strips tls.insecure when insecure nodes are disallowed', () {
      final out = OutboundParser.parse(
        insecureHy2,
        tag: 'n',
        allowInsecure: false,
      );
      expect(out, isNotNull);
      expect((out!['tls'] as Map).containsKey('insecure'), isFalse);
    });

    test('strips insecure from a Clash trojan proxy when disallowed', () {
      final out = OutboundParser.parseClashProxy(
        {
          'type': 'trojan',
          'server': 'example.com',
          'port': 443,
          'password': 'pw',
          'skip-cert-verify': true,
        },
        tag: 'n',
        allowInsecure: false,
      );
      expect(out, isNotNull);
      expect((out!['tls'] as Map).containsKey('insecure'), isFalse);
    });

    test('accepts Clash ws-opts and grpc-opts transport fields', () {
      final ws = OutboundParser.parseClashProxy({
        'type': 'vless',
        'server': 'example.com',
        'port': 443,
        'uuid': '00000000-0000-0000-0000-000000000000',
        'tls': true,
        'network': 'ws',
        'ws-opts': {
          'path': '/edge',
          'headers': {'Host': 'cdn.example.com'},
        },
      }, tag: 'ws');
      expect((ws!['transport'] as Map)['path'], '/edge');
      expect(
        ((ws['transport'] as Map)['headers'] as Map)['Host'],
        'cdn.example.com',
      );

      final grpc = OutboundParser.parseClashProxy({
        'type': 'trojan',
        'server': 'example.com',
        'port': 443,
        'password': 'pw',
        'network': 'grpc',
        'grpc-opts': {'grpc-service-name': 'svc'},
      }, tag: 'grpc');
      expect((grpc!['transport'] as Map)['service_name'], 'svc');
    });

    test('accepts common Clash Reality fields', () {
      final out = OutboundParser.parseClashProxy({
        'type': 'vless',
        'server': 'example.com',
        'port': 443,
        'uuid': '00000000-0000-0000-0000-000000000000',
        'servername': 'www.microsoft.com',
        'client-fingerprint': 'chrome',
        'reality-opts': {
          'public-key': 'abc',
          'short-id': 'def',
          'spider-x': '/',
        },
      }, tag: 'reality');

      final tls = out!['tls'] as Map;
      expect((tls['reality'] as Map)['public_key'], 'abc');
      expect((tls['reality'] as Map)['short_id'], 'def');
      expect((tls['utls'] as Map)['fingerprint'], 'chrome');
    });
  });

  group('AppConfig version single source of truth', () {
    test('setVersion overrides the current version; blank is ignored', () {
      final original = AppConfig.currentVersion;
      AppConfig.setVersion('9.9.9');
      expect(AppConfig.currentVersion, '9.9.9');
      AppConfig.setVersion('   ');
      expect(AppConfig.currentVersion, '9.9.9');
      AppConfig.setVersion(original);
    });
  });

  group('WindowsDpapi', () {
    test('round-trips a secret via native DPAPI', () {
      if (!Platform.isWindows) return; // DPAPI is Windows-only.
      const secret = 'p@ss-字符-🔐-123';
      final enc = WindowsDpapi.protect(secret);
      expect(enc, isNotNull);
      expect(enc, isNot(contains(secret)));
      final dec = WindowsDpapi.unprotect(enc!);
      expect(dec, secret);
    });

    test('returns null for malformed input', () {
      if (!Platform.isWindows) return;
      expect(WindowsDpapi.unprotect('not-hex-zz'), isNull);
    });
  });
}
