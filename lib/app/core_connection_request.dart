import '../shared/models/app_models.dart';
import '../shared/services/singbox_config.dart';

class CoreConnectionRequest {
  const CoreConnectionRequest({
    required this.nodes,
    required this.currentNode,
    required this.proxyMode,
    required this.dnsMode,
    required this.proxyPort,
    this.networkMode = NetworkMode.system,
    this.allowInsecure = true,
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

  List<NodeModel> get validNodes => nodes.where(_hasCoreConfig).toList();

  NodeModel? get selectedNode {
    if (_hasCoreConfig(currentNode)) return currentNode;
    final availableNodes = validNodes;
    return availableNodes.isEmpty ? null : availableNodes.first;
  }

  String get selectedTag {
    final node = selectedNode;
    return node == null ? '' : SingboxConfig.nodeTagFor(node);
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
      );

  Map<String, dynamic>? buildConfig({NetworkMode? overrideNetworkMode}) {
    final availableNodes = validNodes;
    if (availableNodes.isEmpty) return null;
    final tag = selectedTag;
    if (tag.isEmpty) return null;
    return SingboxConfig.buildFullConfig(
      availableNodes,
      selectedTag: tag,
      port: proxyPort,
      apiPort: SingboxConfig.defaultApiPort,
      proxyMode: proxyMode,
      dnsMode: dnsMode,
      networkMode: overrideNetworkMode ?? networkMode,
      allowInsecure: allowInsecure,
    );
  }

  static bool _hasCoreConfig(NodeModel node) =>
      node.rawUri.isNotEmpty || node.rawOutbound != null;
}
