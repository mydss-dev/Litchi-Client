import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/shared/models/app_models.dart';
import 'package:litchi_client/shared/services/node_filter.dart';

void main() {
  const nodes = [
    NodeModel(
      id: 'hk-1',
      name: 'Hong Kong Premium',
      flag: '',
      code: 'HK',
      englishName: 'Hong Kong',
      latency: 0,
      tags: ['Premium'],
      region: NodeRegion.asia,
      server: 'hk.example.com',
    ),
    NodeModel(
      id: 'us-1',
      name: 'United States',
      flag: '',
      code: 'US',
      englishName: 'Los Angeles',
      latency: 0,
      region: NodeRegion.america,
      server: 'us.example.com',
    ),
  ];

  test('filters by search token across display fields', () {
    final result = NodeFilter.apply(
      nodes: nodes,
      query: 'los',
      tab: NodeFilterTab.all,
    );

    expect(result.map((node) => node.id), ['us-1']);
  });

  test('filters by region and premium tag', () {
    final premium = NodeFilter.apply(
      nodes: nodes,
      query: '',
      tab: NodeFilterTab.premium,
    );
    final america = NodeFilter.apply(
      nodes: nodes,
      query: '',
      tab: NodeFilterTab.america,
    );

    expect(premium.map((node) => node.id), ['hk-1']);
    expect(america.map((node) => node.id), ['us-1']);
  });

  test('filters favorites without mutating source list', () {
    final result = NodeFilter.apply(
      nodes: nodes,
      query: '',
      tab: NodeFilterTab.favorite,
      favorites: {'us-1'},
    );

    expect(result.map((node) => node.id), ['us-1']);
    expect(nodes.length, 2);
  });

  test('preserves raw outbound during node cache serialization', () {
    const node = NodeModel(
      id: 'sing-box-1',
      name: 'sing-box Node',
      flag: '',
      latency: 0,
      rawOutbound: {
        '_litchi_format': 'sing-box',
        'type': 'trojan',
        'server': 'example.com',
        'port': 443,
        'password': 'secret',
      },
    );

    final restored = NodeModel.fromJson(node.toJson());

    expect(restored.rawOutbound?['type'], 'trojan');
    expect(restored.rawOutbound?['server'], 'example.com');
    expect(restored.rawOutbound?['port'], 443);
  });
}
