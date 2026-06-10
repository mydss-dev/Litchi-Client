import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/shared/services/subscription/subscription_parser.dart';

void main() {
  test('parses base64 encoded vmess subscription', () {
    final vmess = base64.encode(utf8.encode('''
{
  "ps": "Test Node",
  "add": "example.com",
  "port": 443,
  "id": "00000000-0000-0000-0000-000000000000",
  "aid": 0,
  "net": "tcp",
  "tls": "tls"
}
'''));
    final body = base64.encode(utf8.encode('vmess://$vmess'));

    final nodes = SubscriptionParser.parse(body);

    expect(nodes, hasLength(1));
    expect(nodes.first.name, 'Test Node');
    expect(nodes.first.server, 'example.com');
    expect(nodes.first.port, 443);
    expect(nodes.first.rawUri, startsWith('vmess://'));
  });

  test('parses clash yaml proxies', () {
    const body = '''
proxies:
  - name: SG 01
    type: ss
    server: sg.example.com
    port: 8388
    rate: 2
''';

    final nodes = SubscriptionParser.parse(body);

    expect(nodes, hasLength(1));
    expect(nodes.first.name, 'SG 01');
    expect(nodes.first.server, 'sg.example.com');
    expect(nodes.first.port, 8388);
    expect(nodes.first.rate, 2);
  });
}
