import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/app_controller.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_radius.dart';
import '../../shared/theme/app_shadows.dart';
import '../../shared/theme/app_text_styles.dart';
import '../../shared/widgets/app_bottom_sheet.dart';
import '../../shared/widgets/app_toast.dart';
import '../shop/payment_dialog.dart';
import 'mobile_back_button.dart';

class MobileWalletPage extends StatefulWidget {
  const MobileWalletPage({super.key});

  @override
  State<MobileWalletPage> createState() => _MobileWalletPageState();
}

class _MobileWalletPageState extends State<MobileWalletPage> {
  static const _presets = [6, 30, 68, 128, 256, 328, 648, 1280];

  final _amountCtrl = TextEditingController();
  int _selectedPreset = 128;
  bool _submitting = false;
  final bool _transferring = false;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _amountCtrl.text = _selectedPreset.toString();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshWalletData());
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _refreshWalletData() async {
    if (_refreshing || !mounted) return;
    setState(() => _refreshing = true);
    try {
      await AppScope.of(context).refreshData();
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<void> _handlePullRefresh() async {
    final ctrl = AppScope.of(context);
    await _refreshWalletData();
    if (!mounted || ctrl.dataLoadError != null) return;
    AppToast.show(context, '已刷新', type: AppToastType.success);
  }

  Future<bool> _rechargeAmount(double amount) async {
    final ctrl = AppScope.of(context);
    if (amount <= 0) {
      AppToast.show(context, '请输入有效的充值金额', type: AppToastType.warning);
      return false;
    }
    if (_submitting) return false;
    setState(() => _submitting = true);
    try {
      final tradeNo = await ctrl.api.submitRechargeOrder(
        (amount * 100).round(),
      );
      if (!mounted) return false;
      await showOrderPaymentDialog(
        context: context,
        tradeNo: tradeNo,
        finalPrice: amount,
        api: ctrl.api,
        currencySymbol: ctrl.currencySymbol,
      );
      if (mounted) {
        await ctrl.refreshData();
      }
      return true;
    } catch (e) {
      if (mounted) {
        AppToast.show(
          context,
          e.toString().replaceFirst('ApiException: ', ''),
          type: AppToastType.error,
        );
      }
      return false;
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
    await showAppBottomSheet<void>(
      context: context,
      builder: (_) => _TransferSheet(
        maxAmount: ctrl.withdrawable,
        currencySymbol: ctrl.currencySymbol,
      ),
    );
  }

  void _showWithdrawSheet() {
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
    showAppBottomSheet<void>(
      context: context,
      builder: (_) => _WithdrawSheet(
        maxAmount: ctrl.withdrawable,
        minAmount: ctrl.minWithdrawAmount,
        methods: ctrl.withdrawMethods,
        currencySymbol: ctrl.currencySymbol,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = AppScope.of(context);
    final balance = ctrl.user.balance / 100;
    final commission = ctrl.withdrawable;
    final total = balance + commission;
    return RefreshIndicator(
      onRefresh: _handlePullRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        children: [
          Row(
            children: [
              MobileBackButton(onTap: () => ctrl.goToPage(AppPage.account)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '我的钱包',
                  style: AppTextStyles.pageTitle.copyWith(fontSize: 26),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _WalletHero(
            total: '${ctrl.currencySymbol}${total.toStringAsFixed(2)}',
            balance: '${ctrl.currencySymbol}${balance.toStringAsFixed(2)}',
            commission:
                '${ctrl.currencySymbol}${commission.toStringAsFixed(2)}',
            transferring: _transferring,
            onTransfer: _transferCommission,
            onWithdraw: _showWithdrawSheet,
          ),
          const SizedBox(height: 14),
          _RechargeCard(
            presets: _presets,
            selectedPreset: _selectedPreset,
            controller: _amountCtrl,
            currencySymbol: ctrl.currencySymbol,
            submitting: _submitting,
            onPreset: (value) {
              setState(() => _selectedPreset = value);
              _amountCtrl.text = value.toString();
            },
            onSubmit: () async {
              final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;
              await _rechargeAmount(amount);
            },
          ),
        ],
      ),
    );
  }
}

class _WalletHero extends StatelessWidget {
  const _WalletHero({
    required this.total,
    required this.balance,
    required this.commission,
    required this.transferring,
    required this.onTransfer,
    required this.onWithdraw,
  });

  final String total;
  final String balance;
  final String commission;
  final bool transferring;
  final VoidCallback onTransfer;
  final VoidCallback onWithdraw;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: c.cardBg,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: c.softBorder),
        boxShadow: AppShadows.soft(c),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: c.primarySoft,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(
                  LucideIcons.walletCards,
                  color: c.primary,
                  size: 22,
                ),
              ),
              const Spacer(),
              Text(
                '账户资产',
                style: AppTextStyles.caption.copyWith(color: c.textMuted),
              ),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),
                    Text(
                      total,
                      style: AppTextStyles.largeNumber(
                        fontSize: 36,
                      ).copyWith(color: c.primary),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '账户余额：$balance',
                      style: AppTextStyles.caption.copyWith(color: c.textMuted),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '可提现佣金余额：$commission',
                      style: AppTextStyles.caption.copyWith(color: c.textMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              SizedBox(
                width: 112,
                child: Column(
                  children: [
                    _HeroActionButton(
                      label: transferring ? '划转中' : '划转',
                      icon: LucideIcons.arrowRightLeft,
                      onTap: transferring ? null : onTransfer,
                    ),
                    const SizedBox(height: 10),
                    _HeroActionButton(
                      label: '提现',
                      icon: LucideIcons.receipt,
                      onTap: onWithdraw,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroActionButton extends StatelessWidget {
  const _HeroActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: c.primarySoft,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(width: 2),
            Icon(icon, size: 16, color: c.primary),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.button.copyWith(color: c.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.cardBg,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: c.softBorder),
        boxShadow: AppShadows.soft(c),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.badgePlus, color: c.primary, size: 18),
              const SizedBox(width: 8),
              Text(
                '充值余额',
                style: AppTextStyles.bodyStrong.copyWith(color: c.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFEAF8F1),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Row(
              children: [
                const Icon(
                  LucideIcons.circleAlert,
                  color: Color(0xFF166B4D),
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '充值后的余额仅限消费，无法提现',
                    style: AppTextStyles.caption.copyWith(
                      color: const Color(0xFF166B4D),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final value in presets)
                _PresetChip(
                  label: '$currencySymbol$value',
                  selected: value == selectedPreset,
                  width: (MediaQuery.sizeOf(context).width - 86) / 2,
                  onTap: () => onPreset(value),
                ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: AppTextStyles.input.copyWith(color: c.textPrimary),
            decoration: InputDecoration(
              prefixText: currencySymbol,
              hintText: '自定义金额',
              filled: true,
              fillColor: c.surfaceMuted,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                borderSide: BorderSide(color: c.softBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                borderSide: BorderSide(color: c.softBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                borderSide: BorderSide(color: c.primary),
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 42,
            child: FilledButton.icon(
              onPressed: submitting ? null : onSubmit,
              icon: submitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(LucideIcons.creditCard, size: 17),
              label: Text(submitting ? '创建订单中' : '立即充值'),
            ),
          ),
        ],
      ),
    );
  }
}

class _TransferSheet extends StatefulWidget {
  const _TransferSheet({required this.maxAmount, required this.currencySymbol});

  final double maxAmount;
  final String currencySymbol;

  @override
  State<_TransferSheet> createState() => _TransferSheetState();
}

class _TransferSheetState extends State<_TransferSheet> {
  late final TextEditingController _amountCtrl;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _amountCtrl = TextEditingController(
      text: widget.maxAmount > 0 ? widget.maxAmount.toStringAsFixed(2) : '',
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
    return AppBottomSheet(
      title: '划转佣金',
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: c.primarySoft,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Text(
            '将可提现佣金划转到账户余额，划转后可用于购买套餐。',
            style: AppTextStyles.caption.copyWith(
              color: c.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 12),
        _WalletSheetTextField(
          controller: _amountCtrl,
          label: '划转金额',
          hint: '请输入划转金额',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        const SizedBox(height: 8),
        Text(
          '可划转 ${widget.currencySymbol}${widget.maxAmount.toStringAsFixed(2)}',
          style: AppTextStyles.caption.copyWith(color: c.textMuted),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 44,
          child: FilledButton.icon(
            onPressed: _submitting ? null : _submit,
            icon: _submitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(LucideIcons.arrowRightLeft, size: 17),
            label: Text(_submitting ? '划转中...' : '确认划转'),
          ),
        ),
      ],
    );
  }
}

class _WithdrawSheet extends StatefulWidget {
  const _WithdrawSheet({
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
  State<_WithdrawSheet> createState() => _WithdrawSheetState();
}

class _WithdrawSheetState extends State<_WithdrawSheet> {
  final _accountCtrl = TextEditingController();
  late final TextEditingController _amountCtrl;
  late String _method;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _method = widget.methods.first;
    _amountCtrl = TextEditingController(
      text: widget.maxAmount > 0 ? widget.maxAmount.toStringAsFixed(2) : '',
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
    return AppBottomSheet(
      title: '申请提现',
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
              _WithdrawMethodChip(
                label: method,
                selected: method == _method,
                onTap: () => setState(() => _method = method),
              ),
          ],
        ),
        const SizedBox(height: 12),
        _WalletSheetTextField(
          controller: _accountCtrl,
          label: '提现账户',
          hint: '请输入收款账号',
        ),
        const SizedBox(height: 12),
        _WalletSheetTextField(
          controller: _amountCtrl,
          label: '提现金额',
          hint: '请输入提现金额',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        const SizedBox(height: 8),
        Text(
          '可提现 ${widget.currencySymbol}${widget.maxAmount.toStringAsFixed(2)}'
          '${widget.minAmount > 0 ? ' · 最低 ${widget.currencySymbol}${widget.minAmount.toStringAsFixed(2)}' : ''}',
          style: AppTextStyles.caption.copyWith(color: c.textMuted),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 44,
          child: FilledButton(
            onPressed: _submitting ? null : _submit,
            child: Text(_submitting ? '提交中...' : '提交提现'),
          ),
        ),
      ],
    );
  }
}

class _WithdrawMethodChip extends StatelessWidget {
  const _WithdrawMethodChip({
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
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        constraints: const BoxConstraints(minWidth: 102, minHeight: 44),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
        decoration: BoxDecoration(
          color: selected ? c.primarySoft : c.cardBg,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: selected ? c.primary : c.softBorder),
          boxShadow: selected ? AppShadows.soft(c) : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: AppTextStyles.bodyStrong.copyWith(
            color: selected ? c.primary : c.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _WalletSheetTextField extends StatelessWidget {
  const _WalletSheetTextField({
    required this.controller,
    required this.label,
    required this.hint,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: c.textMuted,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: AppTextStyles.input.copyWith(color: c.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: AppTextStyles.input.copyWith(color: c.textMuted),
            filled: true,
            fillColor: c.surfaceMuted,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: BorderSide(color: c.softBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: BorderSide(color: c.primary),
            ),
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        height: 60,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? c.primarySoft : c.cardBg,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: selected ? c.primary : c.softBorder),
          boxShadow: AppShadows.soft(c),
        ),
        child: Text(
          label,
          style: AppTextStyles.bodyStrong.copyWith(
            color: selected ? c.primary : c.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}
