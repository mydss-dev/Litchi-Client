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

    final effectiveLocalDns = localDnsServers ?? this.localDnsServers;
    final config = SingBoxConfig.buildFullConfig(
      availableNodes,
      selectedTag: selectedSingBoxTag,
      port: overrideProxyPort ?? proxyPort,
      apiPort: apiPort,
      apiSecret: apiSecret,
      proxyMode: proxyMode,
      dnsMode: dnsMode,
      networkMode: overrideNetworkMode ?? networkMode,
      allowInsecure: allowInsecure,
      localDnsServers: effectiveLocalDns,
    );
    if (config == null) return null;

    // A non-empty local DNS snapshot is supplied only while the privileged
    // Windows TUN bridge is active. At that point the bridge is dual-stack, so
    // allow proxied destinations to resolve A and AAAA while keeping IPv4
    // preferred for compatibility. Node/bootstrap resolution remains
    // `ipv4_only` in route.default_domain_resolver and therefore does not
    // require node AAAA records.
    //
    // Mainland domains remain IPv4-only: they are routed direct by the main
    // core, and advertising an artificial TUN IPv6 route must not make an
    // IPv4-only physical network select an unreachable direct IPv6 target.
    if (effectiveLocalDns.isNotEmpty) {
      final dns = config['dns'];
      if (dns is Map<String, dynamic>) {
        dns['strategy'] = 'prefer_ipv4';
        final rules = dns['rules'];
        if (rules is List) {
          for (final rule in rules.whereType<Map<String, dynamic>>()) {
            final ruleSet = rule['rule_set'];
            if (ruleSet is List && ruleSet.contains('geosite-cn')) {
              rule['strategy'] = 'ipv4_only';
            }
          }
        }
      }
    }
    return config;
  }
}
