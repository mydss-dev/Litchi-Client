import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../app/nav_destinations.dart';
import '../../l10n/l10n.dart';
import '../../shared/utils/traffic_metrics.dart';
import '../../shared/utils/traffic_summary_text.dart';
import '../../shared/widgets/app_toast.dart';
import '../../shared/widgets/no_plan_card.dart';
import '../../shared/widgets/responsive_page_scaffold.dart';
import 'widgets/greenfield_traffic_surface.dart';
import 'widgets/traffic_presentation_theme.dart';

class GreenfieldTrafficPage extends StatefulWidget {
  const GreenfieldTrafficPage({super.key});

  @override
  State<GreenfieldTrafficPage> createState() => _GreenfieldTrafficPageState();
}

class _GreenfieldTrafficPageState extends State<GreenfieldTrafficPage> {
  int _periodDays = 7;

  Future<void> _refresh() async {
    final controller = AppScope.of(context);
    await controller.refreshData();
    if (!mounted || controller.dataLoadError != null) return;
    AppToast.show(
      context,
      context.l10n.refreshed,
      type: AppToastType.success,
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final noPlan =
        controller.hasAccountSummary &&
        !controller.isInitialLoading &&
        !controller.hasPlan;

    final children = <Widget>[];
    if (noPlan) {
      children.add(
        NoPlanCard(
          onPurchase: isPageEnabled(AppPage.shop)
              ? () => controller.goToPage(AppPage.shop)
              : null,
        ),
      );
    } else {
      final expiry = subscriptionExpiryDisplay(
        expiredAt: controller.expiredAt,
        expiryText: controller.user.expiry,
      );
      final resetDay = validResetDay(controller.resetDay);
      final resetDays = resetDay == null
          ? null
          : daysUntilMonthlyReset(resetDay);
      final todayTrafficGb = controller.todayTrafficGb;

      children.add(
        TrafficPresentationTheme(
          child: GreenfieldTrafficSurface(
            traffic: controller.traffic,
            todayTrafficGb: todayTrafficGb,
            todayComparison: yesterdayComparisonText(
              context,
              usage: controller.trafficUsage,
              currentGb: todayTrafficGb,
            ),
            expiryDays: expiry.days,
            expiryDate: expiry.date,
            resetDay: resetDay,
            resetDays: resetDays,
            usage: controller.trafficUsage,
            fallbackDailyUsage: controller.dailyUsage,
            periodDays: _periodDays,
            onPeriodChanged: (value) => setState(() => _periodDays = value),
          ),
        ),
      );
    }

    return ResponsivePageScaffold(
      title: context.l10n.trafficStatistics,
      subtitle: context.l10n.trafficStatisticsSubtitle,
      compactTitle: context.l10n.usage,
      compactSubtitle: context.l10n.usageSubtitle,
      primaryCompact: isPrimaryCompactTab(AppPage.traffic),
      onRefresh: _refresh,
      onBack: () => controller.goToPage(AppPage.account),
      children: children,
    );
  }
}
