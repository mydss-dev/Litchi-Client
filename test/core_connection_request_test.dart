import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/app/core_connection_request.dart';
import 'package:litchi_client/shared/models/app_models.dart';

void main() {
  test('keeps only nodes with core config material', () {
    const selected = NodeModel(
      id: '1',
      name: 'usable',
      flag: '',
      latency: 0,
      rawOutbound: {
        'type': 'trojan',
        'tag': 'source',
        'server': 'example.com',
        'server_port': 443,
        'password': 'password',
        '_litchi_format': 'sing-box',
      },
    );
    const request = CoreConnectionRequest(
      nodes: [
        selected,
        NodeModel(id: '2', name: 'display only', flag: '', latency: 0),
      ],
      currentNode: selected,
      proxyMode: ProxyMode.rule,
      dnsMode: DnsMode.cloudflare,
      proxyPort: 7890,
    );

    expect(request.validNodes.map((node) => node.id), ['1']);
    expect(request.selectedSingBoxTag, 'node-1');
  });

  test('accepts native outbound nodes as connectable', () {
    const selected = NodeModel(
      id: 'sing-box-native',
      name: 'sing-box native',
      flag: '',
      latency: 0,
      rawOutbound: {
        'type': 'trojan',
        'server': 'example.com',
        'server_port': 443,
        'password': 'secret',
        '_litchi_format': 'sing-box',
      },
    );
    const request = CoreConnectionRequest(
      nodes: [selected],
      currentNode: selected,
      proxyMode: ProxyMode.rule,
      dnsMode: DnsMode.cloudflare,
      proxyPort: 7890,
    );

    expect(request.validNodes, hasLength(1));
    expect(request.buildSingBoxConfig(), isNotNull);
  });

  test('can build a session config with an automatically selected port', () {
    const selected = NodeModel(
      id: 'dynamic-port',
      name: 'dynamic-port',
      flag: '',
      latency: 0,
      rawOutbound: {
        'type': 'trojan',
        'tag': 'source',
        'server': 'example.com',
        'server_port': 443,
        'password': 'password',
        '_litchi_format': 'sing-box',
      },
    );
    const request = CoreConnectionRequest(
      nodes: [selected],
      currentNode: selected,
      proxyMode: ProxyMode.rule,
      dnsMode: DnsMode.system,
      proxyPort: 7890,
    );

    final config = request.buildSingBoxConfig(overrideProxyPort: 49152);

    final inbounds = config?['inbounds'] as List<dynamic>;
    final mixed = inbounds.whereType<Map<String, dynamic>>().firstWhere(
      (inbound) => inbound['type'] == 'mixed',
    );
    expect(mixed['listen_port'], 49152);
    expect(request.proxyPort, 7890);
  });

  test('pinned Windows TUN DNS allows AAAA but keeps node bootstrap IPv4', () {
    const selected = NodeModel(
      id: 'dual-stack',
      name: 'dual-stack',
      flag: '',
      latency: 0,
      rawOutbound: {
        'type': 'trojan',
        'server': 'example.com',
        'server_port': 443,
        'password': 'password',
        '_litchi_format': 'sing-box',
      },
    );
    const request = CoreConnectionRequest(
      nodes: [selected],
      currentNode: selected,
      proxyMode: ProxyMode.rule,
      dnsMode: DnsMode.cloudflare,
      proxyPort: 7890,
    );

    final normal = request.buildSingBoxConfig()!;
    expect((normal['dns'] as Map)['strategy'], 'ipv4_only');

    final tun = request.buildSingBoxConfig(
      overrideNetworkMode: NetworkMode.system,
      localDnsServers: const ['192.0.2.53'],
    )!;
    final dns = tun['dns'] as Map;
    final route = tun['route'] as Map;
    final bootstrap = route['default_domain_resolver'] as Map;
    final local = (dns['servers'] as List).cast<Map>().firstWhere(
      (server) => server['tag'] == 'dns-local',
    );

    expect(dns['strategy'], 'prefer_ipv4');
    expect(bootstrap['strategy'], 'ipv4_only');
    expect(local['type'], 'udp');
    expect(local['server'], '192.0.2.53');
  });

  test(
    'falls back to first valid node when current node is not connectable',
    () {
      const fallback = NodeModel(
        id: 'fallback',
        name: 'fallback',
        flag: '',
        latency: 0,
        rawOutbound: {
          'type': 'trojan',
          'tag': 'source',
          'server': 'example.com',
          'server_port': 443,
          'password': 'password',
          '_litchi_format': 'sing-box',
        },
      );
      const request = CoreConnectionRequest(
        nodes: [
          NodeModel(id: 'display', name: 'display only', flag: '', latency: 0),
          fallback,
        ],
        currentNode: NodeModel(
          id: 'missing',
          name: 'missing',
          flag: '',
          latency: 0,
        ),
        proxyMode: ProxyMode.rule,
        dnsMode: DnsMode.cloudflare,
        proxyPort: 7890,
      );

      expect(request.selectedNode, fallback);
      expect(request.selectedSingBoxTag, 'node-fallback');
      expect(request.buildSingBoxConfig(), isNotNull);
    },
  );
}
