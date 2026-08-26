import '../../config/app_config.dart';
import '../models/api_models.dart';
import '../models/app_models.dart';
import '../models/model_mappers.dart';
import 'panel_api.dart';

class SubscriptionNodesResult {
  const SubscriptionNodesResult({
    this.nodes = const [],
    this.traffic,
  });

  final List<NodeModel> nodes;
  final TrafficModel? traffic;
}

class SubscriptionDataService {
  const SubscriptionDataService(this._api);

  final PanelApi _api;

  Future<SubscriptionNodesResult> loadNodes(String subscribeUrl) async {
    if (subscribeUrl.trim().isEmpty) return const SubscriptionNodesResult();

    final result = await _api.fetchSubscription(subscribeUrl);
    return SubscriptionNodesResult(
      nodes: result.nodes.map(ModelMappers.toNode).toList(),
      traffic: trafficFromSubTraffic(result.traffic),
    );
  }

  static TrafficModel? trafficFromSubTraffic(SubTraffic? traffic) {
    if (traffic == null || traffic.total <= 0) return null;
    final total = traffic.total / AppConfig.bytesPerGb;
    final used = (traffic.upload + traffic.download) / AppConfig.bytesPerGb;
    final remain = (total - used).clamp(0.0, double.infinity);
    return TrafficModel(totalGb: total, usedGb: used, remainGb: remain);
  }
}
