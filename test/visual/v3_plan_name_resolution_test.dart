import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/app/app_controller.dart';
import 'package:litchi_client/app/plan_presentation.dart';
import 'package:litchi_client/shared/models/api_models.dart';
import 'package:litchi_client/shared/models/app_models.dart';

import 'v3_visual_fixture.dart';

class _ChangingPlanController extends VisualV3Controller {
  _ChangingPlanController() : super(AppPage.dashboard);

  @override
  UserModel get user => const UserModel(
    name: 'Member', plan: 'Old cached plan', avatarLetter: 'M',
    expiry: '2026-12-31');

  @override
  RemoteUser? get accountDetails => const RemoteUser(
    id: 1, email: 'member@example.com', expiredAt: 1798675200,
    balance: 0, transferEnable: 512, used: 0, subscribeStatus: 0,
    planId: 7, planName: 'Old remote plan', remindExpire: false,
    remindTraffic: false, autoRenewal: false);

  @override
  int? get currentPlanId => 8;

  @override
  List<PlanModel> get plans => const [
    PlanModel(id: '008', title: 'Real backend plan', capacity: '512 GB',
      category: PlanCategory.recurring, monthlyPrice: 12.8),
  ];
}

void main() {
  // AppController reads WidgetsBinding.instance during construction.
  TestWidgetsFlutterBinding.ensureInitialized();

  test('matching catalog ID wins over old cached and remote titles', () {
    final controller = _ChangingPlanController();
    addTearDown(controller.disposeVisual);
    final plan = PlanPresentation.fromController(controller);
    expect(plan.name, 'Real backend plan');
    expect(plan.shortLabel, startsWith('Real backend plan ·'));
  });

  test('a synthetic expired label cannot replace a real API plan name', () {
    expect(PlanPresentation.nameFromEvidence(
      userName: '已到期', remoteName: 'Litchi Prime', catalogName: '',
      currentPlanId: 9, remotePlanId: 9,
    ), 'Litchi Prime');
  });

  test('mismatched account ID cannot name the current subscription', () {
    expect(PlanPresentation.nameFromEvidence(
      userName: 'Old cached plan', remoteName: 'Old remote plan',
      catalogName: '', currentPlanId: 9, remotePlanId: 7,
    ), '当前套餐（ID 9）');
  });

  test('direct backend title is used without a catalog match', () {
    expect(PlanPresentation.nameFromEvidence(
      userName: '', remoteName: 'Litchi Ultra', catalogName: '',
      currentPlanId: 8, remotePlanId: 8,
    ), 'Litchi Ultra');
  });

  test('no evidence never invents a product name', () {
    expect(PlanPresentation.nameFromEvidence(
      userName: '', remoteName: '', catalogName: '',
      currentPlanId: 8,
    ), '当前套餐（ID 8）');
    expect(PlanPresentation.nameFromEvidence(
      userName: '已到期', remoteName: '', catalogName: '',
    ), '套餐名称待同步');
  });
}
