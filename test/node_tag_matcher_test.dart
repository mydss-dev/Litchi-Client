import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/shared/models/api_models.dart';
import 'package:litchi_client/shared/models/app_models.dart';
import 'package:litchi_client/shared/models/model_mappers.dart';
import 'package:litchi_client/shared/services/node_tag_matcher.dart';

NodeModel _node(String name, String server, int port, {String id = '1'}) =>
    NodeModel(
      id: id,
      name: name,
      flag: '🇺🇸',
      latency: 0,
      server: server,
      port: port,
    );

void main() {
  test('actual node labels are joined by unique name, not generated ID', () {
    final nodes = [
      _node('US-美国01', 'us1.example.com', 10010),
      _node('US-美国02', 'us2.example.com', 10010, id: '2'),
      _node('HK-香港02', 'hk2.example.com', 10010, id: '3'),
    ];
    final result = NodeTagMatcher.apply(
      nodes: nodes,
      metadata: [
        {
          'id': 41,
          'name': 'US-美国01',
          'tags': ['流媒体解锁', '家宽'],
        },
        {
          'id': 42,
          'name': 'US-美国02',
          'tags': ['测试111'],
        },
        {'id': 44, 'name': 'HK-香港02', 'tags': null},
      ],
    );
    expect(result[0].tags, ['流媒体解锁', '家宽']);
    expect(result[1].tags, ['测试111']);
    expect(result[2].tags, isEmpty);
  });

  test(
    'duplicate names require matching endpoint; ambiguous rows stay empty',
    () {
      final nodes = [
        _node('US-美国01', 'us1.example.com', 10010),
        _node('US-美国01', 'other.example.com', 10010, id: '2'),
      ];
      final result = NodeTagMatcher.apply(
        nodes: nodes,
        metadata: [
          {
            'name': 'US-美国01',
            'host': 'us1.example.com',
            'port': 10010,
            'tags': ['家宽', '家宽', '', null],
          },
        ],
      );
      expect(result[0].tags, ['家宽']);
      expect(result[1].tags, isEmpty);
    },
  );

  test('a rate above one does not invent Premium', () {
    final node = ModelMappers.toNode(
      const RemoteNode(id: 41, name: 'US-美国01', rate: 2.0),
    );
    expect(node.tags, isEmpty);
  });
}
