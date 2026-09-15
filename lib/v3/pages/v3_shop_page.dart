import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../app/app_controller.dart';
import '../../shared/models/api_models.dart';
import '../../shared/models/app_models.dart';
import '../../shared/services/panel_api.dart';
import '../../shared/services/url_opener.dart';
import '../theme/v3_palette.dart';

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

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 700;
        final columns = constraints.maxWidth >= 1040 ? 3 : compact ? 1 : 2;
        final horizontalPadding = compact ? 20.0 : 34.0;
        const gap = 16.0;
        final usableWidth = constraints.maxWidth - horizontalPadding * 2;
        final cardWidth = columns == 1
            ? usableWidth
            : (usableWidth - gap * (columns - 1)) / columns;

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
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'PLAN LAB',
                          style: TextStyle(
                            color: p.accent,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2.2,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          '选择你的线路配额',
                          style: Theme.of(context).textTheme.displayLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '周期套餐、不限时套餐和流量包，都从同一套新购买流程进入。',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  if (!compact)
                    _CurrentPlanBadge(
                      plan: controller.user.plan,
                      remainGb: controller.traffic.remainGb,
                    ),
                ],
              ),
              const SizedBox(height: 26),
              _CategoryDeck(
                selected: _category,
                onChanged: (value) => setState(() => _category = value),
              ),
              if (compact) ...[
                const SizedBox(height: 14),
                _CurrentPlanBadge(
                  plan: controller.user.plan,
                  remainGb: controller.traffic.remainGb,
                ),
              ],
              const SizedBox(height: 20),
              if (plans.isEmpty)
                _EmptyPlans(onRefresh: controller.refreshData)
              else
                Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    for (var index = 0; index < plans.length; index++)
                      SizedBox(
                        width: cardWidth,
                        child: _PlanCard(
                          plan: plans[index],
                          currencySymbol: controller.currencySymbol,
                          emphasis:
                              plans[index].featured ||
                              (index == 0 && plans.length > 1),
                          onBuy: (cycle) => _openOrder(
                            controller,
                            plans[index],
                            cycle,
                          ),
                        ),
                      ),
                  ],
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
      (null, 'All', '全部'),
      (PlanCategory.recurring, 'Cycle', '周期'),
      (PlanCategory.oneTime, 'Forever', '不限时'),
      (PlanCategory.dataPack, 'Boost', '流量包'),
    ];

    return Container(
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: p.panel,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: p.border),
      ),
      child: Row(
        children: [
          for (final item in items)
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(15),
                onTap: () => onChanged(item.$1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  decoration: BoxDecoration(
                    color: selected == item.$1 ? p.rail : Colors.transparent,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Column(
                    children: [
                      Text(
                        item.$2,
                        style: TextStyle(
                          color: selected == item.$1 ? Colors.white : p.text,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.$3,
                        style: TextStyle(
                          color: selected == item.$1
                              ? Colors.white.withValues(alpha: 0.48)
                              : p.textMuted,
                          fontSize: 9,
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
  const _CurrentPlanBadge({required this.plan, required this.remainGb});

  final String plan;
  final double remainGb;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return Container(
      constraints: const BoxConstraints(minWidth: 180, maxWidth: 260),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: p.panelStrong,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(color: p.success, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  plan.trim().isEmpty ? '暂无激活套餐' : plan.trim(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: p.text,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '剩余 ${remainGb.toStringAsFixed(1)} GB',
                  style: TextStyle(color: p.textMuted, fontSize: 9),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatefulWidget {
  const _PlanCard({
    required this.plan,
    required this.currencySymbol,
    required this.emphasis,
    required this.onBuy,
  });

  final PlanModel plan;
  final String currencySymbol;
  final bool emphasis;
  final ValueChanged<BillingCycle> onBuy;

  @override
  State<_PlanCard> createState() => _PlanCardState();
}

class _PlanCardState extends State<_PlanCard> {
  late BillingCycle _cycle;

  @override
  void initState() {
    super.initState();
    _cycle = _defaultCycle(widget.plan);
  }

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    final cycles = _availableCycles(widget.plan);
    final price = _price(widget.plan, _cycle);
    final dark = widget.emphasis;
    final foreground = dark ? Colors.white : p.text;
    final muted = dark ? Colors.white.withValues(alpha: 0.5) : p.textMuted;

    return Container(
      constraints: const BoxConstraints(minHeight: 330),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: dark ? p.rail : p.panel,
        borderRadius: BorderRadius.circular(28),
        border: dark ? null : Border.all(color: p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                decoration: BoxDecoration(
                  color: dark
                      ? Colors.white.withValues(alpha: 0.1)
                      : p.panelStrong,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _categoryLabel(widget.plan.category),
                  style: TextStyle(
                    color: muted,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
              const Spacer(),
              if (widget.plan.hot || widget.emphasis)
                Icon(
                  Icons.auto_awesome_rounded,
                  size: 18,
                  color: dark ? p.cyan : p.accent,
                ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            widget.plan.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: foreground,
              fontSize: 21,
              fontWeight: FontWeight.w800,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.plan.capacity,
            style: TextStyle(
              color: dark ? p.cyan : p.accent,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 22),
          if (cycles.length > 1)
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final cycle in cycles)
                  InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => setState(() => _cycle = cycle),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: _cycle == cycle
                            ? (dark ? Colors.white : p.accentSoft)
                            : (dark
                                  ? Colors.white.withValues(alpha: 0.07)
                                  : p.panelStrong),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _cycleLabel(cycle),
                        style: TextStyle(
                          color: _cycle == cycle
                              ? (dark ? p.rail : p.accent)
                              : muted,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          const Spacer(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PRICE',
                      style: TextStyle(
                        color: muted,
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      price == null
                          ? '--'
                          : '${widget.currencySymbol}${price.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: foreground,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.7,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 46,
                child: FilledButton.icon(
                  onPressed: widget.plan.soldOut || price == null
                      ? null
                      : () => widget.onBuy(_cycle),
                  style: FilledButton.styleFrom(
                    backgroundColor: dark ? Colors.white : p.accent,
                    foregroundColor: dark ? p.rail : Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  icon: const Icon(Icons.arrow_outward_rounded, size: 17),
                  label: Text(
                    widget.plan.soldOut ? '售罄' : '选择',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyPlans extends StatelessWidget {
  const _EmptyPlans({required this.onRefresh});

  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 54),
      decoration: BoxDecoration(
        color: p.panel,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: p.border),
      ),
      child: Column(
        children: [
          Icon(Icons.inventory_2_outlined, color: p.textMuted, size: 28),
          const SizedBox(height: 12),
          Text(
            '当前分类没有可购买套餐',
            style: TextStyle(color: p.text, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            '可以刷新服务端数据后再试。',
            style: TextStyle(color: p.textMuted, fontSize: 11),
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
  });

  final PlanModel plan;
  final BillingCycle initialCycle;
  final PanelApi api;
  final String currencySymbol;
  final Future<void> Function() onPaid;

  @override
  State<_V3OrderDialog> createState() => _V3OrderDialogState();
}

class _V3OrderDialogState extends State<_V3OrderDialog> {
  late BillingCycle _cycle;
  final _couponController = TextEditingController();
  CouponResult? _couponResult;
  bool _checkingCoupon = false;
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
    final coupon = _couponResult;
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
        couponCode: _couponResult == null
            ? null
            : _couponController.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      await showDialog<void>(
        context: context,
        barrierColor: Colors.black.withValues(alpha: 0.52),
        builder: (_) => _V3PaymentDialog(
          tradeNo: tradeNo,
          finalPrice: _finalPrice,
          currencySymbol: widget.currencySymbol,
          api: widget.api,
          onPaid: widget.onPaid,
        ),
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
          color: p.panel,
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
                            color: p.accent,
                            fontSize: 9,
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
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Text(
                '选择周期',
                style: TextStyle(
                  color: p.textMuted,
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
                  color: p.textMuted,
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
                      decoration: InputDecoration(
                        hintText: '可选',
                        filled: true,
                        fillColor: p.panelStrong,
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
              if (_couponResult != null) ...[
                const SizedBox(height: 9),
                Text(
                  '优惠码已生效',
                  style: TextStyle(
                    color: p.success,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  style: TextStyle(color: p.danger, fontSize: 11),
                ),
              ],
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: p.panelStrong,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '应付金额',
                          style: TextStyle(color: p.textMuted, fontSize: 10),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${widget.currencySymbol}${_finalPrice.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: p.text,
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
                          color: p.success,
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
                    backgroundColor: p.accent,
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

class _V3PaymentDialog extends StatefulWidget {
  const _V3PaymentDialog({
    required this.tradeNo,
    required this.finalPrice,
    required this.currencySymbol,
    required this.api,
    required this.onPaid,
  });

  final String tradeNo;
  final double finalPrice;
  final String currencySymbol;
  final PanelApi api;
  final Future<void> Function() onPaid;

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
  String? _paymentUrl;
  int _paymentType = 0;
  String? _error;
  bool _paid = false;

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
      if (mounted) {
        setState(() {
          _loading = false;
          _error = '$error';
        });
      }
    }
  }

  bool get _balanceOnly => _detail?.balanceOnly ?? false;

  double get _amountDue {
    final cents = _detail?.totalAmount;
    return cents == null ? widget.finalPrice : cents / 100;
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
      if (mounted) {
        setState(() {
          _checkingOut = false;
          _error = '$error';
        });
      }
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
        setState(() => _error = '暂未检测到支付完成，可以稍后再次检查。');
      }
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _checkingStatus = false);
    }
  }

  Future<void> _markPaid() async {
    if (_paid) return;
    _paid = true;
    await widget.onPaid();
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
          color: p.panel,
          borderRadius: BorderRadius.circular(30),
        ),
        child: _paid
            ? _PaidView(onClose: () => Navigator.of(context).pop())
            : SingleChildScrollView(
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
                                'PAYMENT',
                                style: TextStyle(
                                  color: p.accent,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 2,
                                ),
                              ),
                              const SizedBox(height: 7),
                              Text(
                                '完成支付',
                                style: Theme.of(context).textTheme.headlineLarge,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '订单 ${widget.tradeNo}',
                      style: TextStyle(color: p.textMuted, fontSize: 10),
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
                          color: p.rail,
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: Row(
                          children: [
                            Text(
                              '需支付',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.5),
                                fontSize: 10,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${widget.currencySymbol}${_amountDue.toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: Colors.white,
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
                          '支付方式',
                          style: TextStyle(
                            color: p.textMuted,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 10),
                        if (_methods.isEmpty)
                          Text(
                            '当前没有可用支付方式',
                            style: TextStyle(color: p.danger, fontSize: 11),
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
                                  onSelected: (_) => setState(
                                    () => _selectedMethodId = method.id,
                                  ),
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
                            _paymentType == 1
                                ? '支付页面已尝试在浏览器打开'
                                : '请使用对应支付应用扫码',
                            style: TextStyle(
                              color: p.textMuted,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        if (_paymentType == 1)
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () => UrlOpener.open(_paymentUrl!),
                              icon: const Icon(
                                Icons.open_in_new_rounded,
                                size: 17,
                              ),
                              label: const Text('重新打开支付页面'),
                            ),
                          ),
                        const SizedBox(height: 10),
                      ],
                      if (_error != null) ...[
                        Text(
                          _error!,
                          style: TextStyle(color: p.danger, fontSize: 11),
                        ),
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
                            backgroundColor: p.accent,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(
                            _paymentUrl == null
                                ? (_checkingOut
                                      ? '正在发起支付…'
                                      : _balanceOnly
                                      ? '使用余额完成订单'
                                      : '继续支付')
                                : (_checkingStatus ? '正在检查…' : '我已完成支付'),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}

class _PaidView extends StatelessWidget {
  const _PaidView({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
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
        Text('支付完成', style: Theme.of(context).textTheme.headlineLarge),
        const SizedBox(height: 8),
        Text(
          '套餐数据正在同步到 Litchi。',
          style: TextStyle(color: p.textMuted, fontSize: 11),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: FilledButton(onPressed: onClose, child: const Text('完成')),
        ),
      ],
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
  PlanCategory.recurring => 'RECURRING',
  PlanCategory.oneTime => 'LIFETIME',
  PlanCategory.dataPack => 'DATA BOOST',
};
