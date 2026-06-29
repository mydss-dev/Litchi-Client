import '../shared/models/app_models.dart';
import '../shared/services/mihomo_config.dart';

class CoreConnectionRequest {
  const CoreConnectionRequest({
    required this.nodes,
    required this.currentNode,
    required this.proxyMode,
    required this.dnsMode,
    required this.proxyPort,
    this.networkMode = NetworkMode.system,
    this.allowInsecure = false,
    this.rules = const [],
    this.ruleProviders = const {},
  });

  final List<NodeModel> nodes;
  final NodeModel currentNode;
  final ProxyMode proxyMode;
  final String dnsMode;
  final int proxyPort;
  final NetworkMode networkMode;

  /// When false, nodes' `insecure`/skip-cert-verify flags are stripped so TLS
  /// certificates are always validated.
  final bool allowInsecure;

  /// Server-supplied Clash rules (e.g. from V2Board subscription YAML).
  /// Each entry is a raw rule line like "DOMAIN-SUFFIX,google.com,PROXY".
  final List<String> rules;

  /// Server-supplied rule-providers (from Clash YAML `rule-providers`).
  final Map<String, dynamic> ruleProviders;

  List<NodeModel> get validNodes => nodes.where((n) => n.hasConfig).toList();

  NodeModel? get selectedNode {
    if (currentNode.hasConfig) return currentNode;
    final availableNodes = validNodes;
    return availableNodes.isEmpty ? null : availableNodes.first;
  }

  String get selectedTag {
    final node = selectedNode;
    return node == null ? '' : MihomoConfig.nodeTagFor(node);
  }

  CoreConnectionRequest withNetworkMode(NetworkMode mode) =>
      CoreConnectionRequest(
        nodes: nodes,
        currentNode: currentNode,
        proxyMode: proxyMode,
        dnsMode: dnsMode,
        proxyPort: proxyPort,
        networkMode: mode,
        allowInsecure: allowInsecure,
        rules: rules,
        ruleProviders: ruleProviders,
      );

  Map<String, dynamic>? buildConfig({
    NetworkMode? overrideNetworkMode,
    int? overrideProxyPort,
    int apiPort = MihomoConfig.defaultApiPort,
  }) {
    final availableNodes = validNodes;
    if (availableNodes.isEmpty) return null;
    final tag = selectedTag;
    if (tag.isEmpty) return null;
    return MihomoConfig.buildFullConfig(
      availableNodes,
      selectedTag: tag,
      port: overrideProxyPort ?? proxyPort,
      apiPort: apiPort,
      proxyMode: proxyMode,
      dnsMode: dnsMode,
      networkMode: overrideNetworkMode ?? networkMode,
      allowInsecure: allowInsecure,
      rules: rules,
      ruleProviders: ruleProviders,
    );
  }
}
