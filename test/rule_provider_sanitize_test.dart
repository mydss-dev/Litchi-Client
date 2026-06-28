import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/shared/services/subscription_parser.dart';

void main() {
  group('rule-provider sanitization', () {
    const yaml = '''
proxies:
  - name: n1
    type: ss
    server: example.com
    port: 8388
    cipher: aes-128-gcm
    password: pw
rule-providers:
  good:
    type: http
    behavior: domain
    url: https://example.com/good.yaml
    path: ./providers/good.yaml
    interval: 86400
  traversal:
    type: http
    behavior: domain
    url: https://example.com/evil.yaml
    path: ../../../../etc/evil.yaml
  absolute:
    type: http
    behavior: domain
    url: https://example.com/abs.yaml
    path: /etc/passwd
  insecure:
    type: http
    behavior: domain
    url: http://example.com/insecure.yaml
    path: ./providers/insecure.yaml
rules:
  - 'MATCH,PROXY'
''';

    final providers = SubscriptionParser.parseProfile(yaml).ruleProviders;

    test('keeps a safe https provider with a confined path', () {
      expect(providers.containsKey('good'), isTrue);
      expect((providers['good'] as Map)['path'], 'providers/good.yaml');
    });

    test('confines a traversal path instead of escaping the data dir', () {
      expect(providers.containsKey('traversal'), isTrue);
      expect(
        (providers['traversal'] as Map)['path'],
        'providers/traversal.yaml',
      );
    });

    test('confines an absolute path under providers/', () {
      expect(providers.containsKey('absolute'), isTrue);
      expect((providers['absolute'] as Map)['path'], 'providers/absolute.yaml');
    });

    test('drops a provider that fetches its rule list over http', () {
      expect(providers.containsKey('insecure'), isFalse);
    });
  });
}
