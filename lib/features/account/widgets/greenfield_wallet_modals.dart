import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/app_controller.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_radius.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_text_styles.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_modal.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../shop/payment_dialog.dart';

Future<void> showGreenfieldWalletRechargeModal(BuildContext context) {
  return showAppAdaptiveModal<void>(
    context: context,
    builder: (_) => const _RechargeModal(),
  );
}

Future<void> showGreenfieldWalletTransferModal(BuildContext context) async {
  final controller = AppScope.of(context);
  if (controller.withdrawable <= 0) {
    AppToast.show(
      context,
      context.l10n.noTransferableCommission,
      type: AppToastType.warning,
    );
    return;
  }

  await showAppAdaptiveModal<void>(
    context: context,
    builder: (_) => _TransferModal(
      maxAmount: controller.withdrawable,
      currencySymbol: controller.currencySymbol,
    ),
  );
  if (context.mounted) await controller.refreshData();
}

Future<void> showGreenfieldWalletWithdrawModal(BuildContext context) async {
  final controller = AppScope.of(context);
  if (!controller.withdrawEnabled) {
    AppToast.show(
      context,
      context.l10n.withdrawalUnavailable,
      type: AppToastType.warning,
    );
    return;
  }
  if (controller.withdrawable <= 0) {
    AppToast.show(
      context,
      context.l10n.noWithdrawableCommission,
      type: AppToastType.warning,
    );
    return;
  }
  if (controller.withdrawMethods.isEmpty) {
    AppToast.show(
      context,
      context.l10n.noWithdrawalMethods,
      type: AppToastType.warning,
    );
    return;
  }

  await showAppAdaptiveModal<void>(
    context: context,
    builder: (_) => _WithdrawModal(
      maxAmount: controller.withdrawable,
      minAmount: controller.minWithdrawAmount,
      methods: controller.withdrawMethods,
      currencySymbol: controller.currencySymbol,
    ),
  );
  if (context.mounted) await controller.refreshData();
}

class _RechargeModal extends StatefulWidget {
  const _RechargeModal();

  @override
  State<_RechargeModal> createState() => _RechargeModalState();
}

class _RechargeModalState extends State<_RechargeModal> {
  static const _presets = [10, 30, 50, 100, 200, 500, 1000, 2000];

  final _amountController = TextEditingController(text: '100');
  int _selectedPreset = 100;
  bool _submitting = false;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final amount = double.tryParse(_amountController.text.trim()) ?? 0;
    if (amount <= 0) {
      AppToast.show(
        context,
        context.l10n.invalidRechargeAmount,
        type: AppToastType.warning,
      );
      return;
    }
    if (_submitting) return;

    final controller = AppScope.of(context);
    final navigator = Navigator.of(context);
    final dialogContext = Navigator.of(context, rootNavigator: true).context;
    setState(() => _submitting = true);
    try {
      final tradeNo = await controller.api.submitRechargeOrder(
        (amount * 100).round(),
      );
      if (!mounted || !dialogContext.mounted) return;
      navigator.pop();
      await showOrderPaymentDialog(
        context: dialogContext,
        tradeNo: tradeNo,
        finalPrice: amount,
        api: controller.api,
        currencySymbol: controller.currencySymbol,
      );
      await controller.refreshData();
    } catch (error) {
      if (dialogContext.mounted) {
        AppToast.show(
          dialogContext,
          error.toString().replaceFirst('ApiException: ', ''),
          type: AppToastType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final c = AppColors.of(context);
    return AppAdaptiveModal(
      title: context.l10n.rechargeBalance,
      subtitle: context.l10n.rechargeBalanceNotice,
      maxWidth: 560,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 460 ? 4 : 2;
              final width =
                  (constraints.maxWidth - AppSpacing.sm * (columns - 1)) /
                  columns;
              return Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final value in _presets)
                    SizedBox(
                      width: width,
                      child: _OptionTile(
                        label: '${controller.currencySymbol}$value',
                        selected: value == _selectedPreset,
                        onTap: () {
                          setState(() => _selectedPreset = value);
                          _amountController.text = value.toString();
                        },
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
            controller: _amountController,
            currencySymbol: controller.currencySymbol,
            submitting: _submitting,
            onSubmit: _submit,
          ),
        ],
      ),
    );
  }
}

class _TransferModal extends StatefulWidget {
  const _TransferModal({
    required this.maxAmount,
    required this.currencySymbol,
  });

  final double maxAmount;
  final String currencySymbol;

  @override
  State<_TransferModal> createState() => _TransferModalState();
}

class _TransferModalState extends State<_TransferModal> {
  late final TextEditingController _amountController;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.maxAmount.toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final amount = double.tryParse(_amountController.text.trim()) ?? 0;
    if (amount <= 0) {
      AppToast.show(
        context,
        context.l10n.transferAmountRequired,
        type: AppToastType.warning,
      );
      return;
    }
    if (amount > widget.maxAmount) {
      AppToast.show(
        context,
        context.l10n.transferAmountTooHigh,
        type: AppToastType.warning,
      );
      return;
    }

    setState(() => _submitting = true);
    final error = await AppScope.of(context).transferCommissionToBalance(amount);
    if (!mounted) return;
    setState(() => _submitting = false);
    if (error == null) {
      Navigator.of(context).pop();
      AppToast.show(
        context,
        context.l10n.commissionTransferred,
        type: AppToastType.success,
      );
    } else {
      AppToast.show(context, error, type: AppToastType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return AppAdaptiveModal(
      title: context.l10n.transferCommission,
      maxWidth: 520,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _InfoPanel(
            icon: LucideIcons.arrowLeftRight,
            text: context.l10n.transferCommissionNotice,
          ),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(
            controller: _amountController,
            label: context.l10n.transferAmount,
            hint: context.l10n.transferAmountRequired,
            prefixText: widget.currencySymbol,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            context.l10n.transferableAmount(
              '${widget.currencySymbol}${widget.maxAmount.toStringAsFixed(2)}',
            ),
            style: AppTextStyles.caption.copyWith(color: c.textMuted),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: _submitting
                ? context.l10n.transferring
                : context.l10n.confirmTransfer,
            leadingIcon: LucideIcons.arrowLeftRight,
            loading: _submitting,
            onPressed: _submitting ? null : _submit,
            expand: true,
          ),
        ],
      ),
    );
  }
}

class _WithdrawModal extends StatefulWidget {
  const _WithdrawModal({
    required this.maxAmount,
    required this.minAmount,
    required this.methods,
    required this.currencySymbol,
  });

  final double maxAmount;
  final double minAmount;
  final List<String> methods;
  final String currencySymbol;

  @override
  State<_WithdrawModal> createState() => _WithdrawModalState();
}

class _WithdrawModalState extends State<_WithdrawModal> {
  final _accountController = TextEditingController();
  late final TextEditingController _amountController;
  late String _method;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _method = widget.methods.first;
    _amountController = TextEditingController(
      text: widget.maxAmount.toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    _accountController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final amount = double.tryParse(_amountController.text.trim()) ?? 0;
    if (amount <= 0) {
      AppToast.show(
        context,
        context.l10n.withdrawalAmountRequired,
        type: AppToastType.warning,
      );
      return;
    }
    if (amount > widget.maxAmount) {
      AppToast.show(
        context,
        context.l10n.withdrawalAmountTooHigh,
        type: AppToastType.warning,
      );
      return;
    }
    if (widget.minAmount > 0 && amount < widget.minAmount) {
      AppToast.show(
        context,
        context.l10n.minimumWithdrawal(
          '${widget.currencySymbol}${widget.minAmount.toStringAsFixed(2)}',
        ),
        type: AppToastType.warning,
      );
      return;
    }
    if (_accountController.text.trim().isEmpty) {
      AppToast.show(
        context,
        context.l10n.withdrawalAccountRequired,
        type: AppToastType.warning,
      );
      return;
    }

    setState(() => _submitting = true);
    final error = await AppScope.of(context).withdrawCommission(
      amount: amount,
      account: _accountController.text,
      method: _method,
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (error == null) {
      Navigator.of(context).pop();
      AppToast.show(
        context,
        context.l10n.withdrawalSubmitted,
        type: AppToastType.success,
      );
    } else {
      AppToast.show(context, error, type: AppToastType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return AppAdaptiveModal(
      title: context.l10n.requestWithdrawal,
      maxWidth: 560,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.l10n.withdrawalMethod,
            style: AppTextStyles.caption.copyWith(
              color: c.textMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final method in widget.methods)
                _MethodTile(
                  label: method,
                  selected: method == _method,
                  onTap: () => setState(() => _method = method),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(
            controller: _accountController,
            label: context.l10n.withdrawalAccount,
            hint: context.l10n.withdrawalAccountHint,
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            controller: _amountController,
            label: context.l10n.withdrawalAmount,
            hint: context.l10n.withdrawalAmountRequired,
            prefixText: widget.currencySymbol,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            widget.minAmount > 0
                ? context.l10n.withdrawableWithMinimum(
                    '${widget.currencySymbol}${widget.maxAmount.toStringAsFixed(2)}',
                    '${widget.currencySymbol}${widget.minAmount.toStringAsFixed(2)}',
                  )
                : context.l10n.withdrawableAmount(
                    '${widget.currencySymbol}${widget.maxAmount.toStringAsFixed(2)}',
                  ),
            style: AppTextStyles.caption.copyWith(color: c.textMuted),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: _submitting
                ? context.l10n.submitting
                : context.l10n.submitWithdrawal,
            leadingIcon: LucideIcons.receipt,
            loading: _submitting,
            onPressed: _submitting ? null : _submit,
            expand: true,
          ),
        ],
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
              onSubmitted: (_) => submitting ? null : onSubmit(),
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
            size: AppControlSize.compact,
            loading: submitting,
            onPressed: submitting ? null : onSubmit,
          ),
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
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
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? c.primarySoft : c.surfaceMuted,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: selected ? c.primary : c.softBorder),
          ),
          child: Text(
            label,
            style: AppTextStyles.bodyStrong.copyWith(
              color: selected ? c.primary : c.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class _MethodTile extends StatelessWidget {
  const _MethodTile({
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
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      color: selected ? c.primarySoft : c.surfaceMuted,
      borderColor: selected ? c.primary : c.softBorder,
      shadow: AppCardShadow.none,
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: AppTextStyles.caption.copyWith(
          color: selected ? c.primary : c.textPrimary,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _InfoPanel extends StatelessWidget {
  const _InfoPanel({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      color: c.primarySoft,
      borderColor: c.primary.withValues(alpha: 0.14),
      shadow: AppCardShadow.none,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 17, color: c.primary),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.caption.copyWith(
                color: c.primary,
                fontWeight: FontWeight.w700,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
