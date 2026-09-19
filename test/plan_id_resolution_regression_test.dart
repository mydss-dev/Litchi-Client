import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/config/app_config.dart';
import 'package:litchi_client/config/panel_backend.dart';
import 'package:litchi_client/shared/models/api_models.dart';
import 'package:litchi_client/shared/models/model_mappers.dart';
import 'package:litchi_client/shared/services/api_client.dart';
import 'package:litchi_client/shared/services/data_loader.dart';
import 'package:litchi_client/shared/services/panel_api.dart';
import 'package:litchi_client/shared/services/plan_data_service.dart';

class _PlanApi extends PanelApi {
  _PlanApi(this.user, this.subscription, this.catalog) : super(ApiClient());

  final RemoteUser user;
  final RemoteSubscribe subscription;
  final List<RemotePlan> catalog;

  @override
  Future<RemoteUser> getUserInfo({bool silent = false}) async => user;

  @override
  Future<RemoteSubscribe> getSubscribeInfo({bool silent = false}) async => subscription;

  @override
  Future<List<RemotePlan>> getPlans() async => catalog;
}

void main() {
  final originalFeatures = AppConfig.panelFeatures;
  setUp(() => AppConfig.panelFeatures = PanelFeatures.legacy);
  tearDown(() => AppConfig.panelFeatures = originalFeatures);

  final catalogItem = RemotePlan.fromJson({
    'id': '42',
    'name': 'Litchi Prime',
    'transfer_enable': 1024,
  });

  test('store plan string ID remains usable for current-plan title', () {
    final mapped = ModelMappers.toPlan(catalogItem);
    expect(catalogItem.id, 42);
    expect(mapped.id, '42');
    expect(PlanDataService.planById([mapped], 42)?.title, 'Litchi Prime');
  });

  test('subscription ID replaces account zero and resolves store title', () async {
    final loader = DataLoader(_PlanApi(
      RemoteUser.fromJson({
        'id': 1,
        'email': 'member@example.com',
        'plan_id': 0,
      }),
      RemoteSubscribe.fromJson({
        'plan_id': '42',
        'subscribe_url': '',
        'transfer_enable': 100,
      }),
      [catalogItem],
    ));
    final snap = await loader.loadAccountStatus();
    expect(snap.hasPlan, isTrue);
    expect(snap.currentPlanId, 42);
    await loader.loadPrimary(snap);
    expect(PlanDataService.planById(snap.plans!, snap.currentPlanId)?.title,
        'Litchi Prime');
  });

  test('subscription current ID takes precedence over stale account ID', () async {
    final loader = DataLoader(_PlanApi(
      RemoteUser.fromJson({
        'id': 1,
        'email': 'member@example.com',
        'plan_id': 7,
      }),
      RemoteSubscribe.fromJson({'plan_id': 42}),
      [catalogItem],
    ));
    final snap = await loader.loadAccountStatus();
    expect(snap.currentPlanId, 42);
    await loader.loadPrimary(snap);
    expect(PlanDataService.planById(snap.plans!, snap.currentPlanId)?.title,
        'Litchi Prime');
  });

  test('missing subscription ID preserves positive account ID', () async {
    final loader = DataLoader(_PlanApi(
      RemoteUser.fromJson({
        'id': 1,
        'email': 'member@example.com',
        'plan_id': 42,
      }),
      RemoteSubscribe.fromJson({'plan_id': 0}),
      [catalogItem],
    ));
    final snap = await loader.loadAccountStatus();
    expect(snap.currentPlanId, 42);
  });
}
