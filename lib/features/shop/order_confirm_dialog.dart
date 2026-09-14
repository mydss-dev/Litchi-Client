import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../l10n/l10n.dart';
import '../../shared/models/api_models.dart';
import '../../shared/models/app_models.dart';
import '../../shared/services/panel_api.dart';
import '../../shared/widgets/app_modal.dart';
import '../../shared/widgets/app_toast.dart';
import 'payment_dialog.dart';
import 'widgets/greenfield_order_confirm_surface.dart';

String periodKey(BillingCycle? cycle, PlanModel plan) {
  if (plan.category == PlanCategory.oneTime ||
      plan.category == PlanCategory.dataPack) {
    return 'onetime_price';
  }
  if (cycle != null) {
    final key = switch (cycle) {
      BillingCycle.monthly => 'month_price',
      BillingCycle.quarterly => 'quarter_price',
      BillingCycle.halfYear => 'half_year_price',
      BillingCycle.yearly => 'year_price',
      BillingCycle.twoYears => 'two_year_price',
      BillingCycle.threeYears => 'three_year_price',
    };
    if (plan.priceForCycle(cycle) != null) return key;
  }
  if (plan.monthlyPrice != null) return 'month_price';
  if (plan.quarterlyPrice != null) return 'quarter_price';
  if (plan.halfYearPrice != null) return 'half_year_price';
  if (plan.yearlyPrice != null) return 'year_price';
  if (plan.oneTimePrice != null) return 'onetime_price';
  return 'month_price';
}

Future<void> showOrderConfirmDialog({
  required BuildContext context,
  required PlanModel plan,
  required BillingCycle cycle,
  required PanelApi api,
  Future<void> Function()? onPaid,
}) {
  return showAppAdaptiveModal<void>(
    context: context,
    builder: (_) => _OrderConfirmDialog(
      plan: plan,
      cycle: cycle,
      api: api,
      onPaid: onPaid,
    ),
  );
}

String _periodLabel(BuildContext context, String key) => switch (key) {
      'month_price' => context.l10n.monthly,
      'quarter_price' => context.l10n.quarterly,
      'half_year_price' => context.l10n.halfYear,
      'year_price' => context.l10n.yearly,
      'two_year_price' => context.l10n.twoYears,
      'three_year_price' => context.l10n.threeYears,
      'onetime_price' => context.l10n.oneTime,
      _ => key,
    };

class _OrderConfirmDialog extends StatefulWidget {
  const _OrderConfirmDialog({
    required this.plan,
    required this.cycle,
    required this.api,
    this.onPaid,
  });

  final PlanModel plan;
  final BillingCycle cycle;
  final PanelApi api;
  final Future<void> Function()? onPaid;

  @override
  State<_OrderConfirmDialog> createState() => _OrderConfirmDialogState();
}

class _OrderConfirmDialogState extends State<_OrderConfirmDialog> {
  late String _period;
  final _couponCtrl = TextEditingController();
  bool _couponApplied = false;
  CouponResult? _coupon;
  bool _verifying = false;
  bool _submitting = false;
  String _currencySymbol = '¥';

  List<MapEntry<String, double>> get _availablePeriods {
    final entries = <MapEntry<String, double>>[];
    void add(String key, double? price) {
      if (price != null) entries.add(MapEntry(key, price));
    }

    add('month_price', widget.plan.monthlyPrice);
    add('quarter_price', widget.plan.quarterlyPrice);
    add('half_year_price', widget.plan.halfYearPrice);
    add('year_price', widget.plan.yearlyPrice);
    add('two_year_price', widget.plan.twoYearPrice);
    add('three_year_price', widget.plan.threeYearPrice);
    add('onetime_price', widget.plan.oneTimePrice);
    return entries;
  }

  double get _originalPrice {
    for (final entry in _availablePeriods) {
      if (entry.key == _period) return entry.value;
    }
    return 0;
  }

  int get _originalCents => (_originalPrice * 100).round();

  int get _discountCents {
    if (!_couponApplied || _coupon == null) return 0;
    if (_coupon!.type == 1) return _coupon!.value;
    if (_coupon!.type == 2) {
      return (_originalCents * _coupon!.value / 100).round();
    }
    return 0;
  }

  double get _finalPrice =>
      ((_originalCents - _discountCents) / 100).clamp(0.0, double.infinity);

  @override
  void initState() {
    super.initState();
    _period = periodKey(widget.cycle, widget.plan);
    _loadCurrencySymbol();
  }

  @override
  void dispose() {
    _couponCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCurrencySymbol() async {
    final symbol = await widget.api.getCommCurrencySymbol();
    if (mounted) setState(() => _currencySymbol = symbol);
  }

  Future<void> _verifyCoupon() async {
    final code = _couponCtrl.text.trim();
    if (code.isEmpty || _verifying) return;
    setState(() => _verifying = true);
    try {
      final result = await widget.api.verifyCoupon(
        code,
        int.parse(widget.plan.id),
      );
      if (!mounted) return;
      if (result != null) {
        setState(() {
          _coupon = result;
          _couponApplied = true;
        });
        AppToast.show(
          context,
          context.l10n.couponApplied,
          type: AppToastType.success,
        );
      } else {
        AppToast.show(
          context,
          context.l10n.invalidCoupon,
          type: AppToastType.error,
        );
      }
    } catch (error) {
      if (mounted) {
        AppToast.show(
          context,
          context.l10n.operationFailed(context.l10n.verify, '$error'),
          type: AppToastType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  void _removeCoupon() {
    setState(() {
      _couponApplied = false;
      _coupon = null;
      _couponCtrl.clear();
    });
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      final tradeNo = await widget.api.submitOrder(
        planId: int.parse(widget.plan.id),
        period: _period,
        couponCode: _couponApplied ? _couponCtrl.text.trim() : null,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      await showOrderPaymentDialog(
        context: context,
        tradeNo: tradeNo,
        finalPrice: _finalPrice,
        api: widget.api,
        currencySymbol: _currencySymbol,
        onPaid: widget.onPaid,
      );
    } catch (error) {
      if (mounted) {
        AppToast.show(
          context,
          context.l10n.operationFailed(context.l10n.submitOrder, '$error'),
          type: AppToastType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _selectPeriod(String key) {
    setState(() {
      _period = key;
      _couponApplied = false;
      _coupon = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final currentPlanId = controller.currentPlanId;
    final expiresAt = controller.expiredAt;
    final hasActivePlan =
        currentPlanId != null &&
        (expiresAt == null ||
            expiresAt == 0 ||
            expiresAt * 1000 > DateTime.now().millisecondsSinceEpoch);
    final switchingPlan =
        hasActivePlan && currentPlanId != int.tryParse(widget.plan.id);
    final switchWarning = switchingPlan
        ? context.l10n.existingPlanSwitchWarning(
            controller.user.plan.isEmpty
                ? context.l10n.currentPlan
                : controller.user.plan,
            widget.plan.title,
          )
        : null;
    final couponStatusText = _couponApplied && _coupon != null
        ? _coupon!.type == 1
            ? context.l10n.discountAmount(
                '$_currencySymbol${(_coupon!.value / 100).toStringAsFixed(2)}',
              )
            : context.l10n.discountPercent(_coupon!.value)
        : null;

    return AppAdaptiveModal(
      title: context.l10n.confirmOrder,
      maxWidth: 560,
      maxHeightFactor: 0.92,
      child: GreenfieldOrderConfirmSurface(
        planTitle: widget.plan.title,
        planCapacity: widget.plan.capacity,
        switchWarning: switchWarning,
        periods: [
          for (final entry in _availablePeriods)
            GreenfieldPeriodOption(
              key: entry.key,
              label: _periodLabel(context, entry.key),
              priceText:
                  '$_currencySymbol${entry.value.toStringAsFixed(2)}',
              selected: entry.key == _period,
            ),
        ],
        couponController: _couponCtrl,
        couponApplied: _couponApplied,
        couponStatusText: couponStatusText,
        verifyingCoupon: _verifying,
        originalPriceText:
            '$_currencySymbol${_originalPrice.toStringAsFixed(2)}',
        discountText: _discountCents > 0
            ? '-$_currencySymbol${(_discountCents / 100).toStringAsFixed(2)}'
            : null,
        totalPriceText: '$_currencySymbol${_finalPrice.toStringAsFixed(2)}',
        submitting: _submitting,
        onPeriodSelected: _selectPeriod,
        onVerifyCoupon: _verifyCoupon,
        onRemoveCoupon: _removeCoupon,
        onCancel: () => Navigator.of(context).pop(),
        onSubmit: _submit,
      ),
    );
  }
}
