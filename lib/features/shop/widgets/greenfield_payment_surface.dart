import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../l10n/l10n.dart';
import '../../../shared/models/api_models.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_radius.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_text_styles.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';

enum GreenfieldPaymentStage { methods, qr, success, expired }

class GreenfieldPaymentAdjustment {
  const GreenfieldPaymentAdjustment({
    required this.label,
    required this.value,
    this.fee = false,
  });

  final String label;
  final String value;
  final bool fee;
}

class GreenfieldPaymentSurface extends StatelessWidget {
  const GreenfieldPaymentSurface({
    super.key,
    required this.stage,
    required this.currencySymbol,
    required this.amount,
    required this.methods,
    required this.methodFeeDescriptions,
    required this.selectedMethodId,
    required this.selectedMethodName,
    required this.adjustments,
    required this.loadingMethods,
    required this.loadingOrderDetail,
    required this.balanceOnly,
    required this.checkingOut,
    required this.payUrl,
    required this.payType,
    required this.secondsLeft,
    required this.manualChecking,
    required this.refreshing,
    required this.onMethodSelected,
    required this.onCheckout,
    required this.onOpenBrowser,
    required this.onManualCheck,
    required this.onRefresh,
    required this.onCancel,
  });

  final GreenfieldPaymentStage stage;
  final String currencySymbol;
  final double amount;
  final List<RemotePaymentMethod> methods;
  final Map<int, String> methodFeeDescriptions;
  final int? selectedMethodId;
  final String selectedMethodName;
  final List<GreenfieldPaymentAdjustment> adjustments;
  final bool loadingMethods;
  final bool loadingOrderDetail;
  final bool balanceOnly;
  final bool checkingOut;
  final String payUrl;
  final int payType;
  final int secondsLeft;
  final bool manualChecking;
  final bool refreshing;
  final ValueChanged<RemotePaymentMethod> onMethodSelected;
  final VoidCallback? onCheckout;
  final VoidCallback onOpenBrowser;
  final VoidCallback onManualCheck;
  final VoidCallback onRefresh;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return switch (stage) {
      GreenfieldPaymentStage.methods => _MethodsStage(surface: this),
      GreenfieldPaymentStage.qr => _QrStage(surface: this),
      GreenfieldPaymentStage.success => _SuccessStage(onDone: onCancel),
      GreenfieldPaymentStage.expired => _ExpiredStage(
          refreshing: refreshing,
          onRefresh: onRefresh,
          onCancel: onCancel,
        ),
    };
  }
}

class _MethodsStage extends StatelessWidget {
  const _MethodsStage({required this.surface});

  final GreenfieldPaymentSurface surface;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final loading = surface.loadingOrderDetail ||
        (!surface.balanceOnly && surface.loadingMethods);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _AmountHero(
          label: context.l10n.amountDue,
          currencySymbol: surface.currencySymbol,
          amount: surface.amount,
        ),
        if (surface.adjustments.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          _AdjustmentStrip(adjustments: surface.adjustments),
        ],
        const SizedBox(height: AppSpacing.xl),
        Text(
          context.l10n.choosePaymentMethod,
          style: AppTextStyles.sectionTitle.copyWith(color: c.textPrimary),
        ),
        const SizedBox(height: AppSpacing.md),
        if (loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else if (surface.balanceOnly)
          _BalanceMethodTile()
        else if (surface.methods.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
            child: Text(
              context.l10n.noPaymentMethods,
              textAlign: TextAlign.center,
              style: AppTextStyles.body.copyWith(color: c.textMuted),
            ),
          )
        else
          ...[
            for (final method in surface.methods) ...[
              _PaymentMethodTile(
                method: method,
                feeText: surface.methodFeeDescriptions[method.id] ?? '',
                selected: surface.selectedMethodId == method.id,
                onTap: () => surface.onMethodSelected(method),
              ),
              if (method != surface.methods.last)
                const SizedBox(height: AppSpacing.sm),
            ],
          ],
        const SizedBox(height: AppSpacing.xl),
        AppButton(
          label: surface.balanceOnly
              ? context.l10n.activateWithBalance
              : context.l10n.payNow,
          onPressed: surface.onCheckout,
          loading: surface.checkingOut,
          expand: true,
        ),
      ],
    );
  }
}

class _AmountHero extends StatelessWidget {
  const _AmountHero({
    required this.label,
    required this.currencySymbol,
    required this.amount,
  });

  final String label;
  final String currencySymbol;
  final double amount;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.xl,
      ),
      decoration: BoxDecoration(
        color: c.primarySoft.withValues(alpha: 0.66),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: c.primary.withValues(alpha: 0.16)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: AppTextStyles.caption.copyWith(color: c.textMuted),
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                currencySymbol,
                style: AppTextStyles.sectionTitle.copyWith(color: c.primary),
              ),
              const SizedBox(width: 2),
              Text(
                amount.toStringAsFixed(2),
                style: AppTextStyles.largeNumber(fontSize: 34).copyWith(
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

class _AdjustmentStrip extends StatelessWidget {
  const _AdjustmentStrip({required this.adjustments});

  final List<GreenfieldPaymentAdjustment> adjustments;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: c.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: c.softBorder),
      ),
      child: Column(
        children: [
          for (var index = 0; index < adjustments.length; index++) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    adjustments[index].label,
                    style: AppTextStyles.caption.copyWith(
                      color: c.textSecondary,
                    ),
                  ),
                ),
                Text(
                  adjustments[index].value,
                  style: AppTextStyles.bodyStrong.copyWith(
                    color: adjustments[index].fee ? c.warning : c.success,
                  ),
                ),
              ],
            ),
            if (index != adjustments.length - 1)
              const SizedBox(height: AppSpacing.sm),
          ],
        ],
      ),
    );
  }
}

class _BalanceMethodTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      color: c.primarySoft,
      shadow: AppCardShadow.none,
      borderColor: c.primary.withValues(alpha: 0.28),
      child: Row(
        children: [
          _MethodIconShell(
            selected: true,
            child: Icon(LucideIcons.walletCards, size: 19, color: c.primary),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              context.l10n.balancePayment,
              style: AppTextStyles.bodyStrong.copyWith(color: c.textPrimary),
            ),
          ),
          Icon(LucideIcons.circleCheck, size: 19, color: c.primary),
        ],
      ),
    );
  }
}

class _PaymentMethodTile extends StatelessWidget {
  const _PaymentMethodTile({
    required this.method,
    required this.feeText,
    required this.selected,
    required this.onTap,
  });

  final RemotePaymentMethod method;
  final String feeText;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      color: selected ? c.primarySoft : c.cardBg,
      shadow: AppCardShadow.none,
      borderColor: selected ? c.primary.withValues(alpha: 0.34) : c.softBorder,
      child: Row(
        children: [
          _MethodIconShell(
            selected: selected,
            child: _PaymentMethodIcon(
              method: method,
              color: selected ? c.primary : c.iconDefault,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  method.name,
                  style: AppTextStyles.bodyStrong.copyWith(
                    color: selected ? c.primary : c.textPrimary,
                  ),
                ),
                if (feeText.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    feeText,
                    style: AppTextStyles.caption.copyWith(color: c.textMuted),
                  ),
                ],
              ],
            ),
          ),
          Icon(
            selected ? LucideIcons.circleCheck : LucideIcons.circle,
            size: 19,
            color: selected ? c.primary : c.iconMuted,
          ),
        ],
      ),
    );
  }
}

class _MethodIconShell extends StatelessWidget {
  const _MethodIconShell({required this.selected, required this.child});

  final bool selected;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? c.cardBg : c.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: child,
    );
  }
}

class _QrStage extends StatelessWidget {
  const _QrStage({required this.surface});

  final GreenfieldPaymentSurface surface;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final minutes = surface.secondsLeft ~/ 60;
    final seconds = surface.secondsLeft % 60;
    final countdown =
        '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    final timerColor = surface.secondsLeft > 300
        ? c.textMuted
        : surface.secondsLeft > 60
            ? c.warning
            : c.danger;

    return Column(
      children: [
        Text(
          surface.selectedMethodName,
          style: AppTextStyles.bodyStrong.copyWith(color: c.textSecondary),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              surface.currencySymbol,
              style: AppTextStyles.sectionTitle.copyWith(color: c.primary),
            ),
            const SizedBox(width: 2),
            Text(
              surface.amount.toStringAsFixed(2),
              style: AppTextStyles.largeNumber(fontSize: 36).copyWith(
                color: c.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: QrImageView(
            data: surface.payUrl,
            version: QrVersions.auto,
            size: 212,
            backgroundColor: Colors.white,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          context.l10n.scanWithPhone,
          style: AppTextStyles.body.copyWith(color: c.textSecondary),
        ),
        if (surface.payType == 1) ...[
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: context.l10n.openInBrowser,
            variant: AppButtonVariant.ghost,
            size: AppControlSize.compact,
            leadingIcon: LucideIcons.externalLink,
            onPressed: surface.onOpenBrowser,
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.timer, size: 14, color: timerColor),
            const SizedBox(width: AppSpacing.xs),
            Text(
              context.l10n.remainingTime(countdown),
              style: AppTextStyles.caption.copyWith(color: timerColor),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        AppButton(
          label: context.l10n.paymentCompleted,
          onPressed: surface.manualChecking ? null : surface.onManualCheck,
          loading: surface.manualChecking,
          expand: true,
        ),
        const SizedBox(height: AppSpacing.sm),
        AppButton(
          label: context.l10n.cancel,
          variant: AppButtonVariant.ghost,
          onPressed: surface.onCancel,
          expand: true,
        ),
      ],
    );
  }
}

class _SuccessStage extends StatelessWidget {
  const _SuccessStage({required this.onDone});

  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Column(
      children: [
        const SizedBox(height: AppSpacing.md),
        Container(
          width: 88,
          height: 88,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: c.success.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(LucideIcons.circleCheck, size: 44, color: c.success),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          context.l10n.paymentSuccess,
          style: AppTextStyles.pageTitle.copyWith(color: c.textPrimary),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          context.l10n.orderActivated,
          textAlign: TextAlign.center,
          style: AppTextStyles.body.copyWith(color: c.textMuted),
        ),
        const SizedBox(height: AppSpacing.xxl),
        AppButton(
          label: context.l10n.done,
          onPressed: onDone,
          expand: true,
        ),
      ],
    );
  }
}

class _ExpiredStage extends StatelessWidget {
  const _ExpiredStage({
    required this.refreshing,
    required this.onRefresh,
    required this.onCancel,
  });

  final bool refreshing;
  final VoidCallback onRefresh;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Column(
      children: [
        const SizedBox(height: AppSpacing.md),
        Container(
          width: 88,
          height: 88,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: c.warning.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(LucideIcons.timer, size: 44, color: c.warning),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          context.l10n.qrExpired,
          style: AppTextStyles.pageTitle.copyWith(color: c.textPrimary),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          context.l10n.refreshQrCode,
          textAlign: TextAlign.center,
          style: AppTextStyles.body.copyWith(color: c.textMuted),
        ),
        const SizedBox(height: AppSpacing.xxl),
        AppButton(
          label: context.l10n.refreshQrCode,
          leadingIcon: LucideIcons.refreshCw,
          onPressed: refreshing ? null : onRefresh,
          loading: refreshing,
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
    );
  }
}

class _PaymentMethodIcon extends StatelessWidget {
  const _PaymentMethodIcon({required this.method, required this.color});

  final RemotePaymentMethod method;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final uri = Uri.tryParse(method.iconUrl ?? '');
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      return Icon(LucideIcons.creditCard, size: 19, color: color);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Image.network(
        uri.toString(),
        width: 22,
        height: 22,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) =>
            Icon(LucideIcons.creditCard, size: 19, color: color),
      ),
    );
  }
}
