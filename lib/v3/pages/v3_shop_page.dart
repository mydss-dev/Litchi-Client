import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../app/plan_presentation.dart';
import '../../shared/models/api_models.dart';
import '../../shared/models/app_models.dart';
import '../../shared/services/panel_api.dart';
import '../commerce/v3_payment_flow.dart';
import '../theme/v3_palette.dart';
import '../ui/v3_components.dart';
import '../ui/v3_sheet.dart';

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
    final plans = controller.plans.where((plan) =>
        _category == null || plan.category == _category).toList(growable: false);
    return LayoutBuilder(builder: (context, constraints) {
      const padding = 24.0;
      const spacing = 12.0;
      final contentWidth = constraints.maxWidth - padding * 2;
      final twoColumns = contentWidth >= 600;
      final cardWidth = twoColumns ? (contentWidth - spacing) / 2 : contentWidth;
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(padding, 24, padding, 36),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const V3PageHeader(kicker: '套餐商城', title: '选择套餐'),
          const SizedBox(height: 18),
          _CurrentPlanBadge(controller: controller),
          const SizedBox(height: 14),
          _CategoryDeck(selected: _category,
            onChanged: (value) => setState(() => _category = value)),
          const SizedBox(height: 14),
          if (plans.isEmpty)
            V3Panel(child: Column(children: [
              const Text('当前分类没有可购买套餐'),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: controller.refreshData,
                child: const Text('刷新套餐')),
            ]))
          else Wrap(spacing: spacing, runSpacing: spacing, children: [
            for (final plan in plans) SizedBox(width: cardWidth,
              child: _PlanCard(plan: plan,
                currencySymbol: controller.currencySymbol,
                desktop: twoColumns,
                onBuy: () => _openOrder(controller, plan, _defaultCycle(plan)))),
          ]),
        ]),
      );
    });
  }

  Future<void> _openOrder(AppController controller, PlanModel plan,
      BillingCycle cycle) => showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.48),
    builder: (_) => _V3OrderDialog(
      hostContext: context,
      plan: plan,
      initialCycle: cycle,
      api: controller.api,
      currencySymbol: controller.currencySymbol,
      onPaid: controller.refreshData,
      onViewOrders: () => openV3Page(context, AppPage.orders),
    ),
  );
}

class _CategoryDeck extends StatelessWidget {
  const _CategoryDeck({required this.selected, required this.onChanged});
  final PlanCategory? selected;
  final ValueChanged<PlanCategory?> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    const items = <(PlanCategory?, String)>[
      (null, '全部'),
      (PlanCategory.recurring, '周期'),
      (PlanCategory.oneTime, '不限时'),
      (PlanCategory.dataPack, '流量包'),
    ];
    return V3Panel(tone: V3PanelTone.raised,
      padding: const EdgeInsets.all(5),
      child: Row(children: [
        for (final item in items) Expanded(child: InkWell(
          borderRadius: BorderRadius.circular(9),
          onTap: () => onChanged(item.$1),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: selected == item.$1 ? p.surface : Colors.transparent,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: selected == item.$1
                  ? p.lychee : Colors.transparent)),
            child: Text(item.$2, textAlign: TextAlign.center,
              style: TextStyle(color: selected == item.$1 ? p.lycheeInk : p.ink,
                fontSize: 12, fontWeight: FontWeight.w700)),
          ),
        )),
      ]),
    );
  }
}

class _CurrentPlanBadge extends StatelessWidget {
  const _CurrentPlanBadge({required this.controller});
  final AppController controller;
  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    final plan = PlanPresentation.fromController(controller);
    return V3Panel(padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
      child: Row(children: [
        Icon(plan.usable ? Icons.verified_rounded : Icons.info_outline_rounded,
          size: 17, color: plan.usable ? p.success : p.inkMuted),
        const SizedBox(width: 9),
        Expanded(child: Tooltip(message: '${plan.shortLabel} · ${plan.expiry}',
          child: Text(plan.shortLabel, maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: p.ink, fontSize: 12,
              fontWeight: FontWeight.w700)))),
        if (controller.traffic.totalGb > 0)
          Text('剩余 ${controller.traffic.remainGb.toStringAsFixed(1)} GB',
            style: TextStyle(color: p.inkMuted, fontSize: 11)),
      ]),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.plan, required this.currencySymbol,
    required this.desktop, required this.onBuy});
  final PlanModel plan;
  final String currencySymbol;
  final bool desktop;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    final cycle = _defaultCycle(plan);
    final price = _price(plan, cycle);
    final features = plan.features.take(3).toList(growable: false);
    final info = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Text(plan.title, maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: p.ink, fontSize: 17,
            fontWeight: FontWeight.w800))),
        if (plan.featured || plan.hot)
          V3StatusBadge(label: plan.featured ? '推荐' : '热门',
            color: p.lychee, compact: true),
      ]),
      const SizedBox(height: 4),
      Text(_categoryLabel(plan.category),
        style: TextStyle(color: p.inkMuted, fontSize: 11)),
      const SizedBox(height: 15),
      Text(plan.capacity.isEmpty ? '流量未标注' : plan.capacity,
        style: TextStyle(color: p.ink, fontSize: 29, fontWeight: FontWeight.w900)),
      const SizedBox(height: 14),
      Divider(color: p.line, height: 1),
      const SizedBox(height: 12),
      if (features.isEmpty)
        Text('暂无套餐说明', style: TextStyle(color: p.inkMuted, fontSize: 12))
      else ...[
        for (final feature in features) Padding(
          padding: const EdgeInsets.only(bottom: 7),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.check_rounded, color: p.successInk, size: 15),
            const SizedBox(width: 7),
            Expanded(child: Text(feature, maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: p.inkMuted, fontSize: 12, height: 1.35))),
          ])),
        Align(alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () => _showPlanDetails(context, plan),
            style: TextButton.styleFrom(padding: EdgeInsets.zero,
              minimumSize: const Size(0, 30)),
            child: Text(plan.features.length > features.length
                ? '查看完整说明' : '套餐详情',
              style: TextStyle(color: p.lycheeInk, fontSize: 12,
                fontWeight: FontWeight.w700)))),
      ],
    ]);
    final purchase = Column(crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Divider(color: p.line, height: 1),
        const SizedBox(height: 11),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(child: Text(price == null ? '价格未配置' :
              '$currencySymbol${price.toStringAsFixed(2)}',
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(color: p.ink, fontSize: price == null ? 14 : 24,
              fontWeight: FontWeight.w900))),
          Text(plan.category == PlanCategory.recurring
              ? _cycleLabel(cycle) : '一次性',
            style: TextStyle(color: p.inkMuted, fontSize: 11)),
        ]),
        const SizedBox(height: 12),
        SizedBox(width: double.infinity, height: 44,
          child: FilledButton(
            onPressed: plan.soldOut || price == null ? null : onBuy,
            style: FilledButton.styleFrom(backgroundColor: p.lychee,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(13))),
            child: Text(plan.soldOut ? '已售罄' : '选择套餐'))),
      ]);
    return V3Panel(padding: const EdgeInsets.all(16),
      child: desktop
        ? SizedBox(height: 380,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [Expanded(child: info), purchase]))
        : Column(crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [info, const SizedBox(height: 14), purchase]));
  }
}

Future<void> _showPlanDetails(BuildContext context, PlanModel plan) =>
    showV3Sheet<void>(context, title: plan.title, builder: (sheetContext) {
  final p = V3Palette.of(sheetContext);
  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text('${_categoryLabel(plan.category)} · ${plan.capacity}',
      style: TextStyle(color: p.inkMuted, fontSize: 12)),
    const SizedBox(height: 16),
    if (plan.deviceLimit != null)
      Padding(padding: const EdgeInsets.only(bottom: 10),
        child: Text('设备数量：${plan.deviceLimit}',
          style: TextStyle(color: p.ink))),
    if (plan.features.isEmpty)
      const Text('后台尚未配置套餐描述')
    else for (final feature in plan.features)
      Padding(padding: const EdgeInsets.only(bottom: 12),
        child: Text(feature,
          style: TextStyle(color: p.ink, fontSize: 13, height: 1.55))),
  ]);
});

class _V3OrderDialog extends StatefulWidget {
  const _V3OrderDialog({required this.hostContext, required this.plan,
    required this.initialCycle, required this.api,
    required this.currencySymbol, required this.onPaid,
    required this.onViewOrders});
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

  double get _originalPrice => _price(widget.plan, _cycle) ?? 0;
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
        if (result == null) _error = '优惠码无效或不可用于当前套餐';
      });
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
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
      await showV3PaymentFlow(context: widget.hostContext,
        tradeNo: tradeNo, fallbackAmount: expectedAmount,
        currencySymbol: widget.currencySymbol, api: widget.api,
        onPaid: widget.onPaid, onViewOrders: widget.onViewOrders);
    } catch (error) {
      if (mounted) setState(() { _error = '$error'; _submitting = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    final cycles = _availableCycles(widget.plan);
    final media = MediaQuery.of(context);
    // Dialog also respects its route's viewInsets. Bound our own child to the
    // remaining viewport so the keyboard cannot cover or clip the footer.
    final availableHeight = (media.size.height - media.viewInsets.bottom -
        media.padding.top - media.padding.bottom - 24)
        .clamp(160.0, 640.0).toDouble();
    final availableWidth = (media.size.width - 24).clamp(280.0, 520.0).toDouble();
    return Dialog(
      backgroundColor: p.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: SizedBox(
        width: availableWidth,
        height: availableHeight,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            // Title and purchase action stay outside the scrollable section.
            Row(children: [
              Expanded(child: Text(widget.plan.title, maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.headlineLarge)),
              IconButton(tooltip: '关闭',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded)),
            ]),
            Divider(color: p.line),
            Expanded(child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  Text('${_categoryLabel(widget.plan.category)} · ${widget.plan.capacity}',
                    style: TextStyle(color: p.inkMuted, fontSize: 12)),
                  if (widget.plan.features.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    for (final feature in widget.plan.features)
                      Padding(padding: const EdgeInsets.only(bottom: 7),
                        child: Text('• $feature',
                          style: TextStyle(color: p.ink, fontSize: 12, height: 1.4))),
                  ],
                  const SizedBox(height: 22),
                  Text(widget.plan.category == PlanCategory.recurring
                      ? '选择付款周期' : '购买方式',
                    style: TextStyle(color: p.ink, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  if (widget.plan.category != PlanCategory.recurring)
                    const V3Panel(tone: V3PanelTone.raised,
                      padding: EdgeInsets.all(12), child: Text('一次性购买'))
                  else Wrap(spacing: 9, runSpacing: 9, children: [
                    for (final cycle in cycles)
                      _CycleOption(label: _cycleLabel(cycle),
                        price: '${widget.currencySymbol}${_price(widget.plan, cycle)!.toStringAsFixed(2)}',
                        selected: _cycle == cycle,
                        onTap: () => setState(() {
                          _cycle = cycle;
                          _couponResult = null;
                          _appliedCode = null;
                        })),
                  ]),
                  const SizedBox(height: 22),
                  Text('优惠码', style: TextStyle(color: p.ink,
                    fontWeight: FontWeight.w800)),
                  const SizedBox(height: 9),
                  Row(children: [
                    Expanded(child: TextField(controller: _couponController,
                      onChanged: (_) => setState(() => _error = null),
                      decoration: const InputDecoration(hintText: '选填优惠码'))),
                    const SizedBox(width: 9),
                    OutlinedButton(onPressed: _checkingCoupon ? null : _verifyCoupon,
                      child: Text(_checkingCoupon ? '验证中' : '验证')),
                  ]),
                  if (_activeCoupon != null) ...[
                    const SizedBox(height: 8),
                    Text('优惠码已生效', style: TextStyle(color: p.successInk,
                      fontSize: 12)),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 10),
                    Text(_error!, style: TextStyle(color: p.dangerInk,
                      fontSize: 12)),
                  ],
                  const SizedBox(height: 22),
                  V3Panel(tone: V3PanelTone.raised,
                    padding: const EdgeInsets.all(16), child: Column(children: [
                      _AmountRow(label: '套餐', value: widget.plan.title),
                      const SizedBox(height: 10),
                      _AmountRow(label: '付款周期',
                        value: widget.plan.category == PlanCategory.recurring
                          ? _cycleLabel(_cycle) : '一次性'),
                      const SizedBox(height: 10),
                      _AmountRow(label: '原价',
                        value: '${widget.currencySymbol}${_originalPrice.toStringAsFixed(2)}'),
                      if (_discountCents > 0) ...[
                        const SizedBox(height: 10),
                        _AmountRow(label: '优惠',
                          value: '-${widget.currencySymbol}${(_discountCents / 100).toStringAsFixed(2)}'),
                      ],
                      const SizedBox(height: 12),
                      Divider(color: p.line),
                      _AmountRow(label: '实付金额',
                        value: '${widget.currencySymbol}${_finalPrice.toStringAsFixed(2)}',
                        strong: true),
                    ])),
                  const SizedBox(height: 10),
                ],
              ),
            )),
            Divider(color: p.line, height: 16),
            SizedBox(height: 48,
              child: FilledButton(
                onPressed: _submitting || _price(widget.plan, _cycle) == null
                  ? null : _submit,
                style: FilledButton.styleFrom(backgroundColor: p.lychee,
                  foregroundColor: Colors.white),
                child: Text(_submitting ? '正在创建订单…' : '确认并创建订单'))),
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
    return InkWell(borderRadius: BorderRadius.circular(12), onTap: onTap,
      child: AnimatedContainer(duration: const Duration(milliseconds: 160),
        width: 132, padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? p.lycheeSoft : p.surfaceRaised,
          border: Border.all(color: selected ? p.lychee : p.line,
            width: selected ? 1.5 : 1),
          borderRadius: BorderRadius.circular(12)),
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
        ]),
      ),
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
BillingCycle _defaultCycle(PlanModel plan) {
  final cycles = _availableCycles(plan);
  return cycles.isEmpty ? BillingCycle.monthly : cycles.first;
}
double? _price(PlanModel plan, BillingCycle cycle) =>
    plan.category != PlanCategory.recurring ? plan.oneTimePrice : plan.priceForCycle(cycle);
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
  BillingCycle.monthly => '月付',
  BillingCycle.quarterly => '季付',
  BillingCycle.halfYear => '半年',
  BillingCycle.yearly => '年付',
  BillingCycle.twoYears => '两年',
  BillingCycle.threeYears => '三年',
};
String _categoryLabel(PlanCategory category) => switch (category) {
  PlanCategory.recurring => '周期套餐',
  PlanCategory.oneTime => '不限时套餐',
  PlanCategory.dataPack => '流量包',
};
