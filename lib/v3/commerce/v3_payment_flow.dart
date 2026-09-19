import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../shared/models/api_models.dart';
import '../../shared/services/panel_api.dart';
import '../../shared/services/url_opener.dart';
import '../theme/v3_palette.dart';
import '../ui/v3_components.dart';
import 'v3_payment_copy.dart';

/// The one payment dialog. Every entry point that can take money — a plan
/// purchase, a wallet top-up, an unpaid order — goes through here.
///
/// [fallbackAmount] is only a placeholder for the moment before the backend
/// answers: the dialog shows the server's confirmed total as soon as
/// `getOrderPaymentDetail` returns, and the fallback only covers the load.
///
/// [onViewOrders] adds a way to go and check the order. Paying is rarely the
/// user's last step, and the only alternative was to close the dialog and hunt
/// for 订单 in the account hub.
Future<void> showV3PaymentFlow({
  required BuildContext context,
  required String tradeNo,
  required double fallbackAmount,
  required String currencySymbol,
  required PanelApi api,
  Future<void> Function()? onPaid,
  VoidCallback? onViewOrders,
}) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.52),
    builder: (_) => _V3PaymentDialog(
      tradeNo: tradeNo,
      fallbackAmount: fallbackAmount,
      currencySymbol: currencySymbol,
      api: api,
      onPaid: onPaid,
      onViewOrders: onViewOrders,
    ),
  );
}

class _V3PaymentDialog extends StatefulWidget {
  const _V3PaymentDialog({
    required this.tradeNo,
    required this.fallbackAmount,
    required this.currencySymbol,
    required this.api,
    required this.onPaid,
    required this.onViewOrders,
  });

  final String tradeNo;
  final double fallbackAmount;
  final String currencySymbol;
  final PanelApi api;
  final Future<void> Function()? onPaid;
  final VoidCallback? onViewOrders;

  @override
  State<_V3PaymentDialog> createState() => _V3PaymentDialogState();
}

class _V3PaymentDialogState extends State<_V3PaymentDialog> {
  List<RemotePaymentMethod> _methods = const [];
  RemoteOrderPaymentDetail? _detail;
  int? _selectedMethodId;
  bool _loading = true;
  bool _checkingOut = false;
  bool _checkingStatus = false;
  bool _paid = false;
  int _paymentType = 0;
  String? _paymentUrl;
  String? _error;

  bool get _balanceOnly => _detail?.balanceOnly ?? false;

  double get _amountDue {
    final cents = _detail?.totalAmount;
    return cents == null ? widget.fallbackAmount : cents / 100;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final methods = await widget.api.getPaymentMethods();
      final detail = await widget.api.getOrderPaymentDetail(widget.tradeNo);
      if (!mounted) return;
      setState(() {
        _methods = methods;
        _detail = detail;
        _selectedMethodId = methods.isEmpty ? null : methods.first.id;
        _loading = false;
      });
      if (detail.status == 3 || detail.status == 4) {
        await _markPaid();
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _message(error);
      });
    }
  }

  Future<void> _checkout() async {
    if (_checkingOut || (!_balanceOnly && _selectedMethodId == null)) return;
    setState(() {
      _checkingOut = true;
      _error = null;
    });
    try {
      final result = await widget.api.checkoutOrder(
        widget.tradeNo,
        _balanceOnly && _methods.isNotEmpty
            ? _methods.first.id
            : _selectedMethodId,
      );
      if (!mounted) return;
      if (result.url.isEmpty) {
        setState(() => _checkingOut = false);
        await _checkStatus();
        return;
      }
      setState(() {
        _paymentUrl = result.url;
        _paymentType = result.type;
        _checkingOut = false;
      });
      if (result.type == 1) await UrlOpener.open(result.url);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _checkingOut = false;
        _error = _message(error);
      });
    }
  }

  Future<void> _checkStatus() async {
    if (_checkingStatus) return;
    setState(() {
      _checkingStatus = true;
      _error = null;
    });
    try {
      final status = await widget.api.checkOrderStatus(widget.tradeNo);
      if (!mounted) return;
      if (status == 3 || status == 4) {
        await _markPaid();
      } else {
        setState(() => _error = V3PaymentCopy.of(context).pendingPayment);
      }
    } catch (error) {
      if (mounted) setState(() => _error = _message(error));
    } finally {
      if (mounted) setState(() => _checkingStatus = false);
    }
  }

  Future<void> _markPaid() async {
    if (_paid) return;
    _paid = true;
    await widget.onPaid?.call();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: Container(
        width: 520,
        constraints: const BoxConstraints(maxHeight: 680),
        padding: const EdgeInsets.all(26),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(30),
        ),
        child: _paid
            ? SingleChildScrollView(child: _paidView(context))
            : _paymentView(context),
      ),
    );
  }

  Widget _paidView(BuildContext context) {
    final p = V3Palette.of(context);
    final copy = V3PaymentCopy.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            color: p.success.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.check_rounded, color: p.success, size: 34),
        ),
        const SizedBox(height: 18),
        Text(copy.completed, style: Theme.of(context).textTheme.headlineLarge),
        const SizedBox(height: 8),
        // One wording for all three entry points. A successful wallet top-up
        // must not claim that only plan data is being refreshed.
        Text(
          copy.syncing,
          style: TextStyle(color: p.inkMuted, fontSize: 11),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(copy.done),
          ),
        ),
        if (widget.onViewOrders != null) ...[
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton(
              // Close first: the callback navigates the shell, and leaving the
              // dialog mounted over the new page would strand it there.
              onPressed: () {
                Navigator.of(context).pop();
                widget.onViewOrders!();
              },
              child: Text(copy.viewOrders),
            ),
          ),
        ],
      ],
    );
  }

  Widget _paymentView(BuildContext context) {
    final p = V3Palette.of(context);
    final copy = V3PaymentCopy.of(context);
    return SingleChildScrollView(
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
                      copy.kicker,
                      style: TextStyle(
                        color: p.lycheeInk,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.8,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      copy.title,
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: copy.close,
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            copy.order(widget.tradeNo),
            style: TextStyle(color: p.inkMuted, fontSize: 10),
          ),
          const SizedBox(height: 22),
          if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            )
          else ...[
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: p.hero,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: p.line),
              ),
              child: Row(
                children: [
                  Text(
                    copy.amountDue,
                    style: TextStyle(color: p.inkMuted, fontSize: 10),
                  ),
                  const Spacer(),
                  Text(
                    '${widget.currencySymbol}${_amountDue.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: p.ink,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            if (!_balanceOnly && _paymentUrl == null) ...[
              Text(
                copy.paymentMethod,
                style: TextStyle(
                  color: p.inkMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              if (_methods.isEmpty)
                Text(
                  copy.noMethods,
                  style: TextStyle(color: p.dangerInk, fontSize: 11),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final method in _methods)
                      ChoiceChip(
                        label: Text(method.name),
                        selected: _selectedMethodId == method.id,
                        side: v3ChipSide(
                          p,
                          selected: _selectedMethodId == method.id,
                        ),
                        onSelected: (_) =>
                            setState(() => _selectedMethodId = method.id),
                      ),
                  ],
                ),
              const SizedBox(height: 18),
            ],
            if (_paymentUrl != null) ...[
              Center(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: QrImageView(data: _paymentUrl!, size: 190),
                ),
              ),
              const SizedBox(height: 14),
              Center(
                child: Text(
                  _paymentType == 1 ? copy.browserOpened : copy.scanQr,
                  style: TextStyle(color: p.inkMuted, fontSize: 11),
                ),
              ),
              const SizedBox(height: 14),
              if (_paymentType == 1)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => UrlOpener.open(_paymentUrl!),
                    icon: const Icon(Icons.open_in_new_rounded, size: 17),
                    label: Text(copy.reopen),
                  ),
                ),
              const SizedBox(height: 10),
            ],
            if (_error != null) ...[
              Text(_error!, style: TextStyle(color: p.dangerInk, fontSize: 11)),
              const SizedBox(height: 12),
            ],
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: _paymentUrl == null
                    ? (_checkingOut ? null : _checkout)
                    : (_checkingStatus ? null : _checkStatus),
                style: FilledButton.styleFrom(
                  backgroundColor: p.lychee,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  _paymentUrl == null
                      ? (_checkingOut
                            ? copy.starting
                            : _balanceOnly
                            ? copy.balance
                            : copy.continuePayment)
                      : (_checkingStatus ? copy.checking : copy.paid),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

String _message(Object error) => error
    .toString()
    .replaceFirst('ApiException: ', '')
    .replaceFirst('Exception: ', '');
