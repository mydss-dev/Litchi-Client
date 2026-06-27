import 'package:flutter/foundation.dart';

import '../shared/models/app_models.dart';

/// Owns the subscription domain: subscribe URL + usage/quota metadata
/// (daily usage, traffic series, alive IP, device limit, reset day, expiry)
/// plus server-supplied rules and rule-providers from Clash YAML.
/// Pure data, no actions. Extracted from [AppController].
class SubscriptionController extends ChangeNotifier {
  String _subscribeUrl = '';
  List<double> _dailyUsage = const [];
  List<TrafficUsagePoint> _trafficUsage = const [];
  int? _aliveIp;
  int? _deviceLimit;
  int? _resetDay;
  int? _expiredAt;
  List<String> _rules = const [];
  Map<String, dynamic> _ruleProviders = const {};

  String get subscribeUrl => _subscribeUrl;
  List<double> get dailyUsage => _dailyUsage;
  List<TrafficUsagePoint> get trafficUsage => _trafficUsage;
  int? get aliveIp => _aliveIp;
  int? get deviceLimit => _deviceLimit;
  int? get resetDay => _resetDay;
  int? get expiredAt => _expiredAt;
  List<String> get rules => _rules;
  Map<String, dynamic> get ruleProviders => _ruleProviders;

  /// Applies subscription fields from a snapshot. Null fields are skipped,
  /// matching the previous `if (snap.x != null) _x = ...` semantics.
  void applySnapshot({
    String? subscribeUrl,
    List<double>? dailyUsage,
    List<TrafficUsagePoint>? trafficUsage,
    int? aliveIp,
    int? deviceLimit,
    int? resetDay,
    int? expiredAt,
    List<String>? rules,
    Map<String, dynamic>? ruleProviders,
  }) {
    if (subscribeUrl != null) _subscribeUrl = subscribeUrl;
    if (dailyUsage != null) _dailyUsage = dailyUsage;
    if (trafficUsage != null) _trafficUsage = trafficUsage;
    if (aliveIp != null) _aliveIp = aliveIp;
    if (deviceLimit != null) _deviceLimit = deviceLimit;
    if (resetDay != null) _resetDay = resetDay;
    if (expiredAt != null) _expiredAt = expiredAt;
    if (rules != null) _rules = rules;
    if (ruleProviders != null) _ruleProviders = ruleProviders;
    notifyListeners();
  }

  void reset() {
    _subscribeUrl = '';
    _dailyUsage = const [];
    _trafficUsage = const [];
    _aliveIp = null;
    _deviceLimit = null;
    _resetDay = null;
    _expiredAt = null;
    _rules = const [];
    _ruleProviders = const {};
    notifyListeners();
  }
}
