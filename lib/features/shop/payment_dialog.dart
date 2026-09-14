import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../l10n/l10n.dart';
import '../../shared/models/api_models.dart';
import '../../shared/services/panel_api.dart';
import '../../shared/services/secure_logger.dart';
import '../../shared/services/url_opener.dart';
import '../../shared/widgets/app_bottom_sheet.dart';
import '../../shared/widgets/app_icon_button.dart';
import '../../shared/widgets/app_modal.dart';
import '../../shared/widgets/app_toast.dart';
import 'widgets/greenfield_payment_surface.dart';

Future<void> showOrderPaymentDialog({
  required BuildContext context,
  required String tradeNo,
  required double finalPrice,
  required PanelApi api,
  String? currencySymbol,
  Future<void> Function()? onPaid,
}) async {
  String symbol = currencySymbol ?? '¥';
  if (currencySymbol == null) {
    try {
      symbol = await api.getCommCurrencySymbol();
    } catch (error) {
      SecureLogger.debug('get currency symbol failed', error);
    }
  }
  if (!context.mounted) return;
  return showAppAdaptiveModal<void>(
    context: context,
    builder: (_) => _PaymentDialog(
      tradeNo: tradeNo,
      finalPrice: finalPrice,
      currencySymbol: symbol,
      api: api,
      onPaid: onPaid,
    ),
  );
}

enum _Stage { methods, qr, success, expired }

class _PaymentDialog extends StatefulWidget {
  const _PaymentDialog({
    required this.tradeNo,
    required this.finalPrice,
    required this.currencySymbol,
    required this.api,
    this.onPaid,
  });

  final String tradeNo;
  final double finalPrice;
  final String currencySymbol;
  final PanelApi api;
  final Future<void> Function()? onPaid;

  @override
  State<_PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<_PaymentDialog> {
  List<RemotePaymentMethod> _methods = [];
  bool _loadingMethods = true;
  bool _loadingOrderDetail = true;
  RemoteOrderPaymentDetail? _orderDetail;
  int? _selectedId;
  String _selectedName = '';
  bool _checkingOut = false;

  _Stage _stage = _Stage.methods;
  String _payUrl = '';
  int _payType = 0;
  Timer? _countdown;
  Timer? _pollTimer;
  int _secondsLeft = 900;

  bool _manualChecking = false;
  bool _refreshing = false;
  bool _paidNotified = false;

  @override
  void initState() {
    super.initState();
    _loadMethods();
    _loadOrderDetail();
  }

  @override
  void dispose() {
    _countdown?.cancel();
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadMethods() async {
    try {
      final methods = await widget.api.getPaymentMethods();
      if (!mounted) return;
      setState(() {
        _methods = methods;
        _loadingMethods = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loadingMethods = false);
      AppToast.show(
        context,
        context.l10n.operationFailed(
          context.l10n.getPaymentMethods,
          '$error',
        ),
        type: AppToastType.error,
      );
    }
  }

  Future<void> _loadOrderDetail() async {
    try {
      final detail = await widget.api.getOrderPaymentDetail(widget.tradeNo);
      if (!mounted) return;
      setState(() {
        _orderDetail = detail;
        _loadingOrderDetail = false;
      });
      if (detail.status == 3 || detail.status == 4) _markPaid();
    } catch (error) {
      SecureLogger.debug('get order payment detail failed', error);
      if (mounted) setState(() => _loadingOrderDetail = false);
    }
  }

  double get _amountDue =>
      (_orderDetail?.totalAmount ?? (widget.finalPrice * 100).round()) / 100;

  int get _balanceAmount => _orderDetail?.balanceAmount ?? 0;
  int get _discountAmount => _orderDetail?.discountAmount ?? 0;
  int get _surplusAmount => _orderDetail?.surplusAmount ?? 0;
  int get _refundAmount => _orderDetail?.refundAmount ?? 0;
  int get _preHandlingAmount => _orderDetail?.preHandlingAmount ?? 0;

  RemotePaymentMethod? get _selectedMethod {
    final selectedId = _selectedId;
    if (selectedId == null) return null;
    for (final method in _methods) {
      if (method.id == selectedId) return method;
    }
    return null;
  }

  int get _selectedFeeAmount {
    final method = _selectedMethod;
    if (method == null) return 0;
    final subtotalCents = (_amountDue * 100).round();
    return method.feeForAmount(subtotalCents);
  }

  int get _displayFeeAmount =>
      _selectedFeeAmount > 0 ? _selectedFeeAmount : _preHandlingAmount;

  double get _payableAmount => _amountDue + _selectedFeeAmount / 100;

  String _feeDescription(RemotePaymentMethod method) {
    final parts = <String>[];
    final percent = method.handlingFeePercent ?? 0;
    final fixed = method.handlingFeeFixed ?? 0;
    if (percent > 0) {
      parts.add('${percent.toStringAsFixed(percent % 1 == 0 ? 0 : 2)}%');
    }
    if (fixed > 0) {
      parts.add('${widget.currencySymbol}${(fixed / 100).toStringAsFixed(2)}');
    }
    if (parts.isEmpty) return '';
    return context.l10n.paymentFeeDescription(parts.join(' + '));
  }

  bool get _balanceOnly => _orderDetail?.balanceOnly ?? false;

  Future<void> _checkout() async {
    if ((!_balanceOnly && _selectedId == null) ||
        _loadingOrderDetail ||
        _checkingOut) {
      return;
    }
    setState(() => _checkingOut = true);
    try {
      final result = await widget.api.checkoutOrder(
        widget.tradeNo,
        _balanceOnly && _methods.isNotEmpty ? _methods.first.id : _selectedId,
      );
      if (!mounted) return;
      if (result.url.isEmpty) {
        await _verifyCompletedCheckout();
      } else {
        setState(() {
          _payUrl = result.url;
          _payType = result.type;
          _stage = _Stage.qr;
          _secondsLeft = 900;
          _checkingOut = false;
        });
        if (result.type == 1) unawaited(_openInBrowser(result.url));
        _startTimers();
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _checkingOut = false);
      AppToast.show(
        context,
        context.l10n.operationFailed(context.l10n.startPayment, '$error'),
        type: AppToastType.error,
      );
    }
  }

  Future<void> _verifyCompletedCheckout() async {
    try {
      final status = await widget.api.checkOrderStatus(widget.tradeNo);
      if (!mounted) return;
      if (status == 3 || status == 4) {
        _markPaid();
        return;
      }
      setState(() => _checkingOut = false);
      AppToast.show(
        context,
        context.l10n.paymentProcessing,
        type: AppToastType.info,
      );
      _pollTimer?.cancel();
      _pollTimer = Timer.periodic(
        const Duration(seconds: 3),
        (_) => _pollStatus(),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _checkingOut = false);
      AppToast.show(
        context,
        context.l10n.paymentNotDetected,
        type: AppToastType.warning,
      );
    }
  }

  Future<void> _openInBrowser(String url) async {
    await UrlOpener.open(url);
  }

  void _startTimers() {
    _countdown?.cancel();
    _pollTimer?.cancel();
    _countdown = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _secondsLeft--;
        if (_secondsLeft <= 0) {
          _countdown?.cancel();
          _pollTimer?.cancel();
          _stage = _Stage.expired;
        }
      });
    });
    _pollTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _pollStatus(),
    );
  }

  Future<void> _pollStatus() async {
    if (!mounted) return;
    try {
      final status = await widget.api.checkOrderStatus(widget.tradeNo);
      if ((status == 3 || status == 4) && mounted) {
        _countdown?.cancel();
        _pollTimer?.cancel();
        _markPaid();
      }
    } catch (error) {
      SecureLogger.debug('payment poll failed', error);
    }
  }

  Future<void> _manualCheck() async {
    if (_manualChecking) return;
    setState(() => _manualChecking = true);
    try {
      final status = await widget.api.checkOrderStatus(widget.tradeNo);
      if (!mounted) return;
      if (status == 3 || status == 4) {
        _countdown?.cancel();
        _pollTimer?.cancel();
        _markPaid();
      } else {
        AppToast.show(
          context,
          context.l10n.paymentNotDetected,
          type: AppToastType.warning,
        );
      }
    } catch (error) {
      if (mounted) {
        AppToast.show(
          context,
          context.l10n.operationFailed(context.l10n.queryPayment, '$error'),
          type: AppToastType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _manualChecking = false);
    }
  }

  void _markPaid() {
    if (!mounted) return;
    setState(() {
      _stage = _Stage.success;
      _checkingOut = false;
    });
    if (_paidNotified) return;
    _paidNotified = true;
    final callback = widget.onPaid;
    if (callback != null) unawaited(callback());
  }

  Future<void> _refresh() async {
    if (_selectedId == null || _refreshing) return;
    setState(() => _refreshing = true);
    try {
      final result = await widget.api.checkoutOrder(
        widget.tradeNo,
        _selectedId!,
      );
      if (!mounted) return;
      setState(() {
        _payUrl = result.url;
        _payType = result.type;
        _stage = _Stage.qr;
        _secondsLeft = 900;
        _refreshing = false;
      });
      if (result.type == 1) unawaited(_openInBrowser(result.url));
      _startTimers();
    } catch (error) {
      if (!mounted) return;
      setState(() => _refreshing = false);
      AppToast.show(
        context,
        context.l10n.operationFailed(context.l10n.refreshPayment, '$error'),
        type: AppToastType.error,
      );
    }
  }

  void _returnToMethods() {
    _countdown?.cancel();
    _pollTimer?.cancel();
    setState(() => _stage = _Stage.methods);
  }

  String _stageTitle(BuildContext context) => switch (_stage) {
        _Stage.methods => context.l10n.selectPaymentMethod,
        _Stage.qr => _payType == 1
            ? context.l10n.browserPayment
            : context.l10n.scanToPay,
        _Stage.success => context.l10n.paymentSuccess,
        _Stage.expired => _payType == 1
            ? context.l10n.paymentTimedOut
            : context.l10n.qrExpired,
      };

  GreenfieldPaymentStage get _greenfieldStage => switch (_stage) {
        _Stage.methods => GreenfieldPaymentStage.methods,
        _Stage.qr => GreenfieldPaymentStage.qr,
        _Stage.success => GreenfieldPaymentStage.success,
        _Stage.expired => GreenfieldPaymentStage.expired,
      };

  String _centsText(int cents, {String prefix = ''}) =>
      '$prefix${widget.currencySymbol}${(cents / 100).toStringAsFixed(2)}';

  List<GreenfieldPaymentAdjustment> get _adjustments => [
        if (_discountAmount > 0)
          GreenfieldPaymentAdjustment(
            label: context.l10n.discount,
            value: _centsText(_discountAmount, prefix: '-'),
          ),
        if (_surplusAmount > 0)
          GreenfieldPaymentAdjustment(
            label: context.l10n.subscriptionCredit,
            value: _centsText(_surplusAmount, prefix: '-'),
          ),
        if (_balanceAmount > 0)
          GreenfieldPaymentAdjustment(
            label: context.l10n.balanceApplied,
            value: _centsText(_balanceAmount, prefix: '-'),
          ),
        if (_refundAmount > 0)
          GreenfieldPaymentAdjustment(
            label: context.l10n.refundAmountLabel,
            value: _centsText(_refundAmount),
          ),
        if (_displayFeeAmount > 0)
          GreenfieldPaymentAdjustment(
            label: context.l10n.paymentHandlingFee,
            value: _centsText(_displayFeeAmount, prefix: '+'),
            fee: true,
          ),
      ];

  @override
  Widget build(BuildContext context) {
    final ready = !_loadingOrderDetail &&
        !_checkingOut &&
        (_balanceOnly || (!_loadingMethods && _selectedId != null));
    final feeDescriptions = <int, String>{
      for (final method in _methods) method.id: _feeDescription(method),
    };

    return AppBottomSheet(
      title: _stageTitle(context),
      leading: _stage == _Stage.qr
          ? AppIconButton(
              icon: LucideIcons.arrowLeft,
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              compact: true,
              onPressed: _returnToMethods,
            )
          : null,
      showClose: _stage != _Stage.success,
      maxHeightFactor: 0.92,
      maxWidth: 480,
      children: [
        GreenfieldPaymentSurface(
          stage: _greenfieldStage,
          currencySymbol: widget.currencySymbol,
          amount: _payableAmount,
          methods: _methods,
          methodFeeDescriptions: feeDescriptions,
          selectedMethodId: _selectedId,
          selectedMethodName: _selectedName,
          adjustments: _adjustments,
          loadingMethods: _loadingMethods,
          loadingOrderDetail: _loadingOrderDetail,
          balanceOnly: _balanceOnly,
          checkingOut: _checkingOut,
          payUrl: _payUrl,
          payType: _payType,
          secondsLeft: _secondsLeft,
          manualChecking: _manualChecking,
          refreshing: _refreshing,
          onMethodSelected: (method) {
            setState(() {
              _selectedId = method.id;
              _selectedName = method.name;
            });
          },
          onCheckout: ready ? _checkout : null,
          onOpenBrowser: () => _openInBrowser(_payUrl),
          onManualCheck: _manualCheck,
          onRefresh: _refresh,
          onCancel: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
