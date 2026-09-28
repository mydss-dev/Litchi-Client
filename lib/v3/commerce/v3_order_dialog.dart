import 'package:flutter/material.dart';

import '../../shared/models/api_models.dart';
import '../../shared/models/app_models.dart';
import '../../shared/services/panel_api.dart';
import '../theme/v3_palette.dart';
import '../ui/v3_components.dart';
import '../ui/v3_locale_copy.dart';
import 'v3_payment_flow.dart';

/// The one order-confirm dialog, shared by the shop (buy a plan) and the
/// account page (renew the current plan). It renders the billing-period /
/// coupon / price summary, submits the order via `PanelApi.submitOrder`, then
/// hands off to [showV3PaymentFlow] for QR / redirect payment with polling.
Future<void> showV3OrderDialog({
  required BuildContext context,
  required PlanModel plan,
  required BillingCycle initialCycle,
  required PanelApi api,
  required String currencySymbol,
  required Future<void> Function() onPaid,
  required VoidCallback onViewOrders,
}) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.48),
    builder: (_) => _V3OrderDialog(
      hostContext: context,
      plan: plan,
      initialCycle: initialCycle,
      api: api,
      currencySymbol: currencySymbol,
      onPaid: onPaid,
      onViewOrders: onViewOrders,
    ),
  );
}

/// Checkout has one fixed desktop footprint for all plans. On small screens or
/// with the keyboard open, only the viewport caps its size; the body scrolls.
const Key kV3PurchaseDialogBodyKey = ValueKey('v3-purchase-dialog-body');

/// Backend exceptions arrive as `Exception: ...` strings; strip the prefixes
/// the other pages strip, so shop error surfaces show the backend message
/// alone.
String _orderErrorText(Object error) => error.toString()
    .replaceFirst('ApiException: ', '')
    .replaceFirst('Exception: ', '');

class _V3OrderDialog extends StatefulWidget {
  const _V3OrderDialog({
    required this.hostContext,
    required this.plan,
    required this.initialCycle,
    required this.api,
    required this.currencySymbol,
    required this.onPaid,
    required this.onViewOrders,
  });
  final BuildContext hostContext;
  final PlanModel plan;
  final BillingCycle initialCycle;
  final PanelApi api;
  final String currencySymbol;
  final Future<void> Function() onPaid;
  final VoidCallback onViewOrders;
  @override
  State<_V3OrderDialog> createState() => _V3OrderDialogState();
}

class _V3OrderDialogState extends State<_V3OrderDialog> {
  late BillingCycle _cycle;
  final _couponController = TextEditingController();
  CouponResult? _couponResult;
  String? _appliedCode;
  bool _checkingCoupon = false;
  bool _submitting = false;
  String? _error;

  CouponResult? get _activeCoupon => _couponResult != null &&
      _couponController.text.trim() == _appliedCode ? _couponResult : null;
  @override
  void initState() { super.initState(); _cycle = widget.initialCycle; }
  @override
  void dispose() { _couponController.dispose(); super.dispose(); }

  double get _originalPrice => v3PlanPrice(widget.plan, _cycle) ?? 0;
  int get _discountCents {
    final coupon = _activeCoupon;
    if (coupon == null) return 0;
    if (coupon.type == 1) return coupon.value;
    if (coupon.type == 2) {
      return ((_originalPrice * 100) * coupon.value / 100).round();
    }
    return 0;
  }
  double get _finalPrice => (((_originalPrice * 100).round() - _discountCents)
      .clamp(0, 1 << 31)) / 100;

  Future<void> _verifyCoupon() async {
    final code = _couponController.text.trim();
    if (_checkingCoupon || code.isEmpty) return;
    setState(() { _checkingCoupon = true; _error = null; });
    try {
      final result = await widget.api.verifyCoupon(code, int.parse(widget.plan.id));
      if (!mounted) return;
      setState(() {
        _couponResult = result;
        _appliedCode = result == null ? null : code;
        if (result == null) {
          _error = v3Copy(context,
            zh: '优惠码无效或不可用于当前套餐',
            en: 'Coupon is invalid or not applicable to this plan',
            tw: '優惠碼無效或不適用於目前方案');
        }
      });
    } catch (error) {
      if (mounted) setState(() => _error = _orderErrorText(error));
    } finally {
      if (mounted) setState(() => _checkingCoupon = false);
    }
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() { _submitting = true; _error = null; });
    try {
      final expectedAmount = _finalPrice;
      final tradeNo = await widget.api.submitOrder(
        planId: int.parse(widget.plan.id),
        period: _periodKey(widget.plan, _cycle),
        couponCode: _activeCoupon == null ? null : _appliedCode);
      if (!mounted) return;
      Navigator.of(context).pop();
      if (!widget.hostContext.mounted) return;
      await showV3PaymentFlow(
        context: widget.hostContext,
        tradeNo: tradeNo,
        fallbackAmount: expectedAmount,
        currencySymbol: widget.currencySymbol,
        api: widget.api,
        onPaid: widget.onPaid,
        onViewOrders: widget.onViewOrders,
      );
    } catch (error) {
      if (mounted) setState(() { _error = _orderErrorText(error); _submitting = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    final cycles = _availableCycles(widget.plan);
    final media = MediaQuery.of(context);
    // Fixed-size checkout on desktop, with only viewport/keyboard safety caps.
    final availableHeight = (media.size.height - media.viewInsets.bottom -
        media.padding.top - media.padding.bottom - 24)
        .clamp(0.0, 520.0).toDouble();
    final availableWidth = (media.size.width - 24)
        .clamp(0.0, 440.0).toDouble();
    return Dialog(
      backgroundColor: p.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(V3Radius.card)),
      child: SizedBox(
        key: kV3PurchaseDialogBodyKey,
        width: availableWidth,
        height: availableHeight,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(child: Text(widget.plan.title, maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.headlineMedium)),
              IconButton(tooltip: v3Copy(context, zh: '关闭', en: 'Close', tw: '關閉'),
                onPressed: _submitting ? null : () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded)),
            ]),
            Divider(color: p.line),
            Expanded(child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 6),
                  Text(widget.plan.category == PlanCategory.recurring
                      ? v3Copy(context, zh: '选择付款周期', en: 'Choose billing period', tw: '選擇付款週期')
                      : v3Copy(context, zh: '购买方式', en: 'Purchase type', tw: '購買方式'),
                    style: TextStyle(color: p.ink, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  if (widget.plan.category != PlanCategory.recurring)
                    V3Panel(tone: V3PanelTone.raised,
                      padding: const EdgeInsets.all(12),
                      child: Text(v3Copy(context, zh: '一次性购买', en: 'One-time purchase', tw: '一次性購買')))
                  else Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final cycle in cycles)
                      _CycleOption(label: v3CycleLabel(context, cycle),
                        price: '${widget.currencySymbol}${v3PlanPrice(widget.plan, cycle)!.toStringAsFixed(2)}',
                        selected: _cycle == cycle,
                        onTap: () => setState(() {
                          _cycle = cycle;
                          _couponResult = null;
                          _appliedCode = null;
                        })),
                  ]),
                  const SizedBox(height: 16),
                  Text(v3Copy(context, zh: '优惠码', en: 'Coupon code', tw: '優惠碼'),
                    style: TextStyle(color: p.ink, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 7),
                  Row(children: [
                    Expanded(child: TextField(controller: _couponController,
                      onChanged: (_) => setState(() => _error = null),
                      decoration: InputDecoration(hintText: v3Copy(context,
                        zh: '选填优惠码', en: 'Coupon code (optional)', tw: '選填優惠碼')))),
                    const SizedBox(width: 9),
                    OutlinedButton(onPressed: _checkingCoupon ? null : _verifyCoupon,
                      child: Text(_checkingCoupon
                        ? v3Copy(context, zh: '验证中', en: 'Verifying', tw: '驗證中')
                        : v3Copy(context, zh: '验证', en: 'Verify', tw: '驗證'))),
                  ]),
                  if (_activeCoupon != null) ...[
                    const SizedBox(height: 8),
                    Text(v3Copy(context, zh: '优惠码已生效', en: 'Coupon applied', tw: '優惠碼已生效'),
                      style: TextStyle(color: p.successInk, fontSize: 12)),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 10),
                    Text(_error!, style: TextStyle(color: p.dangerInk, fontSize: 12)),
                  ],
                  const SizedBox(height: 16),
                  V3Panel(tone: V3PanelTone.raised,
                    padding: const EdgeInsets.all(12), child: Column(children: [
                      _AmountRow(label: v3Copy(context, zh: '套餐', en: 'Plan', tw: '方案'),
                        value: widget.plan.title),
                      const SizedBox(height: 8),
                      _AmountRow(label: v3Copy(context, zh: '付款周期', en: 'Billing period', tw: '付款週期'),
                        value: widget.plan.category == PlanCategory.recurring
                          ? v3CycleLabel(context, _cycle)
                          : v3Copy(context, zh: '一次性', en: 'One-time', tw: '一次性')),
                      const SizedBox(height: 8),
                      _AmountRow(label: v3Copy(context, zh: '原价', en: 'Original price', tw: '原價'),
                        value: '${widget.currencySymbol}${_originalPrice.toStringAsFixed(2)}'),
                      if (_discountCents > 0) ...[
                        const SizedBox(height: 8),
                        _AmountRow(label: v3Copy(context, zh: '优惠', en: 'Discount', tw: '優惠'),
                          value: '-${widget.currencySymbol}${(_discountCents / 100).toStringAsFixed(2)}'),
                      ],
                      const SizedBox(height: 9),
                      Divider(color: p.line),
                      _AmountRow(label: v3Copy(context, zh: '实付金额', en: 'Total due', tw: '實付金額'),
                        value: '${widget.currencySymbol}${_finalPrice.toStringAsFixed(2)}',
                        strong: true),
                    ])),
                  const SizedBox(height: 8),
                ],
              ),
            )),
            Divider(color: p.line, height: 12),
            SizedBox(height: 44,
              child: FilledButton(
                onPressed: _submitting || v3PlanPrice(widget.plan, _cycle) == null
                  ? null : _submit,
                style: FilledButton.styleFrom(backgroundColor: p.lychee,
                  foregroundColor: p.onLychee),
                child: Text(_submitting
                  ? v3Copy(context, zh: '正在创建订单…', en: 'Creating order…', tw: '正在建立訂單…')
                  : v3Copy(context, zh: '确认并创建订单', en: 'Confirm and create order',
                    tw: '確認並建立訂單')))),
          ]),
        ),
      ),
    );
  }
}

class _CycleOption extends StatelessWidget {
  const _CycleOption({required this.label, required this.price,
    required this.selected, required this.onTap});
  final String label;
  final String price;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    // AnimatedContainer stays outside so the selection fill keeps animating;
    // V3Pressable inside it puts the ink above the opaque fill. The padding
    // rides inside the pressable so the whole card stays tappable.
    return AnimatedContainer(duration: const Duration(milliseconds: 160),
      width: 132,
      decoration: BoxDecoration(
        color: selected ? p.lycheeSoft : p.surfaceRaised,
        border: Border.all(color: selected ? p.lychee : p.line,
          width: selected ? 1.5 : 1),
        borderRadius: BorderRadius.circular(V3Radius.field)),
      child: V3Pressable(borderRadius: BorderRadius.circular(V3Radius.field), onTap: onTap,
        child: Padding(padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(label, style: TextStyle(
                color: selected ? p.lycheeInk : p.ink,
                fontSize: 13, fontWeight: FontWeight.w800))),
              if (selected) Icon(Icons.check_circle_rounded,
                size: 16, color: p.lycheeInk),
            ]),
            const SizedBox(height: 7),
            Text(price, style: TextStyle(color: selected ? p.lycheeInk : p.ink,
              fontSize: 15, fontWeight: FontWeight.w800)),
          ]))),
    );
  }
}

class _AmountRow extends StatelessWidget {
  const _AmountRow({required this.label, required this.value, this.strong = false});
  final String label;
  final String value;
  final bool strong;
  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return Row(children: [
      Text(label, style: TextStyle(color: strong ? p.ink : p.inkMuted,
        fontSize: strong ? 14 : 12,
        fontWeight: strong ? FontWeight.w800 : FontWeight.w500)),
      const SizedBox(width: 10),
      Expanded(child: Text(value, textAlign: TextAlign.end, maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: p.ink, fontSize: strong ? 21 : 12,
          fontWeight: strong ? FontWeight.w900 : FontWeight.w700))),
    ]);
  }
}

List<BillingCycle> _availableCycles(PlanModel plan) {
  if (plan.category != PlanCategory.recurring) return const [BillingCycle.monthly];
  return [
    if (plan.monthlyPrice != null) BillingCycle.monthly,
    if (plan.quarterlyPrice != null) BillingCycle.quarterly,
    if (plan.halfYearPrice != null) BillingCycle.halfYear,
    if (plan.yearlyPrice != null) BillingCycle.yearly,
    if (plan.twoYearPrice != null) BillingCycle.twoYears,
    if (plan.threeYearPrice != null) BillingCycle.threeYears,
  ];
}

/// The cycle a purchase (or renew) opens on: the first available cycle for a
/// recurring plan, monthly for a one-time / data-pack plan.
BillingCycle v3DefaultCycle(PlanModel plan) {
  final cycles = _availableCycles(plan);
  return cycles.isEmpty ? BillingCycle.monthly : cycles.first;
}

double? v3PlanPrice(PlanModel plan, BillingCycle cycle) =>
    plan.category != PlanCategory.recurring
        ? plan.oneTimePrice : plan.priceForCycle(cycle);

String _periodKey(PlanModel plan, BillingCycle cycle) {
  if (plan.category != PlanCategory.recurring) return 'onetime_price';
  return switch (cycle) {
    BillingCycle.monthly => 'month_price',
    BillingCycle.quarterly => 'quarter_price',
    BillingCycle.halfYear => 'half_year_price',
    BillingCycle.yearly => 'year_price',
    BillingCycle.twoYears => 'two_year_price',
    BillingCycle.threeYears => 'three_year_price',
  };
}

String v3CycleLabel(BuildContext context, BillingCycle cycle) => switch (cycle) {
  BillingCycle.monthly => v3Copy(context, zh: '月付', en: 'Monthly', tw: '月付'),
  BillingCycle.quarterly => v3Copy(context, zh: '季付', en: 'Quarterly', tw: '季付'),
  BillingCycle.halfYear => v3Copy(context, zh: '半年', en: 'Half-year', tw: '半年'),
  BillingCycle.yearly => v3Copy(context, zh: '年付', en: 'Yearly', tw: '年付'),
  BillingCycle.twoYears => v3Copy(context, zh: '两年', en: 'Two years', tw: '兩年'),
  BillingCycle.threeYears => v3Copy(context, zh: '三年', en: 'Three years', tw: '三年'),
};

String v3CategoryLabel(BuildContext context, PlanCategory category) =>
    switch (category) {
      PlanCategory.recurring => v3Copy(context, zh: '周期套餐', en: 'Recurring plan', tw: '週期方案'),
      PlanCategory.oneTime => v3Copy(context, zh: '不限时套餐', en: 'No-expiry plan', tw: '不限時方案'),
      PlanCategory.dataPack => v3Copy(context, zh: '流量包', en: 'Data pack', tw: '流量包'),
    };