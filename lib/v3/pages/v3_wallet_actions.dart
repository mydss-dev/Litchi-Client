import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../commerce/v3_payment_flow.dart';
import '../theme/v3_palette.dart';
import '../ui/v3_locale_copy.dart';
import '../ui/v3_components.dart';
import '../ui/v3_dialog_frame.dart';
import '../ui/v3_sheet.dart';

/// Wallet actions retain independent dialogs, rather than a nested funds hub.
Future<void> showV3RechargeDialog(BuildContext context) {
  return showDialog<void>(context: context,
    barrierColor: Colors.black.withValues(alpha: .48),
    builder: (_) => _RechargeDialog(
      onViewOrders: () => openV3Page(context, AppPage.orders)));
}

Future<void> showV3TransferDialog(BuildContext context) async {
  final controller = AppScope.read(context);
  if (controller.withdrawable <= 0) {
    _toast(context, v3Copy(context, zh: '当前没有可转入余额的佣金',
      en: 'No commission available to transfer',
      tw: '目前沒有可轉入餘額的佣金'));
    return;
  }
  final success = v3Copy(context, zh: '佣金已转入余额',
    en: 'Commission transferred to balance', tw: '佣金已轉入餘額');
  final amount = await showDialog<double>(context: context,
    barrierColor: Colors.black.withValues(alpha: .48),
    builder: (_) => _AmountDialog(
      title: v3Copy(context, zh: '佣金转余额',
        en: 'Transfer commission', tw: '佣金轉餘額'),
      subtitle: v3Copy(context,
        zh: '可用 ${controller.currencySymbol}${controller.withdrawable.toStringAsFixed(2)}',
        en: 'Available ${controller.currencySymbol}${controller.withdrawable.toStringAsFixed(2)}',
        tw: '可用 ${controller.currencySymbol}${controller.withdrawable.toStringAsFixed(2)}'),
      maximum: controller.withdrawable,
      currencySymbol: controller.currencySymbol));
  if (amount == null || !context.mounted) return;
  final error = await controller.transferCommissionToBalance(amount);
  if (!context.mounted) return;
  _toast(context, error ?? success);
}

Future<void> showV3WithdrawDialog(BuildContext context) async {
  final controller = AppScope.read(context);
  if (!controller.withdrawEnabled) {
    _toast(context, v3Copy(context, zh: '当前账户暂未开放佣金提现',
      en: 'Withdrawals are not available for this account',
      tw: '目前帳戶尚未開放佣金提領'));
    return;
  }
  if (controller.withdrawable <= 0) {
    _toast(context, v3Copy(context, zh: '当前没有可提现佣金',
      en: 'No commission available to withdraw',
      tw: '目前沒有可提領佣金'));
    return;
  }
  final success = v3Copy(context, zh: '提现申请已提交',
    en: 'Withdrawal request submitted', tw: '提領申請已提交');
  final result = await showDialog<_WithdrawRequest>(context: context,
    barrierColor: Colors.black.withValues(alpha: .48),
    builder: (_) => _WithdrawDialog(
      maximum: controller.withdrawable,
      minimum: controller.minWithdrawAmount,
      methods: controller.withdrawMethods,
      currencySymbol: controller.currencySymbol));
  if (result == null || !context.mounted) return;
  final error = await controller.withdrawCommission(
    amount: result.amount, account: result.account, method: result.method);
  if (!context.mounted) return;
  _toast(context, error ?? success);
}

void _toast(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

class _RechargeDialog extends StatefulWidget {
  const _RechargeDialog({required this.onViewOrders});
  final VoidCallback onViewOrders;
  @override
  State<_RechargeDialog> createState() => _RechargeDialogState();
}

class _RechargeDialogState extends State<_RechargeDialog> {
  static const _presets = <double>[10, 30, 50, 100, 200, 500];
  final _amountController = TextEditingController(text: '100');
  bool _busy = false;
  String? _error;

  @override
  void dispose() { _amountController.dispose(); super.dispose(); }

  Future<void> _submit() async {
    if (_busy) return;
    final controller = AppScope.read(context);
    final amount = double.tryParse(_amountController.text.trim()) ?? 0;
    if (amount <= 0) {
      setState(() => _error = v3Copy(context, zh: '请输入有效充值金额',
        en: 'Enter a valid top-up amount', tw: '請輸入有效儲值金額'));
      return;
    }
    setState(() { _busy = true; _error = null; });
    try {
      final tradeNo = await controller.api.submitRechargeOrder((amount * 100).round());
      if (!mounted) return;
      await showV3PaymentFlow(context: context, tradeNo: tradeNo,
        fallbackAmount: amount, currencySymbol: controller.currencySymbol,
        api: controller.api, onPaid: controller.refreshData,
        onViewOrders: () {
          Navigator.of(context).pop();
          widget.onViewOrders();
        });
      if (!mounted) return;
      await controller.refreshData();
    } catch (error) {
      if (mounted) setState(() => _error = _message(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    final symbol = AppScope.of(context).currencySymbol;
    return V3DialogFrame(width: 420,
        child: Column(mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(v3Copy(context, zh: '充值余额',
                en: 'Top up balance', tw: '儲值餘額'),
                style: Theme.of(context).textTheme.headlineMedium)),
              IconButton(tooltip: v3Copy(context, zh: '关闭',
                  en: 'Close', tw: '關閉'),
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded)),
            ]),
            const SizedBox(height: 6),
            TextField(controller: _amountController, autofocus: true,
              onChanged: (_) => setState(() {}),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(prefixText: '$symbol ', hintText: '100',
                filled: true, fillColor: p.surfaceRaised,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none))),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final amount in _presets)
                ChoiceChip(label: Text('$symbol${amount.toStringAsFixed(0)}'),
                  selected: double.tryParse(_amountController.text.trim()) == amount,
                  side: v3ChipSide(p, selected:
                    double.tryParse(_amountController.text.trim()) == amount),
                  onSelected: _busy ? null : (_) => setState(() =>
                    _amountController.text = amount.toStringAsFixed(0))),
            ]),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: p.dangerInk, fontSize: 11)),
            ],
            const SizedBox(height: 18),
            SizedBox(width: double.infinity, height: 48,
              child: FilledButton.icon(onPressed: _busy ? null : _submit,
                style: FilledButton.styleFrom(backgroundColor: p.lychee,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14))),
                icon: const Icon(Icons.add_card_rounded, size: 18),
                label: Text(_busy ? v3Copy(context, zh: '正在创建订单…',
                    en: 'Creating order…', tw: '正在建立訂單…')
                  : v3Copy(context, zh: '去支付',
                    en: 'Continue to payment', tw: '前往付款')))),
          ]));
  }
}

class _AmountDialog extends StatefulWidget {
  const _AmountDialog({required this.title, required this.subtitle,
    required this.maximum, required this.currencySymbol});
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
  void dispose() { _controller.dispose(); super.dispose(); }

  void _submit() {
    final amount = double.tryParse(_controller.text.trim()) ?? 0;
    if (amount <= 0 || amount > widget.maximum) {
      setState(() => _error = v3Copy(context,
        zh: '请输入 0 到 ${widget.maximum.toStringAsFixed(2)} 之间的金额',
        en: 'Enter an amount between 0 and ${widget.maximum.toStringAsFixed(2)}',
        tw: '請輸入 0 到 ${widget.maximum.toStringAsFixed(2)} 之間的金額'));
      return;
    }
    Navigator.of(context).pop(amount);
  }

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return V3DialogFrame(width: 400,
        child: Column(mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(widget.title,
                style: Theme.of(context).textTheme.headlineMedium)),
              IconButton(tooltip: v3Copy(context, zh: '关闭',
                  en: 'Close', tw: '關閉'),
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded)),
            ]),
            const SizedBox(height: 6),
            Text(widget.subtitle,
              style: TextStyle(color: p.inkMuted, fontSize: 10)),
            const SizedBox(height: 18),
            TextField(controller: _controller, autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(prefixText: '${widget.currencySymbol} ',
                suffixIcon: _AllAmountButton(onTap: () =>
                  _controller.text = widget.maximum.toStringAsFixed(2)),
                filled: true, fillColor: p.surfaceRaised,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none))),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: TextStyle(color: p.dangerInk, fontSize: 10)),
            ],
            const SizedBox(height: 18),
            SizedBox(width: double.infinity, height: 46,
              child: FilledButton(onPressed: _submit,
                child: Text(v3Copy(context, zh: '确认转入',
                  en: 'Confirm transfer', tw: '確認轉入')))),
          ]));
  }
}

class _WithdrawDialog extends StatefulWidget {
  const _WithdrawDialog({required this.maximum, required this.minimum,
    required this.methods, required this.currencySymbol});
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
    _amountController.dispose(); _accountController.dispose(); super.dispose();
  }

  void _submit() {
    final amount = double.tryParse(_amountController.text.trim()) ?? 0;
    final account = _accountController.text.trim();
    final method = _method?.trim() ?? '';
    final min = widget.minimum > 0 ? widget.minimum : 0;
    if (amount <= 0 || amount > widget.maximum || amount < min) {
      setState(() => _error = min > 0
        ? v3Copy(context,
            zh: '金额需在 ${widget.currencySymbol}${min.toStringAsFixed(2)} 到 ${widget.currencySymbol}${widget.maximum.toStringAsFixed(2)} 之间',
            en: 'Amount must be ${widget.currencySymbol}${min.toStringAsFixed(2)} to ${widget.currencySymbol}${widget.maximum.toStringAsFixed(2)}',
            tw: '金額需在 ${widget.currencySymbol}${min.toStringAsFixed(2)} 到 ${widget.currencySymbol}${widget.maximum.toStringAsFixed(2)} 之間')
        : v3Copy(context, zh: '请输入有效提现金额',
            en: 'Enter a valid withdrawal amount', tw: '請輸入有效提領金額'));
      return;
    }
    if (account.isEmpty || method.isEmpty) {
      setState(() => _error = v3Copy(context, zh: '请选择提现方式并填写收款账号',
        en: 'Choose a method and enter a payout account',
        tw: '請選擇提領方式並填寫收款帳號'));
      return;
    }
    Navigator.of(context).pop(_WithdrawRequest(
      amount: amount, account: account, method: method));
  }

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return V3DialogFrame(width: 430,
        child: Column(mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(v3Copy(context, zh: '申请提现',
                en: 'Request withdrawal', tw: '申請提領'),
                style: Theme.of(context).textTheme.headlineMedium)),
              IconButton(tooltip: v3Copy(context, zh: '关闭',
                  en: 'Close', tw: '關閉'),
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded)),
            ]),
            const SizedBox(height: 18),
            DropdownButtonFormField<String>(initialValue: _method,
              items: widget.methods.map((method) =>
                DropdownMenuItem(value: method, child: Text(method)))
                .toList(growable: false),
              onChanged: (value) => setState(() => _method = value),
              decoration: InputDecoration(labelText: v3Copy(context,
                zh: '提现方式', en: 'Withdrawal method', tw: '提領方式'))),
            const SizedBox(height: 12),
            TextField(controller: _accountController,
              decoration: InputDecoration(labelText: v3Copy(context,
                zh: '收款账号', en: 'Payout account', tw: '收款帳號'))),
            const SizedBox(height: 12),
            TextField(controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: v3Copy(context,
                  zh: '提现金额', en: 'Withdrawal amount', tw: '提領金額'),
                prefixText: '${widget.currencySymbol} ',
                suffixIcon: _AllAmountButton(onTap: () =>
                  _amountController.text = widget.maximum.toStringAsFixed(2)))),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: TextStyle(color: p.dangerInk, fontSize: 10)),
            ],
            const SizedBox(height: 18),
            SizedBox(width: double.infinity, height: 46,
              child: FilledButton(onPressed: _submit,
                child: Text(v3Copy(context, zh: '提交提现申请',
                  en: 'Submit withdrawal', tw: '提交提領申請')))),
          ]));
  }
}

class _AllAmountButton extends StatelessWidget {
  const _AllAmountButton({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return TextButton(onPressed: onTap,
      style: TextButton.styleFrom(foregroundColor: p.lycheeInk,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        minimumSize: const Size(0, 44),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
      child: Text(v3Copy(context, zh: '全部', en: 'All', tw: '全部')));
  }
}

class _WithdrawRequest {
  const _WithdrawRequest({required this.amount, required this.account,
    required this.method});
  final double amount;
  final String account;
  final String method;
}

String _message(Object error) => error.toString()
    .replaceFirst('ApiException: ', '')
    .replaceFirst('Exception: ', '');