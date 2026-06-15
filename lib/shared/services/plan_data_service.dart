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
    final currentPlan = planById(plans, currentPlanId);
    final user = currentUser;
    return PlanDataResult(
      plans: plans,
      user: user != null && user.plan.trim().isEmpty && currentPlan != null
          ? user.copyWith(plan: currentPlan.title)
          : null,
    );
  }

  static PlanModel? planById(List<PlanModel> plans, int? id) {
    if (id == null || id <= 0) return null;
    for (final plan in plans) {
      if (int.tryParse(plan.id) == id) return plan;
    }
    return null;
  }
}
