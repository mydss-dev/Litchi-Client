import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/config/app_config.dart';
import 'package:litchi_client/shared/models/api_models.dart';
import 'package:litchi_client/shared/models/app_models.dart';
import 'package:litchi_client/shared/services/plan_data_service.dart';
import 'package:litchi_client/shared/services/traffic_data_service.dart';
import 'package:litchi_client/shared/services/user_data_service.dart';

void main() {
  test(
    'converts subscribe traffic and never returns negative remaining data',
    () {
      final traffic = UserDataService.trafficFromSubscribe(
        transferEnable: 2 * AppConfig.bytesPerGb,
        upload: 1.5 * AppConfig.bytesPerGb,
        download: AppConfig.bytesPerGb,
      );

      expect(traffic.totalGb, 2);
      expect(traffic.usedGb, 2.5);
      expect(traffic.remainGb, 0);
    },
  );

  test('finds plan by numeric id string', () {
    const plans = [
      PlanModel(
        id: 'basic',
        title: 'Basic',
        capacity: '100 GB',
        category: PlanCategory.recurring,
      ),
      PlanModel(
        id: '12',
        title: 'Pro',
        capacity: '500 GB',
        category: PlanCategory.recurring,
      ),
    ];

    expect(PlanDataService.planById(plans, 12)?.title, 'Pro');
    expect(PlanDataService.planById(plans, 99), isNull);
    expect(PlanDataService.planById(plans, null), isNull);
  });

  test('fresh plan title replaces stale account plan name', () {
    const user = UserModel(
      name: 'Tester',
      plan: 'Old Pro Name',
      avatarLetter: 'T',
      expiry: '2026-12-31',
    );
    const plans = [
      PlanModel(
        id: '12',
        title: 'Litchi Pro',
        capacity: '500 GB',
        category: PlanCategory.recurring,
      ),
    ];

    final updated = PlanDataService.syncCurrentPlanTitle(
      user: user,
      plans: plans,
      currentPlanId: 12,
    );

    expect(updated?.plan, 'Litchi Pro');
    expect(
      PlanDataService.syncCurrentPlanTitle(
        user: updated,
        plans: plans,
        currentPlanId: 12,
      ),
      isNull,
    );
  });

  test('aggregates traffic logs by local day and keeps points sorted', () {
    final result = TrafficDataService.fromLogs([
      RemoteTrafficLog(
        date: DateTime(2026, 6, 15, 12),
        upload: AppConfig.bytesPerGb,
        download: 2 * AppConfig.bytesPerGb,
        serverRate: 1,
        traffic: 3 * AppConfig.bytesPerGb,
      ),
      RemoteTrafficLog(
        date: DateTime(2026, 6, 14, 23),
        upload: 0.5 * AppConfig.bytesPerGb,
        download: 0.5 * AppConfig.bytesPerGb,
        serverRate: 1,
        traffic: AppConfig.bytesPerGb,
      ),
      RemoteTrafficLog(
        date: DateTime(2026, 6, 15, 18),
        upload: AppConfig.bytesPerGb,
        download: AppConfig.bytesPerGb,
        serverRate: 1,
        traffic: 2 * AppConfig.bytesPerGb,
      ),
    ]);

    expect(result.trafficUsage, hasLength(2));
    expect(result.trafficUsage.first.date, DateTime(2026, 6, 14));
    expect(result.trafficUsage.first.totalGb, 1);
    expect(result.trafficUsage.last.date, DateTime(2026, 6, 15));
    expect(result.trafficUsage.last.totalGb, 5);
    expect(result.trafficUsage.last.uploadGb, 2);
    expect(result.trafficUsage.last.downloadGb, 3);
    expect(result.dailyUsage, [1, 5]);
  });
}
