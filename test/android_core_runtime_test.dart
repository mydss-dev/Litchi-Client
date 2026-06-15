import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/app/android_core_runtime.dart';
import 'package:litchi_client/app/core_connection_request.dart';
import 'package:litchi_client/app/core_runtime.dart';
import 'package:litchi_client/shared/models/app_models.dart';
import 'package:litchi_client/shared/services/android_core_manager.dart';

class FakeAndroidCoreManager extends AndroidCoreManager {
  String? capturedConfig;
  bool startResult = true;

  @override
  bool get isRunning => startResult;

  @override
  Future<bool> start(String configJson) async {
    capturedConfig = configJson;
    return startResult;
  }
}

void main() {
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
    networkMode: NetworkMode.system,
  );

  test('AndroidCoreRuntime forces TUN mode by default', () async {
    final core = FakeAndroidCoreManager();
    final runtime = AndroidCoreRuntime(core: core);

    final ok = await runtime.start(
      const CoreRuntimeStartPlan(request: request),
    );

    expect(ok, isTrue);
    final config = jsonDecode(core.capturedConfig!) as Map<String, dynamic>;
    final inbounds = config['inbounds'] as List<dynamic>;
    expect(
      inbounds.any((item) => (item as Map<String, dynamic>)['type'] == 'tun'),
      isTrue,
    );
  });

  test('AndroidCoreRuntime reports config build failures', () async {
    final runtime = AndroidCoreRuntime(core: FakeAndroidCoreManager());
    const invalidRequest = CoreConnectionRequest(
      nodes: [
        NodeModel(id: 'bad', name: 'bad', flag: '', latency: 0, rawUri: 'bad'),
      ],
      currentNode: NodeModel(
        id: 'bad',
        name: 'bad',
        flag: '',
        latency: 0,
        rawUri: 'bad',
      ),
      proxyMode: ProxyMode.rule,
      dnsMode: 'Cloudflare',
      proxyPort: 7890,
    );

    final ok = await runtime.start(
      const CoreRuntimeStartPlan(request: invalidRequest),
    );

    expect(ok, isFalse);
    expect(runtime.lastError, isNotEmpty);
  });
}
