import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/shared/models/app_models.dart';
import 'package:litchi_client/shared/models/model_mappers.dart';
import 'package:litchi_client/shared/services/sing_box_config.dart';
import 'package:litchi_client/shared/services/subscription_parser.dart';

void main() {
  test('imports native sing-box proxy outbounds from V2Board JSON', () {
    final body = jsonEncode({
      'inbounds': [
        {'type': 'tun', 'tag': 'panel-tun'},
      ],
      'outbounds': [
        {'type': 'direct', 'tag': 'DIRECT'},
        {
          'type': 'selector',
          'tag': '节点选择',
          'outbounds': ['香港 01'],
        },
        {
          'type': 'vless',
          'tag': '香港 01',
          'server': 'example.com',
          'server_port': 443,
          'uuid': '00000000-0000-0000-0000-000000000001',
          'domain_resolver': 'local',
          'tls': {'enabled': true, 'insecure': true},
        },
      ],
      'route': {
        'final': '节点选择',
      },
    });

    final profile = SubscriptionParser.parseProfile(body);
    expect(profile.nodes, hasLength(1));
    expect(profile.nodes.single.name, '香港 01');
    expect(profile.nodes.single.rawOutbound?['_litchi_format'], 'sing-box');

    final node = ModelMappers.toNode(profile.nodes.single);
    final config = SingBoxConfig.buildFullConfig(
      <NodeModel>[node],
      selectedTag: SingBoxConfig.nodeTagFor(node),
    );
    expect(config, isNotNull);
    final outbounds = config!['outbounds'] as List<dynamic>;
    final imported = outbounds.whereType<Map<String, dynamic>>().firstWhere(
      (outbound) => outbound['type'] == 'vless',
    );
    expect(imported['tag'], SingBoxConfig.nodeTagFor(node));
    expect(imported.containsKey('_litchi_format'), isFalse);
    expect(imported.containsKey('domain_resolver'), isFalse);
    expect((imported['tls'] as Map).containsKey('insecure'), isFalse);

    final inbounds = config['inbounds'] as List<dynamic>;
    expect(
      inbounds.whereType<Map<String, dynamic>>().any(
        (inbound) => inbound['tag'] == 'panel-tun',
      ),
      isFalse,
    );
  });

  test('imports V2Board hysteria port hopping outbounds', () {
    final nodes = SubscriptionParser.parse(jsonEncode({
      'outbounds': [
        {
          'type': 'hysteria',
          'tag': 'Hysteria hopping',
          'server': 'hy.example.com',
          'server_ports': ['20000:30000'],
          'auth_str': 'secret',
          'tls': {'enabled': true},
        },
      ],
    }));
    expect(nodes, hasLength(1));
    expect(nodes.single.port, 20000);
  });
}
