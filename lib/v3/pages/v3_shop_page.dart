import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../app/plan_presentation.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../l10n/generated/app_localizations_zh.dart';
import '../../shared/models/api_models.dart';
import '../../shared/models/app_models.dart';
import '../../shared/services/panel_api.dart';
import '../commerce/v3_payment_flow.dart';
import '../theme/v3_palette.dart';
import '../ui/v3_layout.dart';
import '../ui/v3_components.dart';
import '../ui/v3_sheet.dart';

// Preserve the existing simplified-Chinese V3 copy; use the app's saved locale
// for its English and Traditional Chinese variants. Backend plan titles and
// descriptions are user content and must never be machine-substituted here.
String _tr(BuildContext context, String zh, String en, String tw) {
  final l = Localizations.of<AppLocalizations>(context, AppLocalizations) ??
      AppLocalizationsZh();
  if (l.localeName.startsWith('en')) return en;
  if (l.localeName.toLowerCase().contains('tw')) return tw;
  return zh;
}

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
      const padding = V3Layout.pageGutter;
      const spacing = 12.0;
      final contentWidth = constraints.maxWidth - padding * 2;
      final twoColumns = contentWidth >= 600;
      final cardWidth = twoColumns ? (contentWidth - spacing) / 2 : contentWidth;
      return SingleChildScrollView(
        padding: V3Layout.pageInsets,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          V3PageHeader(kicker: _tr(context, '套餐商城', 'PLAN STORE', '方案商店'),
            title: _tr(context, '选择套餐', 'Choose a plan', '選擇方案')),
          const SizedBox(height: 14),
          _CurrentPlanBadge(controller: controller),
          const SizedBox(height: 12),
          _CategoryDeck(selected: _category,
            onChanged: (value) => setState(() => _category = value)),
          const SizedBox(height: 12),
          if (plans.isEmpty)
            V3Panel(child: Column(children: [
              Text(_tr(context, '当前分类没有可购买套餐',
                  'No plans available in this category', '目前類別沒有可購買的方案')),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: controller.refreshData,
                child: Text(_tr(context, '刷新套餐', 'Refresh plans', '重新整理方案'))),
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
    final items = <(PlanCategory?, String)>[
      (null, _tr(context, '全部', 'All', '全部')),
      (PlanCategory.recurring, _tr(context, '周期', 'Recurring', '週期')),
      (PlanCategory.oneTime, _tr(context, '不限时', 'No expiry', '不限時')),
      (PlanCategory.dataPack, _tr(context, '流量包', 'Data packs', '流量包')),
    ];
    return V3Panel(tone: V3PanelTone.raised,
      padding: const EdgeInsets.all(5),
      child: Row(children: [
        for (final item in items) Expanded(child: InkWell(
          key: ValueKey('v3-plan-category-${item.$1?.name ?? 'all'}'),
          borderRadius: BorderRadius.circular(9),
          onTap: () => onChanged(item.$1),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            constraints: const BoxConstraints(minHeight: 44),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 9),
            decoration: BoxDecoration(
              color: selected == item.$1 ? p.lycheeSoft : Colors.transparent,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: selected == item.$1
                  ? p.lychee : Colors.transparent)),
            child: Text(item.$2, textAlign: TextAlign.center,
              maxLines: 1, overflow: TextOverflow.ellipsis,
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
          size: 17, color: plan.usable ? p.successInk : p.inkMuted),
        const SizedBox(width: 9),
        Expanded(child: Tooltip(message: '${plan.shortLabel} · ${plan.expiry}',
          child: Text(plan.shortLabel, maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: p.ink, fontSize: 12,
              fontWeight: FontWeight.w700)))),
        if (controller.traffic.totalGb > 0)
          Text(_tr(context,
            '剩余 ${controller.traffic.remainGb.toStringAsFixed(1)} GB',
            '${controller.traffic.remainGb.toStringAsFixed(1)} GB remaining',
            '剩餘 ${controller.traffic.remainGb.toStringAsFixed(1)} GB'),
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
          V3StatusBadge(label: plan.featured
              ? _tr(context, '推荐', 'Recommended', '推薦')
              : _tr(context, '热门', 'Popular', '熱門'),
            color: p.lychee, compact: true),
      ]),
      const SizedBox(height: 4),
      Text(_categoryLabel(context, plan.category),
        style: TextStyle(color: p.inkMuted, fontSize: 11)),
      const SizedBox(height: 15),
      Text(plan.capacity.isEmpty
          ? _tr(context, '流量未标注', 'Traffic not specified', '未標示流量')
          : plan.capacity,
        style: TextStyle(color: p.ink, fontSize: 29, fontWeight: FontWeight.w900)),
      const SizedBox(height: 14),
      Divider(color: p.line, height: 1),
      const SizedBox(height: 12),
      if (features.isEmpty)
        Text(_tr(context, '暂无套餐说明', 'No plan description', '暫無方案說明'),
          style: TextStyle(color: p.inkMuted, fontSize: 12))
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
                ? _tr(context, '查看完整说明', 'Full description', '查看完整說明')
                : _tr(context, '套餐详情', 'Plan details', '方案詳情'),
              style: TextStyle(color: p.lycheeInk, fontSize: 12,
                fontWeight: FontWeight.w700)))),
      ],
    ]);
    final purchase = Column(crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Divider(color: p.line, height: 1),
        const SizedBox(height: 11),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(child: Text(price == null
              ? _tr(context, '价格未配置', 'Price unavailable', '價格未設定')
              : '$currencySymbol${price.toStringAsFixed(2)}',
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(color: p.ink, fontSize: price == null ? 14 : 24,
              fontWeight: FontWeight.w900))),
          Text(plan.category == PlanCategory.recurring
              ? _cycleLabel(context, cycle)
              : _tr(context, '一次性', 'One-time', '一次性'),
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
            child: Text(plan.soldOut
                ? _tr(context, '已售罄', 'Sold out', '已售罄')
                : _tr(context, '选择套餐', 'Choose plan', '選擇方案')))),
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
    Text('${_categoryLabel(sheetContext, plan.category)} · ${plan.capacity}',
      style: TextStyle(color: p.inkMuted, fontSize: 12)),
    const SizedBox(height: 16),
    if (plan.deviceLimit != null)
      Padding(padding: const EdgeInsets.only(bottom: 10),
        child: Text(_tr(sheetContext, '设备数量：${plan.deviceLimit}',
            'Devices: ${plan.deviceLimit}', '裝置數量：${plan.deviceLimit}'),
          style: TextStyle(color: p.ink))),
    if (plan.features.isEmpty)
      Text(_tr(sheetContext, '后台尚未配置套餐描述',
          'No plan description has been configured', '後台尚未設定方案說明'))
    else for (final feature in plan.features)
      Padding(padding: const EdgeInsets.only(bottom: 12),
        child: Text(feature,
          style: TextStyle(color: p.ink, fontSize: 13, height: 1.55))),
  ]);
});

/// Checkout has one fixed desktop footprint for all plans. On small screens or
/// with the keyboard open, only the viewport caps its size; the body scrolls.
const Key kV3PurchaseDialogBodyKey = ValueKey('v3-purchase-dialog-body');

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
        if (result == null) {
          _error = _tr(context,
            '优惠码无效或不可用于当前套餐',
            'Coupon is invalid or not applicable to this plan',
            '優惠碼無效或不適用於目前方案');
        }
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
    // Fixed-size checkout on desktop, with only viewport/keyboard safety caps.
    final availableHeight = (media.size.height - media.viewInsets.bottom -
        media.padding.top - media.padding.bottom - 24)
        .clamp(0.0, 520.0).toDouble();
    final availableWidth = (media.size.width - 24)
        .clamp(0.0, 440.0).toDouble();
    return Dialog(
      backgroundColor: p.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
              IconButton(tooltip: _tr(context, '关闭', 'Close', '關閉'),
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded)),
            ]),
            Divider(color: p.line),
            Expanded(child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 6),
                  Text(widget.plan.category == PlanCategory.recurring
                      ? _tr(context, '选择付款周期', 'Choose billing period', '選擇付款週期')
                      : _tr(context, '购买方式', 'Purchase type', '購買方式'),
                    style: TextStyle(color: p.ink, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  if (widget.plan.category != PlanCategory.recurring)
                    V3Panel(tone: V3PanelTone.raised,
                      padding: const EdgeInsets.all(12),
                      child: Text(_tr(context, '一次性购买', 'One-time purchase', '一次性購買')))
                  else Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final cycle in cycles)
                      _CycleOption(label: _cycleLabel(context, cycle),
                        price: '${widget.currencySymbol}${_price(widget.plan, cycle)!.toStringAsFixed(2)}',
                        selected: _cycle == cycle,
                        onTap: () => setState(() {
                          _cycle = cycle;
                          _couponResult = null;
                          _appliedCode = null;
                        })),
                  ]),
                  const SizedBox(height: 16),
                  Text(_tr(context, '优惠码', 'Coupon code', '優惠碼'),
                    style: TextStyle(color: p.ink, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 7),
                  Row(children: [
                    Expanded(child: TextField(controller: _couponController,
                      onChanged: (_) => setState(() => _error = null),
                      decoration: InputDecoration(hintText: _tr(context,
                        '选填优惠码', 'Coupon code (optional)', '選填優惠碼')))),
                    const SizedBox(width: 9),
                    OutlinedButton(onPressed: _checkingCoupon ? null : _verifyCoupon,
                      child: Text(_checkingCoupon
                        ? _tr(context, '验证中', 'Verifying', '驗證中')
                        : _tr(context, '验证', 'Verify', '驗證'))),
                  ]),
                  if (_activeCoupon != null) ...[
                    const SizedBox(height: 8),
                    Text(_tr(context, '优惠码已生效', 'Coupon applied', '優惠碼已生效'),
                      style: TextStyle(color: p.successInk, fontSize: 12)),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 10),
                    Text(_error!, style: TextStyle(color: p.dangerInk, fontSize: 12)),
                  ],
                  const SizedBox(height: 16),
                  V3Panel(tone: V3PanelTone.raised,
                    padding: const EdgeInsets.all(12), child: Column(children: [
                      _AmountRow(label: _tr(context, '套餐', 'Plan', '方案'),
                        value: widget.plan.title),
                      const SizedBox(height: 8),
                      _AmountRow(label: _tr(context, '付款周期', 'Billing period', '付款週期'),
                        value: widget.plan.category == PlanCategory.recurring
                          ? _cycleLabel(context, _cycle)
                          : _tr(context, '一次性', 'One-time', '一次性')),
                      const SizedBox(height: 8),
                      _AmountRow(label: _tr(context, '原价', 'Original price', '原價'),
                        value: '${widget.currencySymbol}${_originalPrice.toStringAsFixed(2)}'),
                      if (_discountCents > 0) ...[
                        const SizedBox(height: 8),
                        _AmountRow(label: _tr(context, '优惠', 'Discount', '優惠'),
                          value: '-${widget.currencySymbol}${(_discountCents / 100).toStringAsFixed(2)}'),
                      ],
                      const SizedBox(height: 9),
                      Divider(color: p.line),
                      _AmountRow(label: _tr(context, '实付金额', 'Total due', '實付金額'),
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
                onPressed: _submitting || _price(widget.plan, _cycle) == null
                  ? null : _submit,
                style: FilledButton.styleFrom(backgroundColor: p.lychee,
                  foregroundColor: Colors.white),
                child: Text(_submitting
                  ? _tr(context, '正在创建订单…', 'Creating order…', '正在建立訂單…')
                  : _tr(context, '确认并创建订单', 'Confirm and create order',
                    '確認並建立訂單')))),
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
String _cycleLabel(BuildContext context, BillingCycle cycle) => switch (cycle) {
  BillingCycle.monthly => _tr(context, '月付', 'Monthly', '月付'),
  BillingCycle.quarterly => _tr(context, '季付', 'Quarterly', '季付'),
  BillingCycle.halfYear => _tr(context, '半年', 'Half-year', '半年'),
  BillingCycle.yearly => _tr(context, '年付', 'Yearly', '年付'),
  BillingCycle.twoYears => _tr(context, '两年', 'Two years', '兩年'),
  BillingCycle.threeYears => _tr(context, '三年', 'Three years', '三年'),
};
String _categoryLabel(BuildContext context, PlanCategory category) =>
    switch (category) {
      PlanCategory.recurring => _tr(context, '周期套餐', 'Recurring plan', '週期方案'),
      PlanCategory.oneTime => _tr(context, '不限时套餐', 'No-expiry plan', '不限時方案'),
      PlanCategory.dataPack => _tr(context, '流量包', 'Data pack', '流量包'),
    };
