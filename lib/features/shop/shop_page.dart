import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../l10n/l10n.dart';
import '../../shared/layout/app_platform.dart';
import '../../shared/models/app_models.dart';
import '../../shared/theme/app_spacing.dart';
import '../../shared/utils/formatters.dart';
import '../../shared/utils/traffic_summary_text.dart';
import '../../shared/widgets/app_toast.dart';
import 'order_confirm_dialog.dart';
import 'widgets/greenfield_shop_surface.dart';

class ShopPage extends StatefulWidget {
  const ShopPage({super.key});

  @override
  State<ShopPage> createState() => _ShopPageState();
}

class _ShopPageState extends State<ShopPage> {
  int _tab = 0;

  List<PlanModel> _filtered(List<PlanModel> plans) {
    return plans.where((plan) {
      return switch (_tab) {
        1 => plan.category == PlanCategory.recurring,
        2 => plan.category == PlanCategory.oneTime,
        3 => plan.category == PlanCategory.dataPack,
        _ => true,
      };
    }).toList();
  }

  Future<void> _handlePullRefresh() async {
    final ctrl = AppScope.of(context);
    await ctrl.refreshData();
    if (!mounted || ctrl.dataLoadError != null) return;
    AppToast.show(context, context.l10n.refreshed, type: AppToastType.success);
  }

  void _purchase(PlanModel plan, BillingCycle cycle) {
    final ctrl = AppScope.of(context);
    showOrderConfirmDialog(
      context: context,
      plan: plan,
      cycle: cycle,
      api: ctrl.api,
      onPaid: ctrl.refreshData,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = AppScope.of(context);
    final expiry = subscriptionExpiryDisplay(
      expiredAt: ctrl.expiredAt,
      expiryText: ctrl.user.expiry,
    );
    final expiryLabel = expiry.date.isEmpty ? context.l10n.permanent : expiry.date;
    final currentPlanName = ctrl.user.plan.trim().isEmpty
        ? context.l10n.currentPlan
        : ctrl.user.plan.trim();

    final surface = GreenfieldShopSurface(
      plans: _filtered(ctrl.plans),
      selectedTab: _tab,
      currencySymbol: ctrl.currencySymbol,
      hasActivePlan: ctrl.hasPlan,
      currentPlanName: currentPlanName,
      remainingTraffic: formatGb(ctrl.traffic.remainGb),
      expiryLabel: expiryLabel,
      onSelectedTab: (tab) => setState(() => _tab = tab),
      onPurchase: _purchase,
      showBack: ctrl.mobileProfileChildPage,
      onBack: () => ctrl.goToPage(AppPage.account),
    );

    if (!AppPlatform.usesTouch) return surface;

    return RefreshIndicator(
      onRefresh: _handlePullRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        children: [
          surface,
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }
}
