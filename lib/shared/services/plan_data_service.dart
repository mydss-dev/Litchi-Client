import '../models/app_models.dart';
import '../models/model_mappers.dart';
import 'panel_api.dart';

class PlanDataResult {
  const PlanDataResult({this.plans = const [], this.user});

  final List<PlanModel> plans;
  final UserModel? user;
}

class PlanDataService {
  const PlanDataService(this._api);

  final PanelApi _api;

  Future<PlanDataResult> loadPlans({
    required int? currentPlanId,
    required UserModel? currentUser,
  }) async {
    final remotePlans = await _api.getPlans();
    if (remotePlans.isEmpty) return const PlanDataResult();

    final plans = remotePlans.map(ModelMappers.toPlan).toList();
    return PlanDataResult(
      plans: plans,
      user: syncCurrentPlanTitle(
        user: currentUser,
        plans: plans,
        currentPlanId: currentPlanId,
      ),
    );
  }

  static UserModel? syncCurrentPlanTitle({
    required UserModel? user,
    required List<PlanModel> plans,
    required int? currentPlanId,
  }) {
    if (user == null) return null;
    final currentPlan = planById(plans, currentPlanId);
    if (currentPlan == null) return null;
    final freshTitle = currentPlan.title.trim();
    if (freshTitle.isEmpty || user.plan.trim() == freshTitle) return null;
    return user.copyWith(plan: currentPlan.title);
  }

  static PlanModel? planById(List<PlanModel> plans, int? id) {
    if (id == null || id <= 0) return null;
    for (final plan in plans) {
      if (int.tryParse(plan.id) == id) return plan;
    }
    return null;
  }
}
