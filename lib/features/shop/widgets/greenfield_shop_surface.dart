import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../l10n/l10n.dart';
import '../../../shared/layout/app_layout.dart';
import '../../../shared/layout/app_platform.dart';
import '../../../shared/models/app_models.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_radius.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_text_styles.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_segmented_control.dart';
import '../../../shared/widgets/page_status_cards.dart';
import 'greenfield_plan_card.dart';

class GreenfieldShopSurface extends StatelessWidget {
  const GreenfieldShopSurface({
    super.key,
    required this.plans,
    required this.selectedTab,
    required this.currencySymbol,
    required this.hasActivePlan,
    required this.currentPlanName,
    required this.remainingTraffic,
    required this.expiryLabel,
    required this.onSelectedTab,
    required this.onPurchase,
    this.showBack = false,
    this.onBack,
  });

  final List<PlanModel> plans;
  final int selectedTab;
  final String currencySymbol;
  final bool hasActivePlan;
  final String currentPlanName;
  final String remainingTraffic;
  final String expiryLabel;
  final ValueChanged<int> onSelectedTab;
  final void Function(PlanModel plan, BillingCycle cycle) onPurchase;
  final bool showBack;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final layoutClass = AppLayoutMetrics.classify(constraints.maxWidth);
        final columns = switch (layoutClass) {
          AppLayoutClass.compact => 1,
          AppLayoutClass.medium => 2,
          AppLayoutClass.expanded => 3,
        };
        final touch = AppPlatform.usesTouch;

        return Column(
          key: const ValueKey('greenfield-shop-surface'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ShopHeader(showBack: showBack, onBack: onBack),
            if (hasActivePlan) ...[
              const SizedBox(height: AppSpacing.lg),
              _CurrentPlanStrip(
                planName: currentPlanName,
                remainingTraffic: remainingTraffic,
                expiryLabel: expiryLabel,
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            _CategorySelector(
              selected: selectedTab,
              onSelected: onSelectedTab,
              scrollable: layoutClass == AppLayoutClass.compact,
            ),
            const SizedBox(height: AppSpacing.xl),
            if (plans.isEmpty)
              SizedBox(
                height: 240,
                child: AppEmptyState(
                  icon: LucideIcons.packageOpen,
                  title: context.l10n.noPlans,
                  subtitle: context.l10n.refreshLater,
                ),
              )
            else
              _PlanGrid(
                plans: plans,
                columns: columns,
                currencySymbol: currencySymbol,
                compactCards: touch || columns == 1,
                onPurchase: onPurchase,
              ),
          ],
        );
      },
    );
  }
}

class _ShopHeader extends StatelessWidget {
  const _ShopHeader({required this.showBack, required this.onBack});

  final bool showBack;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showBack && onBack != null) ...[
          PageBackButton(onTap: onBack!),
          const SizedBox(width: AppSpacing.md),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.planPurchase,
                style: AppTextStyles.pageTitle.copyWith(color: c.textPrimary),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                context.l10n.buyPlansSubtitle,
                style: AppTextStyles.body.copyWith(color: c.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CurrentPlanStrip extends StatelessWidget {
  const _CurrentPlanStrip({
    required this.planName,
    required this.remainingTraffic,
    required this.expiryLabel,
  });

  final String planName;
  final String remainingTraffic;
  final String expiryLabel;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.lg,
      ),
      color: c.primarySoft.withValues(alpha: 0.58),
      borderColor: c.primary.withValues(alpha: 0.16),
      shadow: AppCardShadow.none,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: c.cardBg,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(LucideIcons.crown, size: 18, color: c.primary),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.currentPlan,
                  style: AppTextStyles.caption.copyWith(color: c.textMuted),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  planName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyStrong.copyWith(
                    color: c.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          _PlanStripMetric(
            label: context.l10n.remainingTrafficLabel,
            value: remainingTraffic,
          ),
          const SizedBox(width: AppSpacing.xl),
          _PlanStripMetric(
            label: context.l10n.expiryTime,
            value: expiryLabel,
          ),
        ],
      ),
    );
  }
}

class _PlanStripMetric extends StatelessWidget {
  const _PlanStripMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          label,
          style: AppTextStyles.caption.copyWith(color: c.textMuted),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.bodyStrong.copyWith(color: c.textPrimary),
        ),
      ],
    );
  }
}

class _CategorySelector extends StatelessWidget {
  const _CategorySelector({
    required this.selected,
    required this.onSelected,
    required this.scrollable,
  });

  final int selected;
  final ValueChanged<int> onSelected;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final labels = [
      context.l10n.all,
      context.l10n.recurringPlan,
      context.l10n.oneTime,
      context.l10n.dataPack,
    ];
    final control = AppSegmentedControl<int>(
      selected: selected,
      onChanged: onSelected,
      items: [
        for (var index = 0; index < labels.length; index++)
          AppSegmentedItem(value: index, label: labels[index]),
      ],
    );

    if (!scrollable) return control;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: control,
    );
  }
}

class _PlanGrid extends StatelessWidget {
  const _PlanGrid({
    required this.plans,
    required this.columns,
    required this.currencySymbol,
    required this.compactCards,
    required this.onPurchase,
  });

  final List<PlanModel> plans;
  final int columns;
  final String currencySymbol;
  final bool compactCards;
  final void Function(PlanModel plan, BillingCycle cycle) onPurchase;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = AppSpacing.lg;
        final cardWidth = columns == 1
            ? constraints.maxWidth
            : (constraints.maxWidth - gap * (columns - 1)) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final plan in plans)
              SizedBox(
                width: cardWidth,
                child: GreenfieldPlanCard(
                  key: ValueKey('greenfield-plan-${plan.id}'),
                  plan: plan,
                  currencySymbol: currencySymbol,
                  compact: compactCards,
                  onPurchase: onPurchase,
                ),
              ),
          ],
        );
      },
    );
  }
}
