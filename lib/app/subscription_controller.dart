import 'package:flutter/foundation.dart';

import '../shared/models/app_models.dart';
import '../shared/models/subscription_runtime_state.dart';

/// Owns the subscription domain: the subscribe URL plus usage/quota metadata
/// (daily usage, traffic series, device limit, reset day, expiry). Pure data —
/// no actions. Extracted from [AppController].
class SubscriptionController extends ChangeNotifier {
  SubscriptionRuntimeState _state = const SubscriptionRuntimeState();
  SubscriptionRuntimeState get state => _state;

  String get subscribeUrl => _state.subscribeUrl;
  List<double> get dailyUsage => _state.dailyUsage;
  List<TrafficUsagePoint> get trafficUsage => _state.trafficUsage;
  int? get aliveIp => _state.aliveIp;
  int? get deviceLimit => _state.deviceLimit;
  int? get resetDay => _state.resetDay;
  int? get expiredAt => _state.expiredAt;

  void applySnapshot({
    String? subscribeUrl,
    List<double>? dailyUsage,
    List<TrafficUsagePoint>? trafficUsage,
    int? aliveIp,
    int? deviceLimit,
    int? resetDay,
    int? expiredAt,
  }) {
    _state = _state.copyWith(
      subscribeUrl: subscribeUrl,
      dailyUsage: dailyUsage,
      trafficUsage: trafficUsage,
      aliveIp: aliveIp,
      deviceLimit: deviceLimit,
      resetDay: resetDay,
      expiredAt: expiredAt,
    );
    notifyListeners();
  }

  void reset() {
    _state = const SubscriptionRuntimeState();
    notifyListeners();
  }
}
