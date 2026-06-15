import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/app/core_connection_request.dart';
import 'package:litchi_client/app/core_runtime.dart';
import 'package:litchi_client/shared/models/app_models.dart';

void main() {
  test('CoreRuntimeStartPlan builds config with optional network override', () {
    const node = NodeModel(
      id: 'node-1',
      name: 'node',
      flag: '',
      latency: 0,
      rawUri: 'trojan://password@example.com:443#node',
    );
    const request = CoreConnectionRequest(
      nodes: [node],
      currentNode: node,
      proxyMode: ProxyMode.rule,
      dnsMode: 'Cloudflare',
      proxyPort: 7890,
      networkMode: NetworkMode.tun,
    );

    const plan = CoreRuntimeStartPlan(
      request: request,
      overrideNetworkMode: NetworkMode.system,
    );

    expect(plan.buildConfig(), isNotNull);
  });

  test(
    'CoreRuntimeStartPlan returns null config without connectable nodes',
    () {
      const request = CoreConnectionRequest(
        nodes: [
          NodeModel(id: 'display', name: 'display only', flag: '', latency: 0),
        ],
        currentNode: NodeModel(
          id: 'display',
          name: 'display only',
          flag: '',
          latency: 0,
        ),
        proxyMode: ProxyMode.rule,
        dnsMode: 'Cloudflare',
        proxyPort: 7890,
      );
      const plan = CoreRuntimeStartPlan(request: request);

      expect(plan.buildConfig(), isNull);
    },
  );
}
