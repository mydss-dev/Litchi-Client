import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../l10n/l10n.dart';
import '../../../shared/models/app_models.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_radius.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_text_styles.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';

class GreenfieldPlanCard extends StatelessWidget {
  const GreenfieldPlanCard({
    super.key,
    required this.plan,
    required this.currencySymbol,
    required this.compact,
    required this.onPurchase,
  });

  static const double desktopHeight = 360;

  final PlanModel plan;
  final String currencySymbol;
  final bool compact;
  final void Function(PlanModel plan, BillingCycle cycle) onPurchase;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final cycle = _defaultCycle(plan);
    final price = _displayPrice(plan, cycle);
    final canBuy = price != null && !plan.soldOut;
    final benefits = _benefits(context, plan).take(compact ? 4 : 3).toList();
    final quota = _quota(plan);

    return AppCard(
      height: compact ? null : desktopHeight,
      padding: const EdgeInsets.all(AppSpacing.xl),
      borderColor: plan.featured
          ? c.primary.withValues(alpha: 0.55)
          : c.softBorder,
      borderWidth: plan.featured ? 1.4 : 1,
      shadow: plan.featured ? AppCardShadow.card : AppCardShadow.soft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _CategoryBadge(plan: plan),
              const Spacer(),
              if (plan.soldOut)
                _StatusBadge(label: context.l10n.soldOut, color: c.danger)
              else if (plan.hot)
                _StatusBadge(label: context.l10n.popular, color: c.danger)
              else if (plan.featured)
                _StatusBadge(label: context.l10n.recommended, color: c.primary),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            plan.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.sectionTitle.copyWith(
              color: c.textPrimary,
              fontSize: 18,
              height: 1.2,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            quota,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.largeNumber(fontSize: compact ? 34 : 38).copyWith(
              color: c.textPrimary,
              height: 1,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            _quotaCaption(context, plan),
            style: AppTextStyles.caption.copyWith(color: c.textMuted),
          ),
          const SizedBox(height: AppSpacing.lg),
          _PriceLine(
            symbol: currencySymbol,
            price: price,
            unit: _cycleUnit(context, plan, cycle),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (benefits.isNotEmpty)
            Column(
              children: [
                for (var index = 0; index < benefits.length; index++) ...[
                  _BenefitRow(text: benefits[index]),
                  if (index != benefits.length - 1)
                    const SizedBox(height: AppSpacing.sm),
                ],
              ],
            ),
          if (compact)
            const SizedBox(height: AppSpacing.xl)
          else
            const Spacer(),
          AppButton(
            label: canBuy
                ? context.l10n.buyNow
                : plan.soldOut
                ? context.l10n.soldOut
                : context.l10n.unavailableForPurchase,
            onPressed: canBuy ? () => onPurchase(plan, cycle) : null,
            trailingIcon: canBuy ? LucideIcons.arrowRight : null,
            expand: true,
          ),
        ],
      ),
    );
  }
}

class _CategoryBadge extends StatelessWidget {
  const _CategoryBadge({required this.plan});

  final PlanModel plan;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: c.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        _categoryLabel(context, plan.category),
        style: AppTextStyles.badge.copyWith(
          color: c.textSecondary,
          fontSize: 10,
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        maxLines: 1,
        style: AppTextStyles.badge.copyWith(color: color, fontSize: 10),
      ),
    );
  }
}

class _PriceLine extends StatelessWidget {
  const _PriceLine({
    required this.symbol,
    required this.price,
    required this.unit,
  });

  final String symbol;
  final double? price;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            symbol,
            style: AppTextStyles.bodyStrong.copyWith(color: c.textSecondary),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          price == null ? '--' : _priceText(price!),
          style: AppTextStyles.largeNumber(fontSize: 28).copyWith(
            color: c.primary,
            height: 1,
          ),
        ),
        if (unit.isNotEmpty) ...[
          const SizedBox(width: AppSpacing.sm),
          Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Text(
              unit,
              style: AppTextStyles.caption.copyWith(color: c.textMuted),
            ),
          ),
        ],
      ],
    );
  }
}

class _BenefitRow extends StatelessWidget {
  const _BenefitRow({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(LucideIcons.circleCheck, size: 15, color: c.primary),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.caption.copyWith(color: c.textSecondary),
          ),
        ),
      ],
    );
  }
}

BillingCycle greenfieldDefaultCycle(PlanModel plan) => _defaultCycle(plan);

double? greenfieldDisplayPrice(PlanModel plan) =>
    _displayPrice(plan, _defaultCycle(plan));

BillingCycle _defaultCycle(PlanModel plan) {
  if (plan.category != PlanCategory.recurring) return BillingCycle.monthly;
  const order = [
    BillingCycle.monthly,
    BillingCycle.quarterly,
    BillingCycle.halfYear,
    BillingCycle.yearly,
    BillingCycle.twoYears,
    BillingCycle.threeYears,
  ];
  for (final cycle in order) {
    if (plan.priceForCycle(cycle) != null) return cycle;
  }
  return BillingCycle.monthly;
}

double? _displayPrice(PlanModel plan, BillingCycle cycle) {
  if (plan.category == PlanCategory.recurring) {
    return plan.priceForCycle(cycle) ??
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

String _quota(PlanModel plan) {
  final value = plan.capacity.trim();
  if (value.isEmpty || value == '0 GB' || value == '0 TB') return '∞';
  return value;
}

String _quotaCaption(BuildContext context, PlanModel plan) =>
    switch (plan.category) {
      PlanCategory.recurring => context.l10n.recurringPlan,
      PlanCategory.oneTime => context.l10n.oneTimePlan,
      PlanCategory.dataPack => context.l10n.dataPack,
    };

String _categoryLabel(BuildContext context, PlanCategory category) =>
    switch (category) {
      PlanCategory.recurring => context.l10n.recurringPlan,
      PlanCategory.oneTime => context.l10n.oneTime,
      PlanCategory.dataPack => context.l10n.dataPack,
    };

String _cycleUnit(
  BuildContext context,
  PlanModel plan,
  BillingCycle cycle,
) {
  if (plan.category == PlanCategory.oneTime) return context.l10n.unlimitedTime;
  if (plan.category == PlanCategory.dataPack) return '';
  return switch (cycle) {
    BillingCycle.monthly => context.l10n.perMonth,
    BillingCycle.quarterly => context.l10n.perQuarter,
    BillingCycle.halfYear => context.l10n.perHalfYear,
    BillingCycle.yearly => context.l10n.perYear,
    BillingCycle.twoYears => context.l10n.perTwoYears,
    BillingCycle.threeYears => context.l10n.perThreeYears,
  };
}

Iterable<String> _benefits(BuildContext context, PlanModel plan) sync* {
  final seen = <String>{};
  for (final raw in plan.features) {
    final value = _cleanFeature(raw);
    if (value.isEmpty || !seen.add(value)) continue;
    yield value;
  }
  if (plan.deviceLimit != null) {
    final deviceText = plan.deviceLimit! > 0
        ? context.l10n.devicesCount(plan.deviceLimit!)
        : context.l10n.unlimitedDevices;
    if (seen.add(deviceText)) yield deviceText;
  }
}

String _cleanFeature(String value) => value
    .replaceFirst(RegExp(r'^[^\p{L}\p{N}]+', unicode: true), '')
    .trim();

String _priceText(double value) {
  if (value == value.roundToDouble()) return value.toStringAsFixed(0);
  return value.toStringAsFixed(2);
}
