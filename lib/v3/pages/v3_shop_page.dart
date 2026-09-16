import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
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
    final plans = controller.plans
        .where((plan) => _category == null || plan.category == _category)
        .toList(growable: false);

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 700;
        final horizontalPadding = 24.0;

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            26,
            horizontalPadding,
            36,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              V3PageHeader(
                kicker: '套餐商城',
                title: '选择套餐',
                description: '选择适合的流量额度，确认订单时可调整付款周期。',
                trailing: compact
                    ? null
                    : V3StatusBadge(
                        label:
                            '${controller.traffic.remainGb.toStringAsFixed(1)} GB left',
                        color: V3Palette.of(context).success,
                      ),
              ),
              const SizedBox(height: 20),
              _CurrentPlanBadge(
                plan: controller.user.plan,
                hasPlan: controller.hasPlan,
                remainGb: controller.traffic.remainGb,
              ),
              const SizedBox(height: 14),
              _CategoryDeck(
                selected: _category,
                onChanged: (value) => setState(() => _category = value),
              ),
              const SizedBox(height: 14),
              if (plans.isEmpty)
                _EmptyPlans(onRefresh: controller.refreshData)
              else
                // One card per plan rather than one long box with rules through
                // it: a plan is a thing you choose between, and a stack of
                // separate cards is what "choose between" looks like.
                for (var index = 0; index < plans.length; index++)
                  Padding(
                    padding: EdgeInsets.only(
                      bottom: index == plans.length - 1 ? 0 : 12,
                    ),
                    child: V3Panel(
                      padding: const EdgeInsets.all(18),
                      child: _PlanCard(
                        plan: plans[index],
                        currencySymbol: controller.currencySymbol,
                        emphasis:
                            plans[index].featured ||
                            (index == 0 && plans.length > 1),
                        onBuy: () => _openOrder(
                          controller,
                          plans[index],
                          _defaultCycle(plans[index]),
                        ),
                      ),
                    ),
                  ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openOrder(
    AppController controller,
    PlanModel plan,
    BillingCycle cycle,
  ) async {
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.48),
      builder: (_) => _V3OrderDialog(
        plan: plan,
        initialCycle: cycle,
        api: controller.api,
        currencySymbol: controller.currencySymbol,
        onPaid: controller.refreshData,
        // The payment dialog pops itself before calling this, so the orders
        // sheet opens onto the shop rather than onto a second modal.
        onViewOrders: () => openV3Page(context, AppPage.orders),
      ),
    );
  }
}

class _CategoryDeck extends StatelessWidget {
  const _CategoryDeck({required this.selected, required this.onChanged});

  final PlanCategory? selected;
  final ValueChanged<PlanCategory?> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    const items = <(PlanCategory?, String, String)>[
      (null, '全部', '全部'),
      (PlanCategory.recurring, '周期', '周期'),
      (PlanCategory.oneTime, '不限时', '不限时'),
      (PlanCategory.dataPack, '流量包', '流量包'),
    ];

    return V3Panel(
      padding: const EdgeInsets.all(5),
      tone: V3PanelTone.raised,
      child: Row(
        children: [
          for (final item in items)
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(9),
                onTap: () => onChanged(item.$1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    // A white pill on the raised track, with the same soft
                    // shadow and lychee ink the mode rail on the connect page
                    // uses — one segmented control, one look. The black pill it
                    // replaces was the same black as the old hero panels.
                    color: selected == item.$1 ? p.surface : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                    boxShadow: selected == item.$1
                        ? [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 8,
                            ),
                          ]
                        : null,
                  ),
                  child: Column(
                    children: [
                      Text(
                        item.$2,
                        style: TextStyle(
                          color: selected == item.$1 ? p.lycheeInk : p.ink,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CurrentPlanBadge extends StatelessWidget {
  const _CurrentPlanBadge({
    required this.plan,
    required this.remainGb,
    required this.hasPlan,
  });

  final String plan;
  final bool hasPlan;
  final double remainGb;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return V3Panel(
      tone: V3PanelTone.hero,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
      child: Row(
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              color: hasPlan ? p.success : p.inkMuted,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasPlan
                      ? (plan.trim().isEmpty ? '已激活套餐' : plan.trim())
                      : '暂无套餐',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: p.ink,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '剩余 ${remainGb.toStringAsFixed(1)} GB',
                  style: TextStyle(color: p.inkMuted, fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.currencySymbol,
    required this.emphasis,
    required this.onBuy,
  });

  final PlanModel plan;
  final String currencySymbol;
  final bool emphasis;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    final cycle = _defaultCycle(plan);
    final price = _price(plan, cycle);
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 620;
        final identity = Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: emphasis ? p.citrus : p.surfaceRaised,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                emphasis ? Icons.bolt_rounded : Icons.layers_outlined,
                color: emphasis ? p.night : p.ink,
                size: 19,
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    plan.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${_categoryLabel(plan.category)}  /  ${plan.capacity}',
                    style: TextStyle(
                      color: p.inkMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
        final priceBlock = Column(
          crossAxisAlignment: compact
              ? CrossAxisAlignment.start
              : CrossAxisAlignment.end,
          children: [
            Text(
              price == null
                  ? '--'
                  : '$currencySymbol${price.toStringAsFixed(2)}',
              style: TextStyle(
                color: p.ink,
                fontSize: 19,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              plan.category == PlanCategory.recurring
                  ? _cycleLabel(cycle)
                  : '一次性付款',
              style: TextStyle(color: p.inkMuted, fontSize: 10),
            ),
          ],
        );
        final action = V3ActionButton(
          label: plan.soldOut ? '已售罄' : '选择套餐',
          secondary: !emphasis,
          icon: Icons.arrow_forward_rounded,
          onPressed: plan.soldOut || price == null ? null : onBuy,
        );
        final purchase = Row(
          mainAxisSize: MainAxisSize.min,
          children: [priceBlock, const SizedBox(width: 14), action],
        );
        final described = plan.features.isEmpty
            ? identity
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  identity,
                  const SizedBox(height: 14),
                  _PlanFeatures(features: plan.features),
                ],
              );
        return compact
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  described,
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: priceBlock),
                      const SizedBox(width: 12),
                      action,
                    ],
                  ),
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: described),
                  const SizedBox(width: 18),
                  purchase,
                ],
              );
      },
    );
  }
}

/// What the plan's own description says it includes.
///
/// The API's description was already being stripped of markup and split into
/// lines on the way into [PlanModel.features] — and then never read, so every
/// card showed a category and a byte count and nothing the panel had written
/// about the plan.
class _PlanFeatures extends StatelessWidget {
  const _PlanFeatures({required this.features});

  final List<String> features;

  /// Enough to say what the plan is without turning one card into a page.
  static const _shown = 4;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    final lines = features.take(_shown).toList(growable: false);
    final hidden = features.length - lines.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final line in lines)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      color: p.lychee,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    line,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: p.inkMuted,
                      fontSize: 11,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (hidden > 0)
          Text(
            '等 $hidden 项',
            style: TextStyle(color: p.inkMuted, fontSize: 10),
          ),
      ],
    );
  }
}

class _EmptyPlans extends StatelessWidget {
  const _EmptyPlans({required this.onRefresh});

  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return V3Panel(
      padding: const EdgeInsets.symmetric(vertical: 54),
      child: Column(
        children: [
          Icon(Icons.inventory_2_outlined, color: p.inkMuted, size: 28),
          const SizedBox(height: 12),
          Text(
            '当前分类没有可购买套餐',
            style: TextStyle(color: p.ink, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            '可以刷新服务端数据后再试。',
            style: TextStyle(color: p.inkMuted, fontSize: 11),
          ),
          const SizedBox(height: 18),
          OutlinedButton(
            onPressed: () => onRefresh(),
            child: const Text('刷新套餐'),
          ),
        ],
      ),
    );
  }
}

class _V3OrderDialog extends StatefulWidget {
  const _V3OrderDialog({
    required this.plan,
    required this.initialCycle,
    required this.api,
    required this.currencySymbol,
    required this.onPaid,
    required this.onViewOrders,
  });

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
  bool _checkingCoupon = false;

  /// The code [_couponResult] was verified for. The coupon only counts while
  /// the field still holds this exact text, so the discount on screen can never
  /// belong to one code while a different one is submitted.
  String? _appliedCode;

  /// The coupon that actually applies right now, or null. Derived rather than
  /// stored: clearing it on edit alone would still leave programmatic text
  /// changes and revert-then-retype able to resurrect a stale discount.
  CouponResult? get _activeCoupon =>
      _couponResult != null && _couponController.text.trim() == _appliedCode
      ? _couponResult
      : null;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cycle = widget.initialCycle;
  }

  @override
  void dispose() {
    _couponController.dispose();
    super.dispose();
  }

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

  double get _finalPrice {
    final cents = ((_originalPrice * 100).round() - _discountCents).clamp(
      0,
      1 << 31,
    );
    return cents / 100;
  }

  Future<void> _verifyCoupon() async {
    final code = _couponController.text.trim();
    if (_checkingCoupon || code.isEmpty) return;
    setState(() {
      _checkingCoupon = true;
      _error = null;
    });
    try {
      final result = await widget.api.verifyCoupon(
        code,
        int.parse(widget.plan.id),
      );
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
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final tradeNo = await widget.api.submitOrder(
        planId: int.parse(widget.plan.id),
        period: _periodKey(widget.plan, _cycle),
        // Send the code the discount was computed from, and only when that
        // discount is still the one on screen.
        couponCode: _activeCoupon == null ? null : _appliedCode,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      await showV3PaymentFlow(
        context: context,
        tradeNo: tradeNo,
        // Only a placeholder until the backend answers with the real total.
        fallbackAmount: _finalPrice,
        currencySymbol: widget.currencySymbol,
        api: widget.api,
        onPaid: widget.onPaid,
        onViewOrders: widget.onViewOrders,
      );
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = '$error';
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    final cycles = _availableCycles(widget.plan);
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: Container(
        width: 520,
        constraints: const BoxConstraints(maxHeight: 640),
        padding: const EdgeInsets.all(26),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(30),
        ),
        child: SingleChildScrollView(
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
                          'CHECKOUT',
                          style: TextStyle(
                            color: p.lycheeInk,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          widget.plan.title,
                          style: Theme.of(context).textTheme.headlineLarge,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: '关闭',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Text(
                '选择周期',
                style: TextStyle(
                  color: p.inkMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 9),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final cycle in cycles)
                    ChoiceChip(
                      label: Text(_cycleLabel(cycle)),
                      selected: _cycle == cycle,
                      side: v3ChipSide(p, selected: _cycle == cycle),
                      onSelected: (_) => setState(() {
                        _cycle = cycle;
                        _couponResult = null;
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 22),
              Text(
                '优惠码',
                style: TextStyle(
                  color: p.inkMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 9),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _couponController,
                      // Rebuild on every keystroke so the derived discount and
                      // the "已生效" note drop the moment the code no longer
                      // matches the one that was verified.
                      onChanged: (_) => setState(() => _error = null),
                      decoration: InputDecoration(
                        hintText: '可选',
                        filled: true,
                        fillColor: p.surfaceRaised,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    height: 48,
                    child: OutlinedButton(
                      onPressed: _checkingCoupon ? null : _verifyCoupon,
                      child: Text(_checkingCoupon ? '验证中' : '验证'),
                    ),
                  ),
                ],
              ),
              if (_activeCoupon != null) ...[
                const SizedBox(height: 9),
                Text(
                  '优惠码已生效',
                  style: TextStyle(
                    color: p.successInk,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  style: TextStyle(color: p.dangerInk, fontSize: 11),
                ),
              ],
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: p.surfaceRaised,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '应付金额',
                          style: TextStyle(color: p.inkMuted, fontSize: 10),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${widget.currencySymbol}${_finalPrice.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: p.ink,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    if (_discountCents > 0)
                      Text(
                        '-${widget.currencySymbol}${(_discountCents / 100).toStringAsFixed(2)}',
                        style: TextStyle(
                          color: p.successInk,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _submitting ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: p.lychee,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(_submitting ? '正在创建订单…' : '确认并创建订单'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

List<BillingCycle> _availableCycles(PlanModel plan) {
  if (plan.category != PlanCategory.recurring) {
    return const [BillingCycle.monthly];
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

BillingCycle _defaultCycle(PlanModel plan) {
  final cycles = _availableCycles(plan);
  return cycles.isEmpty ? BillingCycle.monthly : cycles.first;
}

double? _price(PlanModel plan, BillingCycle cycle) {
  if (plan.category != PlanCategory.recurring) return plan.oneTimePrice;
  return plan.priceForCycle(cycle);
}

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
