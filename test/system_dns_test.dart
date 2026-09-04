import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/shared/services/system_dns.dart';

void main() {
  test('filters to deduplicated IPv4 literals', () {
    expect(
      SystemDns.filterDnsServers([
        '192.168.1.1',
        'fe80::1',
        '8.8.8.8',
        '192.168.1.1',
        '',
        'not-an-ip',
      ]),
      ['192.168.1.1', '8.8.8.8'],
    );
  });

  test('retains loopback forwarders and drops IPv6', () {
    expect(
      SystemDns.filterDnsServers(['127.0.0.1', '::1', '223.5.5.5']),
      ['127.0.0.1', '223.5.5.5'],
    );
  });

  test('returns empty for empty or non-IPv4 input', () {
    expect(SystemDns.filterDnsServers(const []), isEmpty);
    expect(SystemDns.filterDnsServers(['fe80::1', 'hostname']), isEmpty);
  });
}
