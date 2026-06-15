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
      rawUri: 'trojan://password@example.com:443#usable',
    );
    const request = CoreConnectionRequest(
      nodes: [
        selected,
        NodeModel(id: '2', name: 'display only', flag: '', latency: 0),
      ],
      currentNode: selected,
      proxyMode: ProxyMode.rule,
      dnsMode: 'Cloudflare',
      proxyPort: 7890,
    );

    expect(request.validNodes.map((node) => node.id), ['1']);
    expect(request.selectedTag, 'node-1');
  });

  test('accepts Clash YAML raw outbound nodes as connectable', () {
    const selected = NodeModel(
      id: 'yaml',
      name: 'yaml',
      flag: '',
      latency: 0,
      rawOutbound: {
        'type': 'trojan',
        'server': 'example.com',
        'port': 443,
        'password': 'secret',
      },
    );
    const request = CoreConnectionRequest(
      nodes: [selected],
      currentNode: selected,
      proxyMode: ProxyMode.rule,
      dnsMode: 'Cloudflare',
      proxyPort: 7890,
    );

    expect(request.validNodes, hasLength(1));
    expect(request.buildConfig(), isNotNull);
  });

  test(
    'falls back to first valid node when current node is not connectable',
    () {
      const fallback = NodeModel(
        id: 'fallback',
        name: 'fallback',
        flag: '',
        latency: 0,
        rawUri: 'trojan://password@example.com:443#fallback',
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
        dnsMode: 'Cloudflare',
        proxyPort: 7890,
      );

      expect(request.selectedNode, fallback);
      expect(request.selectedTag, 'node-fallback');
      expect(request.buildConfig(), isNotNull);
    },
  );
}
