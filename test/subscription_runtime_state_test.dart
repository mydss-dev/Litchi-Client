import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/shared/models/app_models.dart';
import 'package:litchi_client/shared/models/subscription_runtime_state.dart';

void main() {
  test('defaults to an empty subscription runtime state', () {
    const state = SubscriptionRuntimeState();

    expect(state.subscribeUrl, isEmpty);
    expect(state.dailyUsage, isEmpty);
    expect(state.trafficUsage, isEmpty);
    expect(state.aliveIp, isNull);
    expect(state.deviceLimit, isNull);
    expect(state.resetDay, isNull);
    expect(state.expiredAt, isNull);
  });

  test('copyWith updates provided fields and preserves omitted fields', () {
    final state = SubscriptionRuntimeState(
      subscribeUrl: 'https://example.com/sub',
      dailyUsage: const [1, 2],
      trafficUsage: [
        TrafficUsagePoint(date: DateTime(2026, 6, 15), totalGb: 3),
      ],
      aliveIp: 2,
    );

    final updated = state.copyWith(deviceLimit: 5, resetDay: 20);

    expect(updated.subscribeUrl, 'https://example.com/sub');
    expect(updated.dailyUsage, [1, 2]);
    expect(updated.trafficUsage, hasLength(1));
    expect(updated.aliveIp, 2);
    expect(updated.deviceLimit, 5);
    expect(updated.resetDay, 20);
  });
}
