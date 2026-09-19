import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/config/app_config.dart';
import 'package:litchi_client/config/panel_backend.dart';
import 'package:litchi_client/shared/models/api_models.dart';
import 'package:litchi_client/shared/models/app_models.dart';
import 'package:litchi_client/shared/services/api_client.dart';
import 'package:litchi_client/shared/services/data_loader.dart';
import 'package:litchi_client/shared/services/panel_api.dart';

class _StubPanelApi extends PanelApi {
  _StubPanelApi({required this.plans, required this.logs}) : super(ApiClient());

  final Future<List<RemotePlan>> Function() plans;
  final Future<List<RemoteTrafficLog>> Function() logs;

  @override
  Future<List<RemotePlan>> getPlans() => plans();

  @override
  Future<List<RemoteTrafficLog>> getTrafficLog() => logs();

  @override
  Future<RemoteInvite> getInviteInfo() async =>
      throw StateError('invite not part of this test');
}

void main() {
  final originalFeatures = AppConfig.panelFeatures;
  setUp(() => AppConfig.panelFeatures = PanelFeatures.legacy);
  tearDown(() => AppConfig.panelFeatures = originalFeatures);

  test('successful empty plan catalog overwrites a previous catalog', () async {
    final loader = DataLoader(
      _StubPanelApi(plans: () async => [], logs: () async => []),
    );
    final snap = DataSnapshot()
      ..plans = const [
        PlanModel(
          id: '7',
          title: 'Old plan',
          capacity: '100 GB',
          category: PlanCategory.recurring,
        ),
      ];

    await loader.loadPrimary(snap);
    expect(snap.plans, isEmpty);
  });

  test('failed plan catalog fetch leaves its snapshot field unknown', () async {
    final loader = DataLoader(
      _StubPanelApi(
        plans: () async => throw StateError('catalog offline'),
        logs: () async => [],
      ),
    );
    final snap = DataSnapshot();

    await loader.loadPrimary(snap);
    expect(snap.plans, isNull);
  });

  test('nonempty plan catalog still maps products', () async {
    final loader = DataLoader(
      _StubPanelApi(
        plans: () async => [
          RemotePlan(id: 7, name: 'New plan', transferEnable: 100, show: 1),
        ],
        logs: () async => [],
      ),
    );
    final snap = DataSnapshot();

    await loader.loadPrimary(snap);
    expect(snap.plans, hasLength(1));
    expect(snap.plans!.single.title, 'New plan');
  });

  test('successful empty traffic history clears stale points', () async {
    final loader = DataLoader(
      _StubPanelApi(plans: () async => [], logs: () async => []),
    );
    final snap = DataSnapshot()
      ..dailyUsage = [5]
      ..trafficUsage = [
        TrafficUsagePoint(date: DateTime(2026, 9, 18), totalGb: 5),
      ];

    await loader.loadSecondary(snap);
    expect(snap.dailyUsage, isEmpty);
    expect(snap.trafficUsage, isEmpty);
  });

  test('failed traffic history fetch leaves history unknown', () async {
    final loader = DataLoader(
      _StubPanelApi(
        plans: () async => [],
        logs: () async => throw StateError('history offline'),
      ),
    );
    final snap = DataSnapshot();

    await loader.loadSecondary(snap);
    expect(snap.dailyUsage, isNull);
    expect(snap.trafficUsage, isNull);
  });

  test('nonempty traffic history still produces daily usage', () async {
    final loader = DataLoader(
      _StubPanelApi(
        plans: () async => [],
        logs: () async => [
          RemoteTrafficLog(
            date: DateTime(2026, 9, 18),
            upload: AppConfig.bytesPerGb,
            download: 0,
            traffic: AppConfig.bytesPerGb,
            serverRate: 1,
          ),
        ],
      ),
    );
    final snap = DataSnapshot();

    await loader.loadSecondary(snap);
    expect(snap.dailyUsage, [1]);
    expect(snap.trafficUsage, hasLength(1));
  });
}
