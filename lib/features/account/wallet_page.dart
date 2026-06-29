import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/app_controller.dart';
import '../../app/nav_destinations.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_radius.dart';
import '../../shared/theme/app_shadows.dart';
import '../../shared/theme/app_text_styles.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_modal.dart';
import '../../shared/widgets/app_text_field.dart';
import '../../shared/widgets/app_toast.dart';
import '../../shared/widgets/responsive_page_scaffold.dart';
import '../shop/payment_dialog.dart';

/// Wallet — a single responsive page.
///
/// Wide screens get the sidebar-style layout with a refresh button and dialogs;
/// compact screens get pull-to-refresh, a mobile header/back button, and the same
/// shared wallet content (hero card + recharge card).
class WalletPage extends StatefulWidget {
  const WalletPage({super.key});

  @override
  State<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends State<WalletPage> {
  static const _presets = [10, 30, 50, 100, 200, 500, 1000, 2000];

  final _amountCtrl = TextEditingController(text: '100');
  int _selectedPreset = 100;
  bool _submitting = false;
  bool _refreshing = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    await AppScope.of(context).refreshData();
    if (!mounted) return;
    setState(() => _refreshing = false);
    if (AppScope.of(context).dataLoadError == null) {
      AppToast.show(context, '已刷新', type: AppToastType.success);
    }
  }

  Future<void> _recharge() async {
    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;
    if (amount <= 0) {
      AppToast.show(context, '请输入有效的充值金额', type: AppToastType.warning);
      return;
    }
    if (_submitting) return;

    final ctrl = AppScope.of(context);
    setState(() => _submitting = true);
    try {
      final tradeNo = await ctrl.api.submitRechargeOrder(
        (amount * 100).round(),
      );
      if (!mounted) return;
      await showOrderPaymentDialog(
        context: context,
        tradeNo: tradeNo,
        finalPrice: amount,
        api: ctrl.api,
        currencySymbol: ctrl.currencySymbol,
      );
      if (mounted) await ctrl.refreshData();
    } catch (e) {
      if (mounted) {
        AppToast.show(
          context,
          e.toString().replaceFirst('ApiException: ', ''),
          type: AppToastType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _transferCommission() async {
    final ctrl = AppScope.of(context);
    if (ctrl.withdrawable <= 0) {
      AppToast.show(context, '暂无可划转佣金', type: AppToastType.warning);
      return;
    }
    await showAppAdaptiveModal<void>(
      context: context,
      builder: (_, compact) => _TransferModal(
        compact: compact,
        maxAmount: ctrl.withdrawable,
        currencySymbol: ctrl.currencySymbol,
      ),
    );
  }

  Future<void> _withdrawCommission() async {
    final ctrl = AppScope.of(context);
    if (!ctrl.withdrawEnabled) {
      AppToast.show(context, '提现暂未开放', type: AppToastType.warning);
      return;
    }
    if (ctrl.withdrawable <= 0) {
      AppToast.show(context, '暂无可提现佣金', type: AppToastType.warning);
      return;
    }
    if (ctrl.withdrawMethods.isEmpty) {
      AppToast.show(context, '暂无可用提现方式', type: AppToastType.warning);
      return;
    }
    await showAppAdaptiveModal<void>(
      context: context,
      builder: (_, compact) => _WithdrawModal(
        compact: compact,
        maxAmount: ctrl.withdrawable,
        minAmount: ctrl.minWithdrawAmount,
        methods: ctrl.withdrawMethods,
        currencySymbol: ctrl.currencySymbol,
      ),
    );
  }

  // ── Responsive build ──────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return ResponsivePageScaffold(
      title: '我的钱包',
      subtitle: '查看余额、佣金与充值',
      compactTitle: '钱包',
      compactSubtitle: '余额、佣金与账户充值',
      primaryCompact: isPrimaryCompactTab(AppPage.wallet),
      onRefresh: _refresh,
      onBack: () => AppScope.of(context).goToPage(AppPage.account),
      children: _bodyChildren(context),
    );
  }

  // ── Shared body (wallet hero + recharge card) ─────────────────────────────

  List<Widget> _bodyChildren(BuildContext context) {
    final ctrl = AppScope.of(context);
    final balance = ctrl.user.balance / 100;
    final commission = ctrl.withdrawable;
    final total = balance + commission;

    return [
      _WalletHero(
        total: '${ctrl.currencySymbol}${total.toStringAsFixed(2)}',
        balance: '${ctrl.currencySymbol}${balance.toStringAsFixed(2)}',
        commission: '${ctrl.currencySymbol}${commission.toStringAsFixed(2)}',
        onTransfer: _transferCommission,
        onWithdraw: _withdrawCommission,
      ),
      const SizedBox(height: 14),
      _RechargeCard(
        presets: _presets,
        selectedPreset: _selectedPreset,
        controller: _amountCtrl,
        currencySymbol: ctrl.currencySymbol,
        submitting: _submitting,
        onPreset: (amount) {
          setState(() => _selectedPreset = amount);
          _amountCtrl.text = amount.toString();
        },
        onSubmit: _recharge,
      ),
    ];
  }
}

// ── Wallet hero card ──────────────────────────────────────────────────────────

class _WalletHero extends StatelessWidget {
  const _WalletHero({
    required this.total,
    required this.balance,
    required this.commission,
    required this.onTransfer,
    required this.onWithdraw,
  });

  final String total;
  final String balance;
  final String commission;
  final VoidCallback onTransfer;
  final VoidCallback onWithdraw;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      radius: AppRadius.lg,
      padding: const EdgeInsets.all(18),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 520;
          final summary = _WalletSummary(
            total: total,
            balance: balance,
            commission: commission,
          );
          final actions = _WalletActions(
            onTransfer: onTransfer,
            onWithdraw: onWithdraw,
          );

          if (!wide) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [summary, const SizedBox(height: 14), actions],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: summary),
              const SizedBox(width: 16),
              Align(
                alignment: Alignment.centerRight,
                child: SizedBox(width: 148, child: actions),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _WalletSummary extends StatelessWidget {
  const _WalletSummary({
    required this.total,
    required this.balance,
    required this.commission,
  });

  final String total;
  final String balance;
  final String commission;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: c.primarySoft,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(LucideIcons.walletCards, color: c.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Text(
              '账户资产',
              style: AppTextStyles.bodyStrong.copyWith(color: c.textPrimary),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          total,
          style: AppTextStyles.largeNumber(
            fontSize: 32,
          ).copyWith(color: c.primary, height: 1),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 14,
          runSpacing: 8,
          children: [
            _AssetLabel(label: '账户余额', value: balance),
            _AssetLabel(label: '可提现佣金', value: commission),
          ],
        ),
      ],
    );
  }
}

class _WalletActions extends StatelessWidget {
  const _WalletActions({required this.onTransfer, required this.onWithdraw});

  final VoidCallback onTransfer;
  final VoidCallback onWithdraw;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _WalletActionButton(
          icon: LucideIcons.arrowRightLeft,
          label: '佣金划转',
          onTap: onTransfer,
        ),
        const SizedBox(height: 8),
        _WalletActionButton(
          icon: LucideIcons.receipt,
          label: '申请提现',
          onTap: onWithdraw,
        ),
      ],
    );
  }
}

class _AssetLabel extends StatelessWidget {
  const _AssetLabel({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: c.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Text(
        '$label：$value',
        style: AppTextStyles.caption.copyWith(
          color: c.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _WalletActionButton extends StatelessWidget {
  const _WalletActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 38,
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 11),
          decoration: BoxDecoration(
            color: c.surfaceMuted,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(color: c.softBorder),
          ),
          child: Row(
            children: [
              Icon(icon, size: 15, color: c.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(
                    color: c.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Icon(LucideIcons.chevronRight, size: 14, color: c.iconMuted),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Recharge card ─────────────────────────────────────────────────────────────

class _RechargeCard extends StatelessWidget {
  const _RechargeCard({
    required this.presets,
    required this.selectedPreset,
    required this.controller,
    required this.currencySymbol,
    required this.submitting,
    required this.onPreset,
    required this.onSubmit,
  });

  final List<int> presets;
  final int selectedPreset;
  final TextEditingController controller;
  final String currencySymbol;
  final bool submitting;
  final ValueChanged<int> onPreset;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return AppCard(
      radius: AppRadius.lg,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.badgePlus, color: c.primary, size: 18),
              const SizedBox(width: 8),
              Text(
                '充值余额',
                style: AppTextStyles.sectionTitle.copyWith(
                  color: c.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: c.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Row(
              children: [
                Icon(LucideIcons.circleAlert, color: c.success, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '充值后的余额仅限消费，无法提现',
                    style: AppTextStyles.caption.copyWith(
                      color: c.success,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 700 ? 4 : 2;
              const gap = 10.0;
              final width =
                  (constraints.maxWidth - gap * (columns - 1)) / columns;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final value in presets)
                    _PresetChip(
                      label: '$currencySymbol$value',
                      selected: value == selectedPreset,
                      width: width,
                      onTap: () => onPreset(value),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          _RechargeAmountRow(
            controller: controller,
            currencySymbol: currencySymbol,
            submitting: submitting,
            onSubmit: onSubmit,
          ),
        ],
      ),
    );
  }
}

class _RechargeAmountRow extends StatelessWidget {
  const _RechargeAmountRow({
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '自定义金额',
          style: AppTextStyles.caption.copyWith(
            color: c.textMuted,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          height: 42,
          padding: const EdgeInsets.only(left: 12, right: 4),
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
              const SizedBox(width: 6),
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: AppTextStyles.input.copyWith(color: c.textPrimary),
                  decoration: InputDecoration(
                    hintText: '请输入充值金额',
                    hintStyle: AppTextStyles.input.copyWith(color: c.textMuted),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              MouseRegion(
                cursor: submitting
                    ? MouseCursor.defer
                    : SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: submitting ? null : onSubmit,
                  child: Container(
                    height: 34,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: submitting ? c.cardBg : c.primary,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: submitting
                        ? SizedBox(
                            width: 15,
                            height: 15,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: c.primary,
                            ),
                          )
                        : Text(
                            '充值',
                            style: AppTextStyles.button.copyWith(
                              color: Colors.white,
                              fontSize: 13,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PresetChip extends StatelessWidget {
  const _PresetChip({
    required this.label,
    required this.selected,
    required this.width,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final double width;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          width: width,
          height: 50,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? c.primarySoft : c.surfaceMuted,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: selected ? c.primary : c.softBorder),
            boxShadow: selected ? AppShadows.soft(c) : null,
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

// ── Transfer modal ────────────────────────────────────────────────────────────

class _TransferModal extends StatefulWidget {
  const _TransferModal({
    required this.compact,
    required this.maxAmount,
    required this.currencySymbol,
  });

  final bool compact;
  final double maxAmount;
  final String currencySymbol;

  @override
  State<_TransferModal> createState() => _TransferModalState();
}

class _TransferModalState extends State<_TransferModal> {
  late final TextEditingController _amountCtrl;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _amountCtrl = TextEditingController(
      text: widget.maxAmount.toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;
    if (amount <= 0) {
      AppToast.show(context, '请输入划转金额', type: AppToastType.warning);
      return;
    }
    if (amount > widget.maxAmount) {
      AppToast.show(context, '划转金额不能超过可提现佣金', type: AppToastType.warning);
      return;
    }

    setState(() => _submitting = true);
    final error = await AppScope.of(
      context,
    ).transferCommissionToBalance(amount);
    if (!mounted) return;
    setState(() => _submitting = false);
    if (error == null) {
      Navigator.of(context).pop();
      AppToast.show(context, '佣金已划转到余额', type: AppToastType.success);
    } else {
      AppToast.show(context, error, type: AppToastType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return AppAdaptiveModal(
      compact: widget.compact,
      title: '划转佣金',
      icon: LucideIcons.arrowRightLeft,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _HintBox(text: '将可提现佣金划转到账户余额，划转后可用于购买套餐。'),
          const SizedBox(height: 14),
          AppTextField(
            controller: _amountCtrl,
            label: '划转金额',
            hint: '请输入划转金额',
            prefixText: widget.currencySymbol,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 8),
          Text(
            '可划转 ${widget.currencySymbol}${widget.maxAmount.toStringAsFixed(2)}',
            style: AppTextStyles.caption.copyWith(color: c.textMuted),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 42,
            child: FilledButton.icon(
              onPressed: _submitting ? null : _submit,
              icon: _submitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(LucideIcons.arrowRightLeft, size: 17),
              label: Text(_submitting ? '划转中' : '确认划转'),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Withdraw modal ────────────────────────────────────────────────────────────

class _WithdrawModal extends StatefulWidget {
  const _WithdrawModal({
    required this.compact,
    required this.maxAmount,
    required this.minAmount,
    required this.methods,
    required this.currencySymbol,
  });

  final bool compact;
  final double maxAmount;
  final double minAmount;
  final List<String> methods;
  final String currencySymbol;

  @override
  State<_WithdrawModal> createState() => _WithdrawModalState();
}

class _WithdrawModalState extends State<_WithdrawModal> {
  final _accountCtrl = TextEditingController();
  late final TextEditingController _amountCtrl;
  late String _method;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _method = widget.methods.first;
    _amountCtrl = TextEditingController(
      text: widget.maxAmount.toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    _accountCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;
    if (amount <= 0) {
      AppToast.show(context, '请输入提现金额', type: AppToastType.warning);
      return;
    }
    if (amount > widget.maxAmount) {
      AppToast.show(context, '提现金额不能超过可提现佣金', type: AppToastType.warning);
      return;
    }
    if (widget.minAmount > 0 && amount < widget.minAmount) {
      AppToast.show(
        context,
        '最低提现金额为 ${widget.currencySymbol}${widget.minAmount.toStringAsFixed(2)}',
        type: AppToastType.warning,
      );
      return;
    }
    if (_accountCtrl.text.trim().isEmpty) {
      AppToast.show(context, '请输入提现账户', type: AppToastType.warning);
      return;
    }

    setState(() => _submitting = true);
    final error = await AppScope.of(context).withdrawCommission(
      amount: amount,
      account: _accountCtrl.text,
      method: _method,
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (error == null) {
      Navigator.of(context).pop();
      AppToast.show(context, '提现工单已提交', type: AppToastType.success);
    } else {
      AppToast.show(context, error, type: AppToastType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return AppAdaptiveModal(
      compact: widget.compact,
      title: '申请提现',
      icon: LucideIcons.receipt,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '提现方式',
            style: AppTextStyles.caption.copyWith(
              color: c.textMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final method in widget.methods)
                _MethodChip(
                  label: method,
                  selected: method == _method,
                  onTap: () => setState(() => _method = method),
                ),
            ],
          ),
          const SizedBox(height: 14),
          AppTextField(
            controller: _accountCtrl,
            label: '提现账户',
            hint: '请输入收款账号',
          ),
          const SizedBox(height: 12),
          AppTextField(
            controller: _amountCtrl,
            label: '提现金额',
            hint: '请输入提现金额',
            prefixText: widget.currencySymbol,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 8),
          Text(
            '可提现 ${widget.currencySymbol}${widget.maxAmount.toStringAsFixed(2)}'
            '${widget.minAmount > 0 ? ' · 最低 ${widget.currencySymbol}${widget.minAmount.toStringAsFixed(2)}' : ''}',
            style: AppTextStyles.caption.copyWith(color: c.textMuted),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 42,
            child: FilledButton(
              onPressed: _submitting ? null : _submit,
              child: Text(_submitting ? '提交中' : '提交提现'),
            ),
          ),
        ],
      ),
    );
  }
}

class _HintBox extends StatelessWidget {
  const _HintBox({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: c.primarySoft,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Text(
        text,
        style: AppTextStyles.caption.copyWith(
          color: c.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _MethodChip extends StatelessWidget {
  const _MethodChip({
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
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          constraints: const BoxConstraints(minWidth: 96, minHeight: 38),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? c.primarySoft : c.surfaceMuted,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: selected ? c.primary : c.softBorder),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: AppTextStyles.caption.copyWith(
              color: selected ? c.primary : c.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}
