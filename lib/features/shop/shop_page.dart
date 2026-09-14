import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/app_controller.dart';
import '../../l10n/l10n.dart';
import '../../shared/layout/app_adaptive_layout.dart';
import '../../shared/layout/app_layout.dart';
import '../../shared/layout/app_platform.dart';
import '../../shared/models/app_models.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_radius.dart';
import '../../shared/theme/app_text_styles.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_segmented_control.dart';
import '../../shared/widgets/app_toast.dart';
import '../../shared/widgets/page_status_cards.dart';
import 'order_confirm_dialog.dart';

/// Shop / plans page.
///
/// Width class owns plan-grid geometry while platform identity only controls
/// interaction behavior such as pull-to-refresh and touch-first card density.
/// Pricing, billing-cycle selection and checkout behavior remain shared.
class ShopPage extends StatefulWidget {
  const ShopPage({super.key});

  @override
  State<ShopPage> createState() => _ShopPageState();
}

class _ShopPageState extends State<ShopPage> {
  int _tab = 0;

  List<String> _tabs(BuildContext context) => [
    context.l10n.all,
    context.l10n.recurringPlan,
    context.l10n.oneTime,
    context.l10n.dataPack,
  ];

  Widget _emptyPlans(BuildContext context) => SizedBox(
    height: 220,
    child: AppEmptyState(
      icon: LucideIcons.packageOpen,
      title: context.l10n.noPlans,
      subtitle: context.l10n.refreshLater,
    ),
  );

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

  @override
  Widget build(BuildContext context) {
    final touch = AppPlatform.usesTouch;

    return AppAdaptiveLayout(
      compact: (context, _) => touch
          ? _buildTouch(context, columns: 1, scrollTabs: true)
          : _buildDesktop(context, columns: 1, scrollTabs: true),
      medium: (context, _) => touch
          ? _buildTouch(context, columns: 2)
          : _buildDesktop(context, columns: 2),
      expanded: (context, _) => touch
          ? _buildTouch(context, columns: 3)
          : _buildDesktop(context, columns: 3),
    );
  }

  Widget _buildDesktop(
    BuildContext context, {
    required int columns,
    bool scrollTabs = false,
  }) {
    final ctrl = AppScope.of(context);
    final plans = _filtered(ctrl.plans);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ShopTabs(
          tabs: _tabs(context),
          selected: _tab,
          scrollable: scrollTabs,
          onSelected: (index) => setState(() => _tab = index),
        ),
        const SizedBox(height: AppLayoutMetrics.sectionGap),
        if (plans.isEmpty)
          _emptyPlans(context)
        else
          _PlanGrid(plans: plans, columns: columns, touch: false),
      ],
    );
  }

  Widget _buildTouch(
    BuildContext context, {
    required int columns,
    bool scrollTabs = false,
  }) {
    final ctrl = AppScope.of(context);
    final plans = _filtered(ctrl.plans);
    final asChild = ctrl.mobileProfileChildPage;

    return RefreshIndicator(
      onRefresh: _handlePullRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        children: [
          if (asChild) ...[
            Row(
              children: [
                PageBackButton(onTap: () => ctrl.goToPage(AppPage.account)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    context.l10n.planPurchase,
                    style: AppTextStyles.pageTitle,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppLayoutMetrics.sectionGap),
          ],
          _ShopTabs(
            tabs: _tabs(context),
            selected: _tab,
            scrollable: scrollTabs,
            onSelected: (index) => setState(() => _tab = index),
          ),
          const SizedBox(height: AppLayoutMetrics.sectionGap),
          if (plans.isEmpty)
            _emptyPlans(context)
          else
            _PlanGrid(plans: plans, columns: columns, touch: true),
        ],
      ),
    );
  }
}

class _PlanGrid extends StatelessWidget {
  const _PlanGrid({
    required this.plans,
    required this.columns,
    required this.touch,
  });

  final List<PlanModel> plans;
  final int columns;
  final bool touch;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = AppLayoutMetrics.sectionGap;
        final cardWidth = columns <= 1
            ? constraints.maxWidth
            : (constraints.maxWidth - gap * (columns - 1)) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final plan in plans)
              SizedBox(
                width: cardWidth,
                child: _PlanCard(
                  key: ValueKey(plan.id),
                  plan: plan,
                  compact: touch,
                  desktop: !touch,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ShopTabs extends StatelessWidget {
  const _ShopTabs({
    required this.tabs,
    required this.selected,
    required this.onSelected,
    this.scrollable = false,
  });

  final List<String> tabs;
  final int selected;
  final ValueChanged<int> onSelected;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final control = AppSegmentedControl<int>(
      selected: selected,
      onChanged: onSelected,
      items: [
        for (var index = 0; index < tabs.length; index++)
          AppSegmentedItem(value: index, label: tabs[index]),
      ],
    );

    if (!scrollable) {
      return SizedBox(width: double.infinity, child: control);
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: control,
    );
  }
}

class _PlanCard extends StatefulWidget {
  const _PlanCard({
    super.key,
    required this.plan,
    this.compact = false,
    this.desktop = false,
  });

  final PlanModel plan;
  final bool compact;
  final bool desktop;

  @override
  State<_PlanCard> createState() => _PlanCardState();
}

class _PlanCardState extends State<_PlanCard> {
  late BillingCycle _cycle;

  PlanModel get plan => widget.plan;

  @override
  void initState() {
    super.initState();
    final cycles = _availableCycles;
    _cycle = cycles.isEmpty ? BillingCycle.monthly : cycles.first;
  }

  @override
  void didUpdateWidget(covariant _PlanCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final cycles = _availableCycles;
    if (!cycles.contains(_cycle)) {
      _cycle = cycles.isEmpty ? BillingCycle.monthly : cycles.first;
    }
  }

  List<BillingCycle> get _cycleOptions {
    if (plan.category != PlanCategory.recurring) return const [];
    return const [
      BillingCycle.monthly,
      BillingCycle.quarterly,
      BillingCycle.halfYear,
      BillingCycle.yearly,
    ];
  }

  List<BillingCycle> get _availableCycles => _cycleOptions
      .where((cycle) => plan.priceForCycle(cycle) != null)
      .toList();

  double? get _price {
    if (plan.category == PlanCategory.recurring) {
      return plan.priceForCycle(_cycle) ??
          plan.monthlyPrice ??
          plan.quarterlyPrice ??
          plan.halfYearPrice ??
          plan.yearlyPrice ??
          plan.twoYearPrice ??
          plan.threeYearPrice;
    }
    return plan.oneTimePrice ??
        plan.monthlyPrice ??
        plan.quarterlyPrice ??
        plan.halfYearPrice ??
        plan.yearlyPrice ??
        plan.twoYearPrice ??
        plan.threeYearPrice;
  }

  String _unit(BuildContext context) => switch (plan.category) {
    PlanCategory.recurring => _cycleUnit(context, _cycle),
    PlanCategory.oneTime => context.l10n.unlimitedTime,
    PlanCategory.dataPack => '',
  };

  String _categoryLabel(BuildContext context) => switch (plan.category) {
    PlanCategory.recurring => context.l10n.recurringPlan,
    PlanCategory.oneTime => context.l10n.oneTimePlan,
    PlanCategory.dataPack => context.l10n.dataPack,
  };

  String _metaText(BuildContext context) {
    final parts = <String>[_categoryLabel(context)];
    final capacity = plan.capacity.trim();
    if (_hasCapacity(plan)) parts.add(capacity);
    if (plan.deviceLimit != null) {
      parts.add(
        plan.deviceLimit! > 0
            ? context.l10n.devicesCount(plan.deviceLimit!)
            : context.l10n.unlimitedDevices,
      );
    }
    return parts.join(' · ');
  }

  IconData get _icon => switch (plan.category) {
    PlanCategory.recurring => LucideIcons.zap,
    PlanCategory.oneTime => LucideIcons.box,
    PlanCategory.dataPack => LucideIcons.plus,
  };

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final ctrl = AppScope.of(context);
    final price = _price;
    final features = plan.features
        .map(_cleanFeature)
        .take(widget.compact ? 4 : 3)
        .toList();
    final canBuy = price != null && !plan.soldOut;

    return AppCard(
      height: widget.desktop ? 390 : null,
      padding: const EdgeInsets.all(16),
      radius: AppRadius.card,
      borderColor: plan.featured ? c.primary : c.softBorder,
      borderWidth: plan.featured ? 1.3 : 1,
      shadow: AppCardShadow.soft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: widget.desktop ? 38 : 42,
                height: widget.desktop ? 38 : 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: c.primarySoft,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(
                  _icon,
                  color: c.primary,
                  size: widget.desktop ? 18 : 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodyStrong.copyWith(
                        color: c.textPrimary,
                        fontSize: widget.desktop ? 15 : 16,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _metaText(context),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption.copyWith(
                        color: c.textMuted,
                        fontSize: widget.desktop ? 10.5 : null,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              if (plan.soldOut)
                _MiniBadge(text: context.l10n.soldOut, color: c.danger)
              else if (plan.capacityLimit != null &&
                  plan.capacityLimit! > 0 &&
                  plan.capacityLimit! < 5)
                _MiniBadge(
                  text: context.l10n.lowStockRemaining(plan.capacityLimit!),
                  color: c.warning,
                )
              else if (plan.hot)
                _MiniBadge(text: context.l10n.popular, color: c.danger)
              else if (plan.featured)
                _MiniBadge(text: context.l10n.recommended, color: c.primary),
            ],
          ),
          SizedBox(height: widget.compact ? 20 : 14),
          _PricePanel(
            symbol: ctrl.currencySymbol,
            price: price,
            unit: _unit(context),
            desktop: widget.desktop,
          ),
          if (_cycleOptions.isNotEmpty) ...[
            const SizedBox(height: 12),
            _CycleSelector(
              cycles: _cycleOptions,
              enabledCycles: _availableCycles,
              selected: _cycle,
              onChanged: (cycle) => setState(() => _cycle = cycle),
            ),
          ],
          if (features.isNotEmpty) ...[
            const SizedBox(height: 12),
            _FeatureList(features: features),
          ],
          if (widget.compact) const SizedBox(height: 14) else const Spacer(),
          AppButton(
            label: canBuy
                ? context.l10n.buyNow
                : plan.soldOut
                ? context.l10n.soldOut
                : context.l10n.unavailableForPurchase,
            onPressed: !canBuy
                ? null
                : () => showOrderConfirmDialog(
                    context: context,
                    plan: plan,
                    cycle: _cycle,
                    api: ctrl.api,
                    onPaid: ctrl.refreshData,
                  ),
            expand: true,
          ),
        ],
      ),
    );
  }
}

class _CycleSelector extends StatelessWidget {
  const _CycleSelector({
    required this.cycles,
    required this.enabledCycles,
    required this.selected,
    required this.onChanged,
  });

  final List<BillingCycle> cycles;
  final List<BillingCycle> enabledCycles;
  final BillingCycle selected;
  final ValueChanged<BillingCycle> onChanged;

  @override
  Widget build(BuildContext context) {
    return AppSegmentedControl<BillingCycle>(
      selected: selected,
      onChanged: onChanged,
      items: [
        for (final cycle in cycles)
          AppSegmentedItem(
            value: cycle,
            label: _cycleLabel(context, cycle),
            enabled: enabledCycles.contains(cycle),
          ),
      ],
    );
  }
}

class _PricePanel extends StatelessWidget {
  const _PricePanel({
    required this.symbol,
    required this.price,
    required this.unit,
    this.desktop = false,
  });

  final String symbol;
  final double? price;
  final String unit;
  final bool desktop;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Padding(
            padding: EdgeInsets.only(bottom: desktop ? 6 : 7),
            child: Text(
              symbol,
              style: AppTextStyles.bodyStrong.copyWith(color: c.textPrimary),
            ),
          ),
          Text(
            price == null ? '--' : price!.toStringAsFixed(0),
            style: AppTextStyles.largeNumber(fontSize: desktop ? 34 : 38)
                .copyWith(color: c.textPrimary),
          ),
          if (unit.isNotEmpty) ...[
            const SizedBox(width: 6),
            Padding(
              padding: EdgeInsets.only(bottom: desktop ? 7 : 8),
              child: Text(
                unit,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption.copyWith(color: c.textMuted),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FeatureList extends StatelessWidget {
  const _FeatureList({required this.features});

  final List<String> features;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Column(
      children: [
        for (var i = 0; i < features.length; i++) ...[
          Row(
            children: [
              Icon(LucideIcons.check, size: 15, color: c.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  features[i],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(color: c.textSecondary),
                ),
              ),
            ],
          ),
          if (i != features.length - 1) const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _MiniBadge extends StatelessWidget {
  const _MiniBadge({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 104),
      child: Container(
        height: 22,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.badge.copyWith(color: color, fontSize: 10),
        ),
      ),
    );
  }
}

String _cycleLabel(BuildContext context, BillingCycle cycle) => switch (cycle) {
  BillingCycle.monthly => context.l10n.monthly,
  BillingCycle.quarterly => context.l10n.quarterly,
  BillingCycle.halfYear => context.l10n.halfYear,
  BillingCycle.yearly => context.l10n.yearly,
  BillingCycle.twoYears => context.l10n.twoYears,
  BillingCycle.threeYears => context.l10n.threeYears,
};

String _cycleUnit(BuildContext context, BillingCycle cycle) => switch (cycle) {
  BillingCycle.monthly => context.l10n.perMonth,
  BillingCycle.quarterly => context.l10n.perQuarter,
  BillingCycle.halfYear => context.l10n.perHalfYear,
  BillingCycle.yearly => context.l10n.perYear,
  BillingCycle.twoYears => context.l10n.perTwoYears,
  BillingCycle.threeYears => context.l10n.perThreeYears,
};

String _cleanFeature(String value) {
  return value
      .replaceFirst(RegExp(r'^[^\p{L}\p{N}]+', unicode: true), '')
      .trim();
}

bool _hasCapacity(PlanModel plan) {
  final capacity = plan.capacity.trim();
  return capacity.isNotEmpty && capacity != '0 GB' && capacity != '0 TB';
}
