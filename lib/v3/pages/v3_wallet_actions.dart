import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../commerce/v3_payment_flow.dart';
import '../theme/v3_palette.dart';
import '../ui/v3_sheet.dart';

/// The wallet's three actions, each its own dialog.
///
/// They used to share one "资金中心" sheet: the balance, the commission, the
/// top-up field and the transfer/withdraw rows all in one modal, so opening
/// the wallet meant reading a page before you could do anything. The account
/// page now shows the balance itself and offers the three verbs as buttons —
/// each one opens exactly the dialog that verb needs and nothing else.
///
/// These are plain dialogs rather than [showV3Sheet]s: a sheet is a
/// destination-sized surface, and asking for an amount is not a destination.

/// Asks for a top-up amount and starts the payment flow.
///
/// [context] must be the page the dialog is opened from, not the dialog's own:
/// the payment flow's "查看订单" route closes both dialogs and then navigates,
/// and navigating with a dialog's context would use one that no longer exists.
Future<void> showV3RechargeDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.48),
    builder: (_) => _RechargeDialog(
      onViewOrders: () => openV3Page(context, AppPage.orders),
    ),
  );
}

/// Moves commission into the balance.
///
/// Refuses before opening when there is nothing to move: a dialog whose only
/// possible outcome is an error is worse than a sentence saying why.
Future<void> showV3TransferDialog(BuildContext context) async {
  final controller = AppScope.read(context);
  if (controller.withdrawable <= 0) {
    _toast(context, '当前没有可转入余额的佣金');
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
  if (amount == null || !context.mounted) return;
  final error = await controller.transferCommissionToBalance(amount);
  if (!context.mounted) return;
  _toast(context, error ?? '佣金已转入余额');
}

/// Files a withdrawal request.
Future<void> showV3WithdrawDialog(BuildContext context) async {
  final controller = AppScope.read(context);
  if (!controller.withdrawEnabled) {
    _toast(context, '当前账户暂未开放佣金提现');
    return;
  }
  if (controller.withdrawable <= 0) {
    _toast(context, '当前没有可提现佣金');
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
  if (result == null || !context.mounted) return;
  final error = await controller.withdrawCommission(
    amount: result.amount,
    account: result.account,
    method: result.method,
  );
  if (!context.mounted) return;
  _toast(context, error ?? '提现申请已提交');
}

void _toast(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

class _RechargeDialog extends StatefulWidget {
  const _RechargeDialog({required this.onViewOrders});

  /// Runs after the payment flow's "查看订单" has closed this dialog. Owned by
  /// the caller so the navigation it performs uses the page's context rather
  /// than this dialog's.
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
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final controller = AppScope.read(context);
    final amount = double.tryParse(_amountController.text.trim()) ?? 0;
    if (amount <= 0) {
      setState(() => _error = '请输入有效充值金额');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final tradeNo = await controller.api.submitRechargeOrder(
        (amount * 100).round(),
      );
      if (!mounted) return;
      // The payment dialog sits above this one and dismisses itself when it is
      // done, so this stays where it is until the user closes it — closing the
      // recharge dialog on the way in would take the barrier out from under a
      // payment modal that is still running.
      await showV3PaymentFlow(
        context: context,
        tradeNo: tradeNo,
        fallbackAmount: amount,
        currencySymbol: controller.currencySymbol,
        api: controller.api,
        onPaid: controller.refreshData,
        onViewOrders: () {
          // Orders opens as a sheet of its own, so this dialog goes first —
          // otherwise the two stack and the user has to close twice to get
          // back to where they started. The payment dialog has already popped
          // itself by the time this runs, so this pop lands on the right one.
          Navigator.of(context).pop();
          widget.onViewOrders();
        },
      );
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
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: Container(
        width: 420,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(26),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '充值余额',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ),
                IconButton(
                  tooltip: '关闭',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _amountController,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onSubmitted: (_) => _submit(),
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
                for (final amount in _presets)
                  ActionChip(
                    label: Text('$symbol${amount.toStringAsFixed(0)}'),
                    onPressed: _busy
                        ? null
                        : () => setState(
                            () => _amountController.text = amount
                                .toStringAsFixed(0),
                          ),
                  ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: p.dangerInk, fontSize: 11)),
            ],
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                onPressed: _busy ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: p.lychee,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.add_card_rounded, size: 18),
                label: Text(_busy ? '正在创建订单…' : '去支付'),
              ),
            ),
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
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ),
                IconButton(
                  tooltip: '关闭',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
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
                suffixIcon: _AllAmountButton(
                  onTap: () =>
                      _controller.text = widget.maximum.toStringAsFixed(2),
                ),
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
            Row(
              children: [
                Expanded(
                  child: Text(
                    '申请提现',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ),
                IconButton(
                  tooltip: '关闭',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
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
                suffixIcon: _AllAmountButton(
                  onTap: () => _amountController.text = widget.maximum
                      .toStringAsFixed(2),
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
                child: const Text('提交提现申请'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sets the amount field to the maximum the user may submit.
///
/// Withdraw and transfer both cap at a figure the user has to look up
/// elsewhere; a single "全部" tap puts that figure in the box.
class _AllAmountButton extends StatelessWidget {
  const _AllAmountButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: p.lycheeInk,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        minimumSize: const Size(0, 40),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
      ),
      child: const Text('全部'),
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
