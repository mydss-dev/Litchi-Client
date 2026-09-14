import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../l10n/l10n.dart';
import '../../../shared/layout/app_layout.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_radius.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_text_styles.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';

class GreenfieldPeriodOption {
  const GreenfieldPeriodOption({
    required this.key,
    required this.label,
    required this.priceText,
    required this.selected,
  });

  final String key;
  final String label;
  final String priceText;
  final bool selected;
}

class GreenfieldOrderConfirmSurface extends StatelessWidget {
  const GreenfieldOrderConfirmSurface({
    super.key,
    required this.planTitle,
    required this.planCapacity,
    required this.periods,
    required this.couponController,
    required this.couponApplied,
    required this.couponStatusText,
    required this.verifyingCoupon,
    required this.originalPriceText,
    required this.discountText,
    required this.totalPriceText,
    required this.submitting,
    required this.onPeriodSelected,
    required this.onVerifyCoupon,
    required this.onRemoveCoupon,
    required this.onCancel,
    required this.onSubmit,
    this.switchWarning,
  });

  final String planTitle;
  final String planCapacity;
  final List<GreenfieldPeriodOption> periods;
  final TextEditingController couponController;
  final bool couponApplied;
  final String? couponStatusText;
  final bool verifyingCoupon;
  final String originalPriceText;
  final String? discountText;
  final String totalPriceText;
  final bool submitting;
  final ValueChanged<String> onPeriodSelected;
  final VoidCallback onVerifyCoupon;
  final VoidCallback onRemoveCoupon;
  final VoidCallback onCancel;
  final VoidCallback onSubmit;
  final String? switchWarning;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact =
            AppLayoutMetrics.classify(constraints.maxWidth) ==
            AppLayoutClass.compact;

        return Column(
          key: const ValueKey('greenfield-order-confirm-surface'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _PlanSummary(
              title: planTitle,
              capacity: planCapacity,
            ),
            if (switchWarning != null && switchWarning!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.lg),
              _SwitchWarning(message: switchWarning!),
            ],
            if (periods.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xl),
              Text(
                context.l10n.selectBillingCycle,
                style: AppTextStyles.sectionTitle.copyWith(
                  color: c.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _PeriodGrid(
                periods: periods,
                onSelected: onPeriodSelected,
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            Text(
              context.l10n.couponCode,
              style: AppTextStyles.sectionTitle.copyWith(color: c.textPrimary),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: AppTextField(
                    controller: couponController,
                    hint: context.l10n.couponHint,
                    enabled: !couponApplied,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                AppButton(
                  label: couponApplied
                      ? context.l10n.remove
                      : context.l10n.verify,
                  variant: couponApplied
                      ? AppButtonVariant.ghost
                      : AppButtonVariant.secondary,
                  loading: verifyingCoupon,
                  onPressed: verifyingCoupon
                      ? null
                      : couponApplied
                      ? onRemoveCoupon
                      : onVerifyCoupon,
                ),
              ],
            ),
            if (couponStatusText != null && couponStatusText!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Icon(LucideIcons.tag, size: 14, color: c.success),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      couponStatusText!,
                      style: AppTextStyles.caption.copyWith(color: c.success),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            _PriceSummary(
              originalPriceText: originalPriceText,
              discountText: discountText,
              totalPriceText: totalPriceText,
            ),
            const SizedBox(height: AppSpacing.xl),
            if (compact)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppButton(
                    label: context.l10n.submitOrder,
                    onPressed: submitting ? null : onSubmit,
                    loading: submitting,
                    expand: true,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  AppButton(
                    label: context.l10n.cancel,
                    variant: AppButtonVariant.ghost,
                    onPressed: onCancel,
                    expand: true,
                  ),
                ],
              )
            else
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      label: context.l10n.cancel,
                      variant: AppButtonVariant.outline,
                      onPressed: onCancel,
                      expand: true,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    flex: 2,
                    child: AppButton(
                      label: context.l10n.submitOrder,
                      onPressed: submitting ? null : onSubmit,
                      loading: submitting,
                      expand: true,
                    ),
                  ),
                ],
              ),
          ],
        );
      },
    );
  }
}

class _PlanSummary extends StatelessWidget {
  const _PlanSummary({required this.title, required this.capacity});

  final String title;
  final String capacity;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final quota = capacity.trim().isEmpty ? 'Litchi' : capacity.trim();
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: c.primarySoft.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: c.primary.withValues(alpha: 0.16)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: c.brandGradient,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: const Icon(
              LucideIcons.shoppingBag,
              size: 20,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.sectionTitle.copyWith(
                    color: c.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  quota,
                  style: AppTextStyles.metricValue.copyWith(color: c.primary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SwitchWarning extends StatelessWidget {
  const _SwitchWarning({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: c.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(LucideIcons.triangleAlert, size: 17, color: c.warning),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.caption.copyWith(
                color: c.textSecondary,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PeriodGrid extends StatelessWidget {
  const _PeriodGrid({required this.periods, required this.onSelected});

  final List<GreenfieldPeriodOption> periods;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact =
            AppLayoutMetrics.classify(constraints.maxWidth) ==
            AppLayoutClass.compact;
        final columns = compact ? 2 : 3;
        const gap = AppSpacing.sm;
        final width =
            (constraints.maxWidth - gap * (columns - 1)) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final period in periods)
              SizedBox(
                width: width,
                child: _PeriodOption(
                  option: period,
                  onPressed: () => onSelected(period.key),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _PeriodOption extends StatelessWidget {
  const _PeriodOption({required this.option, required this.onPressed});

  final GreenfieldPeriodOption option;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Material(
      color: option.selected ? c.primarySoft : c.surfaceMuted,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          constraints: const BoxConstraints(minHeight: 58),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: option.selected
                  ? c.primary.withValues(alpha: 0.42)
                  : c.softBorder,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                option.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodyStrong.copyWith(
                  color: option.selected ? c.primary : c.textPrimary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                option.priceText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption.copyWith(
                  color: option.selected ? c.primary : c.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PriceSummary extends StatelessWidget {
  const _PriceSummary({
    required this.originalPriceText,
    required this.discountText,
    required this.totalPriceText,
  });

  final String originalPriceText;
  final String? discountText;
  final String totalPriceText;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: c.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        children: [
          _PriceRow(
            label: context.l10n.originalPrice,
            value: originalPriceText,
          ),
          if (discountText != null) ...[
            const SizedBox(height: AppSpacing.sm),
            _PriceRow(
              label: context.l10n.discount,
              value: discountText!,
              valueColor: c.success,
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Divider(height: 1, thickness: 1, color: c.softBorder),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: Text(
                  context.l10n.totalDue,
                  style: AppTextStyles.bodyStrong.copyWith(
                    color: c.textPrimary,
                  ),
                ),
              ),
              Text(
                totalPriceText,
                style: AppTextStyles.largeNumber(fontSize: 24).copyWith(
                  color: c.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  const _PriceRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: AppTextStyles.body.copyWith(color: c.textSecondary),
          ),
        ),
        Text(
          value,
          style: AppTextStyles.bodyStrong.copyWith(
            color: valueColor ?? c.textPrimary,
          ),
        ),
      ],
    );
  }
}
