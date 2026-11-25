import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../commerce/v3_order_dialog.dart';
import 'v3_sheet.dart';

/// Continue using the existing checkout from the Usage detail header.
void openV3PlanRenewal(BuildContext context, AppController controller) {
  if (!controller.hasPlan) {
    controller.goToPage(AppPage.shop);
    return;
  }
  for (final plan in controller.plans) {
    if (int.tryParse(plan.id) == controller.currentPlanId) {
      showV3OrderDialog(
        context: context,
        plan: plan,
        initialCycle: v3DefaultCycle(plan),
        api: controller.api,
        currencySymbol: controller.currencySymbol,
        onPaid: controller.refreshData,
        onViewOrders: () => openV3Page(context, AppPage.orders),
      );
      return;
    }
  }
  controller.goToPage(AppPage.shop);
}
