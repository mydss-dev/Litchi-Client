import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../commerce/v3_payment_flow.dart';
import '../theme/v3_palette.dart';

class V3WalletPage extends StatefulWidget {
  const V3WalletPage({super.key});

  @override
  State<V3WalletPage> createState() => _V3WalletPageState();
}

class _V3WalletPageState extends State<V3WalletPage> {
  static const _presets = <double>[10, 30, 50, 100, 200, 500];

  final _rechargeController = TextEditingController(text: '100');
  bool _submittingRecharge = false;
  bool _financialAction = false;

  @override
  void dispose() {
    _rechargeController.dispose();
    super.dispose();
  }

  Future<void> _recharge() async {
    if (_submittingRecharge) return;
    final controller = AppScope.read(context);
    final amount = double.tryParse(_rechargeController.text.trim()) ?? 0;
    if (amount <= 0) {
      _toast('请输入有效充值金额');
      return;
    }
    setState(() => _submittingRecharge = true);
    try {
      final tradeNo = await controller.api.submitRechargeOrder(
        (amount * 100).round(),
      );
      if (!mounted) return;
      await showV3PaymentFlow(
        context: context,
        tradeNo: tradeNo,
        fallbackAmount: amount,
        currencySymbol: controller.currencySymbol,
        api: controller.api,
        onPaid: controller.refreshData,
        onViewOrders: () => controller.goToPage(AppPage.orders),
      );
      if (mounted) await controller.refreshData();
    } catch (error) {
      if (mounted) _toast(_message(error));
    } finally {
      if (mounted) setState(() => _submittingRecharge = false);
    }
  }

  Future<void> _transferAll() async {
    if (_financialAction) return;
    final controller = AppScope.read(context);
    if (controller.withdrawable <= 0) {
      _toast('当前没有可转入余额的佣金');
      return;
    }
    setState(() => _financialAction = true);
    final error = await controller.transferAllCommission();
    if (!mounted) return;
    setState(() => _financialAction = false);
    _toast(error ?? '佣金已转入余额');
  }

  Future<void> _openTransfer() async {
    final controller = AppScope.read(context);
    if (controller.withdrawable <= 0) {
      _toast('当前没有可转入余额的佣金');
      return;
    }
    final amount = await showDialog<double>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.48),
      builder: (_) => _AmountDialog(
        title: '佣金转余额',
        subtitle:
            '可用 ${controller.currencySymbol}${controller.withdrawable.toStringAsFixed(2)}',
        maximum: controller.withdrawable,
        currencySymbol: controller.currencySymbol,
      ),
    );
    if (amount == null || !mounted) return;
    setState(() => _financialAction = true);
    final error = await controller.transferCommissionToBalance(amount);
    if (!mounted) return;
    setState(() => _financialAction = false);
    _toast(error ?? '佣金已转入余额');
  }

  Future<void> _openWithdraw() async {
    final controller = AppScope.read(context);
    if (!controller.withdrawEnabled) {
      _toast('当前账户暂未开放佣金提现');
      return;
    }
    if (controller.withdrawable <= 0) {
      _toast('当前没有可提现佣金');
      return;
    }
    final result = await showDialog<_WithdrawRequest>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.48),
      builder: (_) => _WithdrawDialog(
        maximum: controller.withdrawable,
        minimum: controller.minWithdrawAmount,
        methods: controller.withdrawMethods,
        currencySymbol: controller.currencySymbol,
      ),
    );
    if (result == null || !mounted) return;
    setState(() => _financialAction = true);
    final error = await controller.withdrawCommission(
      amount: result.amount,
      account: result.account,
      method: result.method,
    );
    if (!mounted) return;
    setState(() => _financialAction = false);
    _toast(error ?? '提现申请已提交');
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final p = V3Palette.of(context);
    final symbol = controller.currencySymbol;
    final balance = controller.user.balance / 100;
    final commission = controller.withdrawable;
    final total = balance + commission;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 720;
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            compact ? 20 : 34,
            26,
            compact ? 20 : 34,
            36,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'WALLET FLOW',
                          style: TextStyle(
                            color: p.lycheeInk,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2.2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '资金中心',
                          style: Theme.of(context).textTheme.displayLarge,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: '刷新',
                    onPressed: controller.refreshData,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 26),
              _BalanceHero(
                symbol: symbol,
                total: total,
                balance: balance,
                commission: commission,
              ),
              const SizedBox(height: 16),
              compact
                  ? Column(
                      children: [
                        _RechargePanel(
                          controller: _rechargeController,
                          presets: _presets,
                          symbol: symbol,
                          busy: _submittingRecharge,
                          onPreset: (amount) => setState(
                            () => _rechargeController.text = amount
                                .toStringAsFixed(0),
                          ),
                          onSubmit: _recharge,
                        ),
                        const SizedBox(height: 16),
                        _CommissionPanel(
                          controller: controller,
                          busy: _financialAction,
                          onTransferAll: _transferAll,
                          onTransfer: _openTransfer,
                          onWithdraw: _openWithdraw,
                        ),
                      ],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 11,
                          child: _RechargePanel(
                            controller: _rechargeController,
                            presets: _presets,
                            symbol: symbol,
                            busy: _submittingRecharge,
                            onPreset: (amount) => setState(
                              () => _rechargeController.text = amount
                                  .toStringAsFixed(0),
                            ),
                            onSubmit: _recharge,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 9,
                          child: _CommissionPanel(
                            controller: controller,
                            busy: _financialAction,
                            onTransferAll: _transferAll,
                            onTransfer: _openTransfer,
                            onWithdraw: _openWithdraw,
                          ),
                        ),
                      ],
                    ),
            ],
          ),
        );
      },
    );
  }
}

class _BalanceHero extends StatelessWidget {
  const _BalanceHero({
    required this.symbol,
    required this.total,
    required this.balance,
    required this.commission,
  });

  final String symbol;
  final double total;
  final double balance;
  final double commission;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: p.hero,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: p.line),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TOTAL VALUE',
                  style: TextStyle(
                    color: p.inkMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.7,
                  ),
                ),
                const SizedBox(height: 9),
                Text(
                  '$symbol${total.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: p.ink,
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1,
                  ),
                ),
              ],
            ),
          ),
          _HeroStat(label: '余额', value: '$symbol${balance.toStringAsFixed(2)}'),
          const SizedBox(width: 26),
          _HeroStat(
            label: '佣金',
            value: '$symbol${commission.toStringAsFixed(2)}',
          ),
          const SizedBox(width: 8),
          Container(
            width: 10,
            height: 56,
            decoration: BoxDecoration(
              color: p.aqua,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(label, style: TextStyle(color: p.inkMuted, fontSize: 10)),
        const SizedBox(height: 5),
        Text(
          value,
          style: TextStyle(
            color: p.ink,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _RechargePanel extends StatelessWidget {
  const _RechargePanel({
    required this.controller,
    required this.presets,
    required this.symbol,
    required this.busy,
    required this.onPreset,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final List<double> presets;
  final String symbol;
  final bool busy;
  final ValueChanged<double> onPreset;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: p.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TOP UP',
            style: TextStyle(
              color: p.inkMuted,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 7),
          Text('充值余额', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 18),
          TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              prefixText: '$symbol ',
              hintText: '100',
              filled: true,
              fillColor: p.surfaceRaised,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final amount in presets)
                ActionChip(
                  label: Text('$symbol${amount.toStringAsFixed(0)}'),
                  onPressed: () => onPreset(amount),
                ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              onPressed: busy ? null : onSubmit,
              style: FilledButton.styleFrom(
                backgroundColor: p.lychee,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              icon: const Icon(Icons.add_card_rounded, size: 18),
              label: Text(busy ? '正在创建订单…' : '充值'),
            ),
          ),
        ],
      ),
    );
  }
}

class _CommissionPanel extends StatelessWidget {
  const _CommissionPanel({
    required this.controller,
    required this.busy,
    required this.onTransferAll,
    required this.onTransfer,
    required this.onWithdraw,
  });

  final AppController controller;
  final bool busy;
  final VoidCallback onTransferAll;
  final VoidCallback onTransfer;
  final VoidCallback onWithdraw;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    final symbol = controller.currencySymbol;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: p.surfaceRaised,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'COMMISSION',
                style: TextStyle(
                  color: p.inkMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
              const Spacer(),
              if (busy)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '$symbol${controller.withdrawable.toStringAsFixed(2)}',
            style: TextStyle(
              color: p.ink,
              fontSize: 27,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text('当前可操作佣金', style: TextStyle(color: p.inkMuted, fontSize: 10)),
          const SizedBox(height: 20),
          _WalletAction(
            icon: Icons.south_west_rounded,
            title: '部分转入余额',
            subtitle: '选择金额转入账户余额',
            onTap: busy ? null : onTransfer,
          ),
          const SizedBox(height: 8),
          _WalletAction(
            icon: Icons.keyboard_double_arrow_down_rounded,
            title: '全部转入余额',
            subtitle: '一次转入全部可用佣金',
            onTap: busy ? null : onTransferAll,
          ),
          const SizedBox(height: 8),
          _WalletAction(
            icon: Icons.account_balance_rounded,
            title: '申请提现',
            subtitle: controller.withdrawEnabled
                ? (controller.minWithdrawAmount > 0
                      ? '最低 $symbol${controller.minWithdrawAmount.toStringAsFixed(2)}'
                      : '提现到已支持的收款方式')
                : '当前未开放提现',
            onTap: busy ? null : onWithdraw,
          ),
        ],
      ),
    );
  }
}

class _WalletAction extends StatelessWidget {
  const _WalletAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: p.line),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: p.lychee),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: p.ink,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(color: p.inkMuted, fontSize: 10),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: p.inkMuted, size: 18),
          ],
        ),
      ),
    );
  }
}

class _AmountDialog extends StatefulWidget {
  const _AmountDialog({
    required this.title,
    required this.subtitle,
    required this.maximum,
    required this.currencySymbol,
  });

  final String title;
  final String subtitle;
  final double maximum;
  final String currencySymbol;

  @override
  State<_AmountDialog> createState() => _AmountDialogState();
}

class _AmountDialogState extends State<_AmountDialog> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final amount = double.tryParse(_controller.text.trim()) ?? 0;
    if (amount <= 0 || amount > widget.maximum) {
      setState(
        () => _error = '请输入 0 到 ${widget.maximum.toStringAsFixed(2)} 之间的金额',
      );
      return;
    }
    Navigator.of(context).pop(amount);
  }

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(26),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 6),
            Text(
              widget.subtitle,
              style: TextStyle(color: p.inkMuted, fontSize: 10),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                prefixText: '${widget.currencySymbol} ',
                filled: true,
                fillColor: p.surfaceRaised,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: TextStyle(color: p.dangerInk, fontSize: 10)),
            ],
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: FilledButton(
                onPressed: _submit,
                child: const Text('确认转入'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WithdrawDialog extends StatefulWidget {
  const _WithdrawDialog({
    required this.maximum,
    required this.minimum,
    required this.methods,
    required this.currencySymbol,
  });

  final double maximum;
  final double minimum;
  final List<String> methods;
  final String currencySymbol;

  @override
  State<_WithdrawDialog> createState() => _WithdrawDialogState();
}

class _WithdrawDialogState extends State<_WithdrawDialog> {
  final _amountController = TextEditingController();
  final _accountController = TextEditingController();
  String? _method;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.methods.isNotEmpty) _method = widget.methods.first;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _accountController.dispose();
    super.dispose();
  }

  void _submit() {
    final amount = double.tryParse(_amountController.text.trim()) ?? 0;
    final account = _accountController.text.trim();
    final method = _method?.trim() ?? '';
    final min = widget.minimum > 0 ? widget.minimum : 0;
    if (amount <= 0 || amount > widget.maximum || amount < min) {
      setState(
        () => _error = min > 0
            ? '金额需在 ${widget.currencySymbol}${min.toStringAsFixed(2)} 到 ${widget.currencySymbol}${widget.maximum.toStringAsFixed(2)} 之间'
            : '请输入有效提现金额',
      );
      return;
    }
    if (account.isEmpty || method.isEmpty) {
      setState(() => _error = '请选择提现方式并填写收款账号');
      return;
    }
    Navigator.of(
      context,
    ).pop(_WithdrawRequest(amount: amount, account: account, method: method));
  }

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 430,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(26),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('申请提现', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 18),
            DropdownButtonFormField<String>(
              initialValue: _method,
              items: widget.methods
                  .map(
                    (method) =>
                        DropdownMenuItem(value: method, child: Text(method)),
                  )
                  .toList(growable: false),
              onChanged: (value) => setState(() => _method = value),
              decoration: const InputDecoration(labelText: '提现方式'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _accountController,
              decoration: const InputDecoration(labelText: '收款账号'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: '提现金额',
                prefixText: '${widget.currencySymbol} ',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: TextStyle(color: p.dangerInk, fontSize: 10)),
            ],
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: FilledButton(
                onPressed: _submit,
                child: const Text('提交提现申请'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WithdrawRequest {
  const _WithdrawRequest({
    required this.amount,
    required this.account,
    required this.method,
  });

  final double amount;
  final String account;
  final String method;
}

String _message(Object error) => error
    .toString()
    .replaceFirst('ApiException: ', '')
    .replaceFirst('Exception: ', '');
