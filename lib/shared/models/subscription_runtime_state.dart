import 'app_models.dart';

class SubscriptionRuntimeState {
  const SubscriptionRuntimeState({
    this.subscribeUrl = '',
    this.dailyUsage = const [],
    this.trafficUsage = const [],
    this.aliveIp,
    this.deviceLimit,
    this.resetDay,
    this.expiredAt,
  });

  final String subscribeUrl;
  final List<double> dailyUsage;
  final List<TrafficUsagePoint> trafficUsage;
  final int? aliveIp;
  final int? deviceLimit;
  final int? resetDay;
  final int? expiredAt;

  SubscriptionRuntimeState copyWith({
    String? subscribeUrl,
    List<double>? dailyUsage,
    List<TrafficUsagePoint>? trafficUsage,
    int? aliveIp,
    int? deviceLimit,
    int? resetDay,
    int? expiredAt,
  }) {
    return SubscriptionRuntimeState(
      subscribeUrl: subscribeUrl ?? this.subscribeUrl,
      dailyUsage: dailyUsage ?? this.dailyUsage,
      trafficUsage: trafficUsage ?? this.trafficUsage,
      aliveIp: aliveIp ?? this.aliveIp,
      deviceLimit: deviceLimit ?? this.deviceLimit,
      resetDay: resetDay ?? this.resetDay,
      expiredAt: expiredAt ?? this.expiredAt,
    );
  }
}
