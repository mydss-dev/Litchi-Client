import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../shared/models/api_models.dart';
import '../../shared/models/app_models.dart';
import '../../shared/services/panel_api.dart';
import '../commerce/v3_payment_flow.dart';
import '../theme/v3_palette.dart';
import '../ui/v3_components.dart';
import '../ui/v3_sheet.dart';

/// Each plan is a separate product card. Two fit the default desktop window.
class V3ShopPage extends StatefulWidget {
  const V3ShopPage({super.key});
  @override
  State<V3ShopPage> createState() => _V3ShopPageState();
}

class _V3ShopPageState extends State<V3ShopPage> {
  PlanCategory? _category;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final p = V3Palette.of(context);
    final plans = controller.plans
        .where((plan) => _category == null || plan.category == _category)
        .toList(growable: false);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 36),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const V3PageHeader(kicker: '套餐商城', title: '选择套餐'),
        const SizedBox(height: 18),
        V3Panel(tone: V3PanelTone.raised,
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
          child: Row(children: [
            Icon(Icons.verified_rounded,
              color: controller.hasPlan ? p.successInk : p.inkMuted, size: 18),
            const SizedBox(width: 9),
            Expanded(child: Text(
              controller.hasPlan
                ? '当前：${controller.user.plan.trim().isEmpty ? '已激活套餐' : controller.user.plan.trim()}'
                : '当前没有已激活套餐',
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(color: p.ink, fontSize: 12,
                fontWeight: FontWeight.w700))),
            Text('${controller.traffic.remainGb.toStringAsFixed(1)} GB',
              style: TextStyle(color: p.inkMuted, fontSize: 11)),
          ])),
        const SizedBox(height: 14),
        _CategorySelector(value: _category,
          onChanged: (v) => setState(() => _category = v)),
        const SizedBox(height: 14),
        if (plans.isEmpty)
          V3Panel(child: Column(children: [
            const Text('当前分类暂无可购买套餐'),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: controller.refreshData,
              child: const Text('刷新套餐')),
          ]))
        else
          LayoutBuilder(builder: (context, constraints) {
            final twoColumns = constraints.maxWidth >= 590;
            final cards = <Widget>[];
            for (var i = 0; i < plans.length; i += twoColumns ? 2 : 1) {
              cards.add(Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: IntrinsicHeight(child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var j = i;
                      j < plans.length && j < i + (twoColumns ? 2 : 1);
                      j++) ...[
                      if (j > i) const SizedBox(width: 12),
                      Expanded(child: _PlanCard(
                        plan: plans[j], symbol: controller.currencySymbol,
                        onBuy: () => _openOrder(controller, plans[j]))),
                    ],
                    if (twoColumns && i + 1 >= plans.length) ...[
                      const SizedBox(width: 12),
                      const Expanded(child: SizedBox.shrink()),
                    ],
                  ],
                )),
              ));
            }
            return Column(children: cards);
          }),
      ]),
    );
  }

  Future<void> _openOrder(AppController controller, PlanModel plan) =>
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.48),
      builder: (_) => _OrderDialog(
        hostContext: context, plan: plan,
        symbol: controller.currencySymbol, api: controller.api,
        onPaid: controller.refreshData,
        onViewOrders: () => openV3Page(context, AppPage.orders),
      ),
    );
}

class _CategorySelector extends StatelessWidget {
  const _CategorySelector({required this.value, required this.onChanged});
  final PlanCategory? value;
  final ValueChanged<PlanCategory?> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    const options = <(PlanCategory?, String)>[
      (null, '全部'), (PlanCategory.recurring, '周期'),
      (PlanCategory.oneTime, '不限时'), (PlanCategory.dataPack, '流量包'),
    ];
    return V3Panel(tone: V3PanelTone.raised,
      padding: const EdgeInsets.all(4),
      child: Row(children: [
        for (final option in options)
          Expanded(child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => onChanged(option.$1),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: value == option.$1 ? p.surface : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: value == option.$1
                  ? p.line : Colors.transparent)),
              child: Text(option.$2, textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                  color: value == option.$1 ? p.lycheeInk : p.ink)),
            ),
          )),
      ]),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.plan, required this.symbol,
    required this.onBuy});
  final PlanModel plan;
  final String symbol;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    final cycle = _availableCycles(plan).firstOrNull;
    final price = cycle == null ? null : _price(plan, cycle);
    final summary = plan.features.take(3).toList(growable: false);
    return V3Panel(radius: 20, padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Text(plan.title, maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: p.ink, fontSize: 17,
              fontWeight: FontWeight.w800))),
          if (plan.featured || plan.hot) ...[
            const SizedBox(width: 6),
            Icon(Icons.stars_rounded, color: p.lycheeInk, size: 18),
          ],
        ]),
        const SizedBox(height: 5),
        Text(_categoryLabel(plan.category),
          style: TextStyle(color: p.inkMuted, fontSize: 11)),
        const SizedBox(height: 17),
        Text(plan.capacity.isEmpty ? '流量以详情为准' : plan.capacity,
          style: TextStyle(color: p.ink, fontSize: 25,
            fontWeight: FontWeight.w900)),
        Text('套餐流量', style: TextStyle(color: p.inkMuted, fontSize: 11)),
        const SizedBox(height: 15),
        Divider(color: p.line, height: 1),
        const SizedBox(height: 14),
        if (summary.isEmpty)
          Text('查看套餐详情了解使用规则',
            style: TextStyle(color: p.inkMuted, fontSize: 12))
        else
          for (final feature in summary)
            Padding(padding: const EdgeInsets.only(bottom: 8),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.check_circle_outline_rounded,
                    color: p.successInk, size: 15),
                  const SizedBox(width: 7),
                  Expanded(child: Text(feature, maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: p.inkMuted,
                      fontSize: 12, height: 1.4))),
                ])),
        // Show the full description even for a single long paragraph that was
        // abbreviated to two lines in the card.
        if (plan.features.isNotEmpty)
          Align(alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => _showPlanDetails(context, plan),
              child: const Text('查看完整说明'))),
        const Spacer(),
        const SizedBox(height: 15),
        Divider(color: p.line, height: 1),
        const SizedBox(height: 12),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(child: Text(price == null ? '暂不可购买'
              : '$symbol${price.toStringAsFixed(2)}',
            style: TextStyle(color: p.ink, fontSize: 23,
              fontWeight: FontWeight.w900))),
          Text(plan.category == PlanCategory.recurring
              ? '起 / ${_cycleLabel(cycle!)}' : '一次性',
            style: TextStyle(color: p.inkMuted, fontSize: 11)),
        ]),
        const SizedBox(height: 12),
        SizedBox(height: 44, child: FilledButton(
          onPressed: plan.soldOut || price == null ? null : onBuy,
          style: FilledButton.styleFrom(backgroundColor: p.lychee,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12))),
          child: Text(plan.soldOut ? '已售罄' : '选择套餐'),
        )),
      ]),
    );
  }
}

void _showPlanDetails(BuildContext context, PlanModel plan) {
  final p = V3Palette.of(context);
  showV3Sheet<void>(context, title: plan.title,
    builder: (_) => Column(crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${_categoryLabel(plan.category)} · ${plan.capacity}',
          style: TextStyle(color: p.inkMuted, fontSize: 12)),
        const SizedBox(height: 16),
        for (final line in plan.features)
          Padding(padding: const EdgeInsets.only(bottom: 12),
            child: Text(line, style: TextStyle(color: p.ink,
              fontSize: 13, height: 1.5))),
      ]));
}

class _OrderDialog extends StatefulWidget {
  const _OrderDialog({required this.hostContext, required this.plan,
    required this.symbol, required this.api, required this.onPaid,
    required this.onViewOrders});
  final BuildContext hostContext;
  final PlanModel plan;
  final String symbol;
  final PanelApi api;
  final Future<void> Function() onPaid;
  final VoidCallback onViewOrders;
  @override
  State<_OrderDialog> createState() => _OrderDialogState();
}

class _OrderDialogState extends State<_OrderDialog> {
  late BillingCycle _cycle;
  final _couponField = TextEditingController();
  CouponResult? _coupon;
  String? _verifiedCode;
  bool _checking = false;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cycle = _availableCycles(widget.plan).firstOrNull ?? BillingCycle.monthly;
  }
  @override
  void dispose() {
    _couponField.dispose();
    super.dispose();
  }

  CouponResult? get _activeCoupon =>
      _couponField.text.trim() == _verifiedCode ? _coupon : null;
  double get _original => _price(widget.plan, _cycle) ?? 0;
  int get _discount {
    final coupon = _activeCoupon;
    if (coupon == null) return 0;
    if (coupon.type == 1) return coupon.value;
    if (coupon.type == 2) {
      return ((_original * 100) * coupon.value / 100).round();
    }
    return 0;
  }
  double get _total =>
      ((_original * 100).round() - _discount).clamp(0, 1 << 31) / 100;

  Future<void> _verify() async {
    final code = _couponField.text.trim();
    final cycle = _cycle;
    if (_checking || code.isEmpty) return;
    setState(() { _checking = true; _error = null; _coupon = null; });
    try {
      final result = await widget.api.verifyCoupon(
        code, int.parse(widget.plan.id));
      if (!mounted) return;
      setState(() {
        if (code == _couponField.text.trim() && cycle == _cycle) {
          _coupon = result;
          _verifiedCode = result == null ? null : code;
          if (result == null) _error = '优惠码无效或不适用于当前套餐';
        }
      });
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() { _submitting = true; _error = null; });
    try {
      final amount = _total;
      final tradeNo = await widget.api.submitOrder(
        planId: int.parse(widget.plan.id),
        period: _periodKey(widget.plan, _cycle),
        couponCode: _activeCoupon == null ? null : _verifiedCode,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      if (!widget.hostContext.mounted) return;
      await showV3PaymentFlow(
        context: widget.hostContext, tradeNo: tradeNo,
        fallbackAmount: amount, currencySymbol: widget.symbol,
        api: widget.api, onPaid: widget.onPaid,
        onViewOrders: widget.onViewOrders,
      );
    } catch (e) {
      if (mounted) setState(() { _error = '$e'; _submitting = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    final cycles = _availableCycles(widget.plan);
    return Dialog(backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(18),
      child: Container(width: 520,
        constraints: const BoxConstraints(maxHeight: 640),
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(color: p.surface,
          borderRadius: BorderRadius.circular(24)),
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(child: Text(widget.plan.title,
                  style: Theme.of(context).textTheme.headlineLarge)),
                IconButton(tooltip: '关闭', onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded)),
              ]),
              const SizedBox(height: 5),
              Text('${widget.plan.capacity} · ${_categoryLabel(widget.plan.category)}',
                style: TextStyle(color: p.inkMuted, fontSize: 12)),
              const SizedBox(height: 24),
              Text(widget.plan.category == PlanCategory.recurring
                  ? '选择付款周期' : '付款方式',
                style: TextStyle(color: p.ink, fontSize: 13,
                  fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              if (widget.plan.category != PlanCategory.recurring)
                _CycleChoice(label: '一次性付款',
                  price: '${widget.symbol}${_original.toStringAsFixed(2)}',
                  selected: true, onTap: () {})
              else
                LayoutBuilder(builder: (context, constraints) {
                  final itemWidth = (constraints.maxWidth - 8) / 2;
                  return Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final cycle in cycles)
                      SizedBox(width: itemWidth, child: _CycleChoice(
                        label: _cycleLabel(cycle),
                        price: '${widget.symbol}${_price(widget.plan, cycle)!.toStringAsFixed(2)}',
                        selected: cycle == _cycle,
                        onTap: () => setState(() {
                          _cycle = cycle;
                          _coupon = null;
                          _verifiedCode = null;
                        }),
                      )),
                  ]);
                }),
              const SizedBox(height: 24),
              Text('优惠码', style: TextStyle(color: p.ink,
                fontSize: 13, fontWeight: FontWeight.w800)),
              const SizedBox(height: 9),
              Row(children: [
                Expanded(child: TextField(
                  controller: _couponField,
                  onChanged: (_) => setState(() => _error = null),
                  decoration: const InputDecoration(hintText: '选填优惠码'),
                )),
                const SizedBox(width: 8),
                OutlinedButton(onPressed: _checking ? null : _verify,
                  child: Text(_checking ? '验证中' : '验证')),
              ]),
              if (_activeCoupon != null)
                Padding(padding: const EdgeInsets.only(top: 8),
                  child: Text('优惠码已生效',
                    style: TextStyle(color: p.successInk, fontSize: 12))),
              if (_error != null)
                Padding(padding: const EdgeInsets.only(top: 8),
                  child: Text(_error!,
                    style: TextStyle(color: p.dangerInk, fontSize: 12))),
              const SizedBox(height: 20),
              V3Panel(tone: V3PanelTone.raised,
                padding: const EdgeInsets.all(14),
                child: Column(children: [
                  _BillRow(label: '原价', value:
                    '${widget.symbol}${_original.toStringAsFixed(2)}'),
                  if (_discount > 0) ...[
                    const SizedBox(height: 8),
                    _BillRow(label: '优惠', value:
                      '-${widget.symbol}${(_discount / 100).toStringAsFixed(2)}'),
                  ],
                  const SizedBox(height: 9),
                  Divider(color: p.line, height: 1),
                  const SizedBox(height: 9),
                  _BillRow(label: '实付金额', value:
                    '${widget.symbol}${_total.toStringAsFixed(2)}',
                    prominent: true),
                ])),
              const SizedBox(height: 16),
              SizedBox(width: double.infinity, height: 48,
                child: FilledButton(
                  onPressed: _submitting || cycles.isEmpty ? null : _submit,
                  style: FilledButton.styleFrom(backgroundColor: p.lychee,
                    foregroundColor: Colors.white),
                  child: Text(_submitting ? '正在创建订单…' : '确认并创建订单'),
                )),
            ],
          ),
        ),
      ),
    );
  }
}

class _CycleChoice extends StatelessWidget {
  const _CycleChoice({required this.label, required this.price,
    required this.selected, required this.onTap});
  final String label;
  final String price;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? p.lycheeSoft : p.surfaceRaised,
          border: Border.all(color: selected ? p.lycheeInk : p.line,
            width: selected ? 1.5 : 1),
          borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: selected ? p.lycheeInk : p.ink,
                fontSize: 13, fontWeight: FontWeight.w800)),
              const SizedBox(height: 3),
              Text(price, style: TextStyle(color: selected ? p.lycheeInk : p.inkMuted,
                fontSize: 12)),
            ])),
          if (selected) Icon(Icons.check_circle_rounded,
            color: p.lycheeInk, size: 18),
        ]),
      ));
  }
}

class _BillRow extends StatelessWidget {
  const _BillRow({required this.label, required this.value,
    this.prominent = false});
  final String label;
  final String value;
  final bool prominent;
  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return Row(children: [
      Expanded(child: Text(label, style: TextStyle(color: p.inkMuted,
        fontSize: prominent ? 13 : 12))),
      Text(value, style: TextStyle(color: p.ink,
        fontSize: prominent ? 22 : 13,
        fontWeight: prominent ? FontWeight.w900 : FontWeight.w700)),
    ]);
  }
}

List<BillingCycle> _availableCycles(PlanModel plan) {
  if (plan.category != PlanCategory.recurring) {
    return plan.oneTimePrice == null ? const [] : const [BillingCycle.monthly];
  }
  return [
    if (plan.monthlyPrice != null) BillingCycle.monthly,
    if (plan.quarterlyPrice != null) BillingCycle.quarterly,
    if (plan.halfYearPrice != null) BillingCycle.halfYear,
    if (plan.yearlyPrice != null) BillingCycle.yearly,
    if (plan.twoYearPrice != null) BillingCycle.twoYears,
    if (plan.threeYearPrice != null) BillingCycle.threeYears,
  ];
}

double? _price(PlanModel plan, BillingCycle cycle) =>
  plan.category == PlanCategory.recurring
    ? plan.priceForCycle(cycle) : plan.oneTimePrice;

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

String _cycleLabel(BillingCycle cycle) => switch (cycle) {
  BillingCycle.monthly => '月付', BillingCycle.quarterly => '季付',
  BillingCycle.halfYear => '半年', BillingCycle.yearly => '年付',
  BillingCycle.twoYears => '两年', BillingCycle.threeYears => '三年',
};

String _categoryLabel(PlanCategory category) => switch (category) {
  PlanCategory.recurring => '周期套餐',
  PlanCategory.oneTime => '不限时套餐',
  PlanCategory.dataPack => '流量包',
};
