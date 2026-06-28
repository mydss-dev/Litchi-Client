import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/shared/services/subscription_parser.dart';

void main() {
  const proxy = '''
proxies:
  - name: Test Node
    type: trojan
    server: example.com
    port: 443
    password: secret
''';

  test('maps custom MATCH and FINAL groups to PROXY', () {
    final profile = SubscriptionParser.parseProfile('''
$proxy
rules:
  - MATCH,Litchi Cloud
  - FINAL,Another Group
''');

    expect(profile.rules, containsAll(['MATCH,PROXY', 'FINAL,PROXY']));
  });

  test('keeps built-in two-field policies unchanged', () {
    final profile = SubscriptionParser.parseProfile('''
$proxy
rules:
  - MATCH,DIRECT
  - FINAL,REJECT
''');

    expect(profile.rules, containsAll(['MATCH,DIRECT', 'FINAL,REJECT']));
  });

  test('still maps custom three-field rule policies', () {
    final profile = SubscriptionParser.parseProfile('''
$proxy
rules:
  - DOMAIN-SUFFIX,example.com,Litchi Cloud
''');

    expect(profile.rules, ['DOMAIN-SUFFIX,example.com,PROXY']);
  });
}
