import '../shared/models/app_models.dart';
import '../shared/services/sing_box_config.dart';

class CoreConnectionRequest {
  const CoreConnectionRequest({
    required this.nodes,
    required this.currentNode,
    required this.proxyMode,
    required this.dnsMode,
    required this.proxyPort,
    this.networkMode = NetworkMode.system,
    this.allowInsecure = false,
    this.localDnsServers = const [],
  });

  final List<NodeModel> nodes;
  final NodeModel currentNode;
  final ProxyMode proxyMode;
  final DnsMode dnsMode;
  final int proxyPort;
  final NetworkMode networkMode;

  /// When false, nodes' `insecure`/skip-cert-verify flags are stripped so TLS
  /// certificates are always validated.
  final bool allowInsecure;

  /// Real system DNS servers snapshotted before the Windows TUN bridge comes
  /// up. When non-empty, `dns-local` resolves through them directly instead of
  /// the (TUN-poisoned) OS resolver.
  final List<String> localDnsServers;

  List<NodeModel> get validNodes => nodes.where((n) => n.hasConfig).toList();

  NodeModel? get selectedNode {
    if (currentNode.hasConfig) return currentNode;
    final availableNodes = validNodes;
    return availableNodes.isEmpty ? null : availableNodes.first;
  }

  String get selectedSingBoxTag {
    final node = selectedNode;
    return node == null ? '' : SingBoxConfig.nodeTagFor(node);
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
        localDnsServers: localDnsServers,
      );

  Map<String, dynamic>? buildSingBoxConfig({
    NetworkMode? overrideNetworkMode,
    int? overrideProxyPort,
    int apiPort = SingBoxConfig.defaultApiPort,
    String apiSecret = '',
    List<String>? localDnsServers,
  }) {
    final availableNodes = validNodes;
    if (availableNodes.isEmpty || selectedSingBoxTag.isEmpty) return null;
    return SingBoxConfig.buildFullConfig(
      availableNodes,
      selectedTag: selectedSingBoxTag,
      port: overrideProxyPort ?? proxyPort,
      apiPort: apiPort,
      apiSecret: apiSecret,
      proxyMode: proxyMode,
      dnsMode: dnsMode,
      networkMode: overrideNetworkMode ?? networkMode,
      allowInsecure: allowInsecure,
      localDnsServers: localDnsServers ?? this.localDnsServers,
    );
  }
}
