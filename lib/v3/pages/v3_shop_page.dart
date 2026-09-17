import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../shared/models/api_models.dart';
import '../../shared/models/app_models.dart';
import '../../shared/services/panel_api.dart';
import '../commerce/v3_payment_flow.dart';
import '../theme/v3_palette.dart';
import '../ui/v3_components.dart';
import '../ui/v3_sheet.dart';

/// Independent, responsive product cards. The purchase flow remains backed by
/// the same order and payment APIs; this page only changes their presentation.
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
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const V3PageHeader(kicker: '套餐商城', title: '选择套餐'),
          const SizedBox(height: 16),
          if (controller.hasPlan)
            V3Panel(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(Icons.check_circle_rounded, size: 17, color: p.successInk),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${controller.user.plan.isEmpty ? '已激活套餐' : controller.user.plan} · 剩余 ${controller.traffic.remainGb.toStringAsFixed(1)} GB',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: p.ink, fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          if (controller.hasPlan) const SizedBox(height: 14),
          _CategoryTabs(
            selected: _category,
            onSelected: (value) => setState(() => _category = value),
          ),
          const SizedBox(height: 16),
          if (plans.isEmpty)
            V3Panel(
              child: Column(
                children: [
                  const Text('当前分类暂无可购买套餐'),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () => controller.refreshData(),
                    child: const Text('刷新套餐'),
                  ),
                ],
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                // 900px window: ~618px remains after the rail and page padding.
                // 303px cards fit with a 12px gutter; below 610px use one column.
                final twoColumns = constraints.maxWidth >= 610;
                final width = twoColumns
                    ? (constraints.maxWidth - 12) / 2
                    : constraints.maxWidth;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final plan in plans)
                      SizedBox(
                        width: width,
                        child: _ProductCard(
                          plan: plan,
                          currencySymbol: controller.currencySymbol,
                          onBuy: () => _openOrder(controller, plan),
                        ),
                      ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Future<void> _openOrder(AppController controller, PlanModel plan) async {
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.48),
      builder: (_) => _OrderDialog(
        plan: plan,
        api: controller.api,
        currencySymbol: controller.currencySymbol,
        onPaid: controller.refreshData,
        onViewOrders: () => openV3Page(context, AppPage.orders),
      ),
    );
  }
}

class _CategoryTabs extends StatelessWidget {
  const _CategoryTabs({required this.selected, required this.onSelected});

  final PlanCategory? selected;
  final ValueChanged<PlanCategory?> onSelected;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    const tabs = <(PlanCategory?, String)>[
      (null, '全部'),
      (PlanCategory.recurring, '周期'),
      (PlanCategory.oneTime, '不限时'),
      (PlanCategory.dataPack, '流量包'),
    ];
    return V3Panel(
      tone: V3PanelTone.raised,
      padding: const EdgeInsets.all(5),
      child: Row(
        children: [
          for (final tab in tabs)
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => onSelected(tab.$1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  decoration: BoxDecoration(
                    color: selected == tab.$1 ? p.surface : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: selected == tab.$1 ? p.line : Colors.transparent,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    tab.$2,
                    style: TextStyle(
                      color: selected == tab.$1 ? p.lycheeInk : p.inkMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.plan,
    required this.currencySymbol,
    required this.onBuy,
  });

  final PlanModel plan;
  final String currencySymbol;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    final cycles = _cycles(plan);
    final price = cycles.isEmpty ? null : _price(plan, cycles.first);
    final featured = plan.featured || plan.hot;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: featured ? p.lychee : p.line, width: featured ? 1.5 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  plan.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: p.ink, fontSize: 17, fontWeight: FontWeight.w800),
                ),
              ),
              if (featured) ...[
                const SizedBox(width: 6),
                V3StatusBadge(label: '推荐', color: p.lycheeInk, compact: true),
              ],
            ],
          ),
          const SizedBox(height: 5),
          Text(_categoryName(plan.category), style: TextStyle(color: p.inkMuted, fontSize: 12)),
          const SizedBox(height: 15),
          Text(
            plan.capacity.isEmpty ? '流量以套餐说明为准' : plan.capacity,
            style: TextStyle(color: p.ink, fontSize: 27, fontWeight: FontWeight.w900),
          ),
          Text('套餐流量', style: TextStyle(color: p.inkMuted, fontSize: 12)),
          const SizedBox(height: 14),
          Divider(height: 1, color: p.line),
          const SizedBox(height: 13),
          if (plan.features.isEmpty)
            Text('套餐详情以购买页面和服务端说明为准', style: TextStyle(color: p.inkMuted, fontSize: 12))
          else ...[
            for (final feature in plan.features.take(3))
              Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.check_rounded, size: 15, color: p.successInk),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        feature,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: p.ink, fontSize: 12, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            TextButton.icon(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => AlertDialog(
                  title: Text(plan.title),
                  content: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: SingleChildScrollView(
                      child: SelectableText(plan.features.join('\n\n')),
                    ),
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('关闭')),
                  ],
                ),
              ),
              icon: const Icon(Icons.arrow_forward_rounded, size: 15),
              label: const Text('查看套餐说明'),
            ),
          ],
          const SizedBox(height: 12),
          Divider(height: 1, color: p.line),
          const SizedBox(height: 12),
          Text(
            price == null ? '暂无报价' : '$currencySymbol${price.toStringAsFixed(2)}',
            style: TextStyle(color: p.ink, fontSize: 25, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 3),
          Text(
            plan.category == PlanCategory.recurring
                ? '起 · ${cycles.isEmpty ? '周期未配置' : _cycleName(cycles.first)}，购买时可切换周期'
                : '一次性付款',
            style: TextStyle(color: p.inkMuted, fontSize: 11),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 44,
            child: FilledButton(
              onPressed: plan.soldOut || price == null ? null : onBuy,
              style: FilledButton.styleFrom(
                backgroundColor: p.lychee,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
              ),
              child: Text(plan.soldOut ? '已售罄' : '选择套餐'),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderDialog extends StatefulWidget {
  const _OrderDialog({
    required this.plan,
    required this.api,
    required this.currencySymbol,
    required this.onPaid,
    required this.onViewOrders,
  });

  final PlanModel plan;
  final PanelApi api;
  final String currencySymbol;
  final Future<void> Function() onPaid;
  final VoidCallback onViewOrders;

  @override
  State<_OrderDialog> createState() => _OrderDialogState();
}

class _OrderDialogState extends State<_OrderDialog> {
  late BillingCycle _cycle;
  final _code = TextEditingController();
  CouponResult? _verified;
  String? _verifiedCode;
  String? _error;
  bool _checking = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final cycles = _cycles(widget.plan);
    _cycle = cycles.isEmpty ? BillingCycle.monthly : cycles.first;
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  CouponResult? get _coupon =>
      _verified != null && _verifiedCode == _code.text.trim() ? _verified : null;
  double get _original => _price(widget.plan, _cycle) ?? 0;
  int get _discount {
    final coupon = _coupon;
    if (coupon == null) return 0;
    if (coupon.type == 1) return coupon.value;
    if (coupon.type == 2) return ((_original * 100) * coupon.value / 100).round();
    return 0;
  }
  double get _total => (((_original * 100).round() - _discount).clamp(0, 1 << 31)) / 100;

  Future<void> _verify() async {
    final code = _code.text.trim();
    if (_checking || code.isEmpty) return;
    setState(() { _checking = true; _error = null; _verified = null; _verifiedCode = null; });
    try {
      final result = await widget.api.verifyCoupon(code, int.parse(widget.plan.id));
      if (!mounted) return;
      setState(() {
        // Ignore replies to requests whose input has changed in the meantime.
        if (_code.text.trim() == code) { _verified = result; _verifiedCode = result == null ? null : code; }
        if (result == null) _error = '优惠码无效或不可用于当前套餐';
      });
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() { _submitting = true; _error = null; });
    try {
      final tradeNo = await widget.api.submitOrder(
        planId: int.parse(widget.plan.id),
        period: _period(widget.plan, _cycle),
        couponCode: _coupon == null ? null : _verifiedCode,
      );
      if (!mounted) return;
      final estimatedTotal = _total;
      Navigator.of(context).pop();
      await showV3PaymentFlow(
        context: context,
        tradeNo: tradeNo,
        fallbackAmount: estimatedTotal,
        currencySymbol: widget.currencySymbol,
        api: widget.api,
        onPaid: widget.onPaid,
        onViewOrders: widget.onViewOrders,
      );
    } catch (error) {
      if (mounted) setState(() { _error = '$error'; _submitting = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    final cycles = _cycles(widget.plan);
    return Dialog(
      backgroundColor: p.surface,
      insetPadding: const EdgeInsets.all(18),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 510, maxHeight: 610),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                Expanded(child: Text(widget.plan.title, style: Theme.of(context).textTheme.headlineLarge)),
                IconButton(tooltip: '关闭', onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close_rounded)),
              ]),
              const SizedBox(height: 8),
              Text('选择付款周期', style: TextStyle(color: p.ink, fontSize: 13, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              if (widget.plan.category != PlanCategory.recurring)
                Text('一次性付款', style: TextStyle(color: p.inkMuted, fontSize: 13))
              else
                LayoutBuilder(builder: (context, constraints) {
                  final width = (constraints.maxWidth - 8) / 2;
                  return Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final cycle in cycles)
                      SizedBox(width: width, child: InkWell(
                        onTap: () => setState(() { _cycle = cycle; _verified = null; _verifiedCode = null; }),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          decoration: BoxDecoration(
                            color: _cycle == cycle ? p.lycheeSoft : p.surfaceRaised,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _cycle == cycle ? p.lycheeInk : p.line, width: _cycle == cycle ? 1.5 : 1),
                          ),
                          child: Row(children: [
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(_cycleName(cycle), style: TextStyle(color: _cycle == cycle ? p.lycheeInk : p.ink, fontSize: 13, fontWeight: FontWeight.w800)),
                              const SizedBox(height: 3),
                              Text('${widget.currencySymbol}${_price(widget.plan, cycle)!.toStringAsFixed(2)}', style: TextStyle(color: p.ink, fontSize: 12)),
                            ])),
                            if (_cycle == cycle) Icon(Icons.check_circle_rounded, size: 17, color: p.lycheeInk),
                          ]),
                        ),
                      )),
                  ]);
                }),
              const SizedBox(height: 20),
              Text('优惠码', style: TextStyle(color: p.ink, fontSize: 13, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: TextField(
                  controller: _code,
                  onChanged: (_) => setState(() { _verified = null; _verifiedCode = null; _error = null; }),
                  decoration: const InputDecoration(hintText: '可选'),
                )),
                const SizedBox(width: 8),
                OutlinedButton(onPressed: _checking ? null : _verify, child: Text(_checking ? '验证中' : '验证')),
              ]),
              if (_coupon != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text('优惠码已生效', style: TextStyle(color: p.successInk, fontSize: 12))),
              if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: TextStyle(color: p.dangerInk, fontSize: 12))),
              const SizedBox(height: 20),
              V3Panel(tone: V3PanelTone.raised, padding: const EdgeInsets.all(15), child: Column(children: [
                _TotalLine(label: '所选周期', value: widget.plan.category == PlanCategory.recurring ? _cycleName(_cycle) : '一次性'),
                const SizedBox(height: 9),
                _TotalLine(label: '原价', value: '${widget.currencySymbol}${_original.toStringAsFixed(2)}'),
                if (_discount > 0) ...[const SizedBox(height: 9), _TotalLine(label: '优惠', value: '-${widget.currencySymbol}${(_discount / 100).toStringAsFixed(2)}')],
                const SizedBox(height: 10),
                Divider(height: 1, color: p.line),
                const SizedBox(height: 10),
                _TotalLine(label: '预计实付', value: '${widget.currencySymbol}${_total.toStringAsFixed(2)}', emphasized: true),
              ])),
              const SizedBox(height: 15),
              SizedBox(height: 48, child: FilledButton(
                onPressed: _submitting || cycles.isEmpty ? null : _submit,
                style: FilledButton.styleFrom(backgroundColor: p.lychee, foregroundColor: Colors.white),
                child: Text(_submitting ? '正在创建订单…' : '确认并创建订单'),
              )),
              const SizedBox(height: 7),
              Text('最终支付金额以服务端创建的订单为准', textAlign: TextAlign.center, style: TextStyle(color: p.inkMuted, fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }
}

class _TotalLine extends StatelessWidget {
  const _TotalLine({required this.label, required this.value, this.emphasized = false});
  final String label;
  final String value;
  final bool emphasized;
  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return Row(children: [
      Text(label, style: TextStyle(color: p.inkMuted, fontSize: 12)),
      const Spacer(),
      Text(value, style: TextStyle(color: p.ink, fontSize: emphasized ? 21 : 12, fontWeight: FontWeight.w800)),
    ]);
  }
}

List<BillingCycle> _cycles(PlanModel plan) {
  if (plan.category != PlanCategory.recurring) return plan.oneTimePrice == null ? [] : [BillingCycle.monthly];
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
    plan.category == PlanCategory.recurring ? plan.priceForCycle(cycle) : plan.oneTimePrice;

String _period(PlanModel plan, BillingCycle cycle) {
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

String _cycleName(BillingCycle cycle) => switch (cycle) {
  BillingCycle.monthly => '月付',
  BillingCycle.quarterly => '季付',
  BillingCycle.halfYear => '半年',
  BillingCycle.yearly => '年付',
  BillingCycle.twoYears => '两年',
  BillingCycle.threeYears => '三年',
};

String _categoryName(PlanCategory category) => switch (category) {
  PlanCategory.recurring => '周期套餐',
  PlanCategory.oneTime => '不限时套餐',
  PlanCategory.dataPack => '流量包',
};
