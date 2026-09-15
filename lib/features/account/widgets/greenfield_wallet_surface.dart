import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../l10n/l10n.dart';
import '../../../shared/layout/app_platform.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_radius.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_text_styles.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';

class GreenfieldWalletSurface extends StatelessWidget {
  const GreenfieldWalletSurface({
    super.key,
    required this.totalText,
    required this.balanceText,
    required this.commissionText,
    required this.currencySymbol,
    required this.presets,
    required this.selectedPreset,
    required this.amountController,
    required this.submitting,
    required this.withdrawEnabled,
    required this.minimumWithdrawalText,
    required this.withdrawMethods,
    required this.onPresetSelected,
    required this.onOpenRecharge,
    required this.onSubmitRecharge,
    required this.onTransfer,
    required this.onWithdraw,
  });

  final String totalText;
  final String balanceText;
  final String commissionText;
  final String currencySymbol;
  final List<int> presets;
  final int selectedPreset;
  final TextEditingController amountController;
  final bool submitting;
  final bool withdrawEnabled;
  final String minimumWithdrawalText;
  final List<String> withdrawMethods;
  final ValueChanged<int> onPresetSelected;
  final VoidCallback onOpenRecharge;
  final VoidCallback onSubmitRecharge;
  final VoidCallback onTransfer;
  final VoidCallback onWithdraw;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = AppPlatform.usesTouch || constraints.maxWidth < 680;
        final recharge = _QuickRechargeCard(
          compact: compact,
          currencySymbol: currencySymbol,
          presets: presets,
          selectedPreset: selectedPreset,
          controller: amountController,
          submitting: submitting,
          onPresetSelected: onPresetSelected,
          onSubmitRecharge: onSubmitRecharge,
        );
        final commission = _CommissionCard(
          commissionText: commissionText,
          withdrawEnabled: withdrawEnabled,
          minimumWithdrawalText: minimumWithdrawalText,
          withdrawMethods: withdrawMethods,
          onTransfer: onTransfer,
          onWithdraw: onWithdraw,
        );

        return Column(
          key: const ValueKey('greenfield-wallet-surface'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _AssetHero(
              compact: compact,
              totalText: totalText,
              balanceText: balanceText,
              commissionText: commissionText,
              onOpenRecharge: onOpenRecharge,
              onTransfer: onTransfer,
              onWithdraw: onWithdraw,
            ),
            const SizedBox(height: AppSpacing.lg),
            if (compact) ...[
              recharge,
              const SizedBox(height: AppSpacing.lg),
              commission,
            ] else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: recharge),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(flex: 2, child: commission),
                ],
              ),
            if (compact) const SizedBox(height: AppSpacing.xxl),
          ],
        );
      },
    );
  }
}

class _AssetHero extends StatelessWidget {
  const _AssetHero({
    required this.compact,
    required this.totalText,
    required this.balanceText,
    required this.commissionText,
    required this.onOpenRecharge,
    required this.onTransfer,
    required this.onWithdraw,
  });

  final bool compact;
  final String totalText;
  final String balanceText;
  final String commissionText;
  final VoidCallback onOpenRecharge;
  final VoidCallback onTransfer;
  final VoidCallback onWithdraw;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final summary = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: c.primary,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: const Icon(
                LucideIcons.walletCards,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.myWallet,
                    style: AppTextStyles.sectionTitle.copyWith(
                      color: c.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    context.l10n.myWalletSubtitle,
                    style: AppTextStyles.caption.copyWith(color: c.textMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        Text(
          context.l10n.accountAssets,
          style: AppTextStyles.caption.copyWith(
            color: c.textMuted,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          totalText,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.largeNumber(
            fontSize: compact ? 32 : 38,
          ).copyWith(color: c.textPrimary, height: 1.05),
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            Expanded(
              child: _AssetMetric(
                label: context.l10n.accountBalance,
                value: balanceText,
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: _AssetMetric(
                label: context.l10n.withdrawableCommission,
                value: commissionText,
              ),
            ),
          ],
        ),
      ],
    );

    final actions = compact
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppButton(
                label: context.l10n.rechargeBalance,
                leadingIcon: LucideIcons.circlePlus,
                onPressed: onOpenRecharge,
                expand: true,
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      label: context.l10n.transferShort,
                      leadingIcon: LucideIcons.arrowLeftRight,
                      variant: AppButtonVariant.secondary,
                      onPressed: onTransfer,
                      expand: true,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: AppButton(
                      label: context.l10n.withdrawShort,
                      leadingIcon: LucideIcons.receipt,
                      variant: AppButtonVariant.outline,
                      onPressed: onWithdraw,
                      expand: true,
                    ),
                  ),
                ],
              ),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppButton(
                label: context.l10n.rechargeBalance,
                leadingIcon: LucideIcons.circlePlus,
                onPressed: onOpenRecharge,
                expand: true,
              ),
              const SizedBox(height: AppSpacing.sm),
              AppButton(
                label: context.l10n.transferCommission,
                leadingIcon: LucideIcons.arrowLeftRight,
                variant: AppButtonVariant.secondary,
                onPressed: onTransfer,
                expand: true,
              ),
              const SizedBox(height: AppSpacing.sm),
              AppButton(
                label: context.l10n.requestWithdrawal,
                leadingIcon: LucideIcons.receipt,
                variant: AppButtonVariant.outline,
                onPressed: onWithdraw,
                expand: true,
              ),
            ],
          );

    return AppCard(
      padding: EdgeInsets.all(compact ? AppSpacing.lg : AppSpacing.xl),
      color: c.primarySoft.withValues(alpha: 0.48),
      borderColor: c.primary.withValues(alpha: 0.14),
      shadow: AppCardShadow.soft,
      child: compact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                summary,
                const SizedBox(height: AppSpacing.xl),
                actions,
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(child: summary),
                const SizedBox(width: AppSpacing.xl),
                SizedBox(width: 220, child: actions),
              ],
            ),
    );
  }
}

class _AssetMetric extends StatelessWidget {
  const _AssetMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: c.cardBg.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: c.softBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.caption.copyWith(color: c.textMuted),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodyStrong.copyWith(
              color: c.textPrimary,
              fontSize: 17,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickRechargeCard extends StatelessWidget {
  const _QuickRechargeCard({
    required this.compact,
    required this.currencySymbol,
    required this.presets,
    required this.selectedPreset,
    required this.controller,
    required this.submitting,
    required this.onPresetSelected,
    required this.onSubmitRecharge,
  });

  final bool compact;
  final String currencySymbol;
  final List<int> presets;
  final int selectedPreset;
  final TextEditingController controller;
  final bool submitting;
  final ValueChanged<int> onPresetSelected;
  final VoidCallback onSubmitRecharge;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      shadow: AppCardShadow.soft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(LucideIcons.badgePlus, size: 18, color: c.primary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  context.l10n.rechargeBalance,
                  style: AppTextStyles.sectionTitle.copyWith(
                    color: c.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            context.l10n.rechargeBalanceNotice,
            style: AppTextStyles.caption.copyWith(color: c.textMuted),
          ),
          const SizedBox(height: AppSpacing.lg),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = compact ? 2 : 4;
              final width =
                  (constraints.maxWidth - AppSpacing.sm * (columns - 1)) /
                  columns;
              return Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final value in presets)
                    SizedBox(
                      width: width,
                      child: _PresetTile(
                        label: '$currencySymbol$value',
                        selected: value == selectedPreset,
                        onTap: () => onPresetSelected(value),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            context.l10n.customAmount,
            style: AppTextStyles.caption.copyWith(
              color: c.textMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _RechargeAmountField(
            controller: controller,
            currencySymbol: currencySymbol,
            submitting: submitting,
            onSubmit: onSubmitRecharge,
          ),
        ],
      ),
    );
  }
}

class _PresetTile extends StatelessWidget {
  const _PresetTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Ink(
          height: 48,
          decoration: BoxDecoration(
            color: selected ? c.primarySoft : c.surfaceMuted,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: selected ? c.primary : c.softBorder),
          ),
          child: Center(
            child: Text(
              label,
              style: AppTextStyles.bodyStrong.copyWith(
                color: selected ? c.primary : c.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RechargeAmountField extends StatelessWidget {
  const _RechargeAmountField({
    required this.controller,
    required this.currencySymbol,
    required this.submitting,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final String currencySymbol;
  final bool submitting;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      constraints: const BoxConstraints(minHeight: 48),
      padding: const EdgeInsets.only(left: AppSpacing.md, right: 4),
      decoration: BoxDecoration(
        color: c.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: c.softBorder),
      ),
      child: Row(
        children: [
          Text(
            currencySymbol,
            style: AppTextStyles.input.copyWith(color: c.textMuted),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textInputAction: TextInputAction.done,
              onSubmitted: (_) {
                if (!submitting) onSubmit();
              },
              style: AppTextStyles.input.copyWith(color: c.textPrimary),
              decoration: InputDecoration(
                hintText: context.l10n.rechargeAmountHint,
                hintStyle: AppTextStyles.input.copyWith(color: c.textMuted),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 13),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          AppButton(
            label: context.l10n.recharge,
            leadingIcon: LucideIcons.circlePlus,
            size: AppControlSize.compact,
            loading: submitting,
            onPressed: submitting ? null : onSubmit,
          ),
        ],
      ),
    );
  }
}

class _CommissionCard extends StatelessWidget {
  const _CommissionCard({
    required this.commissionText,
    required this.withdrawEnabled,
    required this.minimumWithdrawalText,
    required this.withdrawMethods,
    required this.onTransfer,
    required this.onWithdraw,
  });

  final String commissionText;
  final bool withdrawEnabled;
  final String minimumWithdrawalText;
  final List<String> withdrawMethods;
  final VoidCallback onTransfer;
  final VoidCallback onWithdraw;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final withdrawalState = !withdrawEnabled
        ? context.l10n.withdrawalUnavailable
        : minimumWithdrawalText.isNotEmpty
            ? context.l10n.minimumWithdrawal(minimumWithdrawalText)
            : context.l10n.withdrawableAmount(commissionText);
    final methodsText = withdrawMethods.isEmpty
        ? context.l10n.noWithdrawalMethods
        : '${context.l10n.withdrawalMethod}: ${withdrawMethods.join(' / ')}';

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      shadow: AppCardShadow.soft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(LucideIcons.badgeDollarSign, size: 18, color: c.primary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  context.l10n.withdrawableCommission,
                  style: AppTextStyles.sectionTitle.copyWith(
                    color: c.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            commissionText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.largeNumber(fontSize: 26).copyWith(
              color: c.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _StatusLine(
            icon: LucideIcons.circleAlert,
            text: withdrawalState,
            emphasized: !withdrawEnabled,
          ),
          const SizedBox(height: AppSpacing.sm),
          _StatusLine(
            icon: LucideIcons.receipt,
            text: methodsText,
          ),
          const SizedBox(height: AppSpacing.xl),
          AppButton(
            label: context.l10n.transferCommission,
            leadingIcon: LucideIcons.arrowLeftRight,
            variant: AppButtonVariant.secondary,
            onPressed: onTransfer,
            expand: true,
          ),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: context.l10n.requestWithdrawal,
            leadingIcon: LucideIcons.receipt,
            variant: AppButtonVariant.outline,
            onPressed: onWithdraw,
            expand: true,
          ),
        ],
      ),
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({
    required this.icon,
    required this.text,
    this.emphasized = false,
  });

  final IconData icon;
  final String text;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final color = emphasized ? c.warning : c.textMuted;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icon, size: 15, color: color),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            text,
            style: AppTextStyles.caption.copyWith(
              color: color,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}
