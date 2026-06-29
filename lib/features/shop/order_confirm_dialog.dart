import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../shared/models/api_models.dart';
import '../../shared/models/app_models.dart';
import '../../shared/services/panel_api.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_palette.dart';
import '../../shared/theme/app_radius.dart';
import '../../shared/theme/app_text_styles.dart';
import '../../shared/widgets/app_bottom_sheet.dart';
import '../../shared/widgets/app_modal.dart';
import '../../shared/widgets/app_toast.dart';
import '../../shared/widgets/icon_action_btn.dart';
import 'payment_dialog.dart';

// ── helpers ───────────────────────────────────────────────────────────────────

/// Maps BillingCycle / one-time to the API period key.
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

const _periodLabels = {
  'month_price': '月付',
  'quarter_price': '季付',
  'half_year_price': '半年付',
  'year_price': '年付',
  'two_year_price': '两年付',
  'three_year_price': '三年付',
  'onetime_price': '一次性',
};

// ── public entry-point ────────────────────────────────────────────────────────

Future<void> showOrderConfirmDialog({
  required BuildContext context,
  required PlanModel plan,
  required BillingCycle cycle,
  required PanelApi api,
}) {
  return showAppAdaptiveModal<void>(
    context: context,
    builder: (_, compact) => _OrderConfirmDialog(
      plan: plan,
      cycle: cycle,
      api: api,
      compact: compact,
    ),
  );
}

// ── Order confirm dialog ──────────────────────────────────────────────────────

class _OrderConfirmDialog extends StatefulWidget {
  const _OrderConfirmDialog({
    required this.plan,
    required this.cycle,
    required this.api,
    required this.compact,
  });

  final PlanModel plan;
  final BillingCycle cycle;
  final PanelApi api;
  final bool compact;

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

  // ── derived prices ────────────────────────────────────────────────────────

  List<MapEntry<String, double>> get _availablePeriods {
    final entries = <MapEntry<String, double>>[];
    void add(String key, double? price) {
      if (price != null) {
        entries.add(MapEntry(key, price));
      }
    }

    add('month_price', widget.plan.monthlyPrice);
    add('quarter_price', widget.plan.quarterlyPrice);
    add('half_year_price', widget.plan.halfYearPrice);
    add('year_price', widget.plan.yearlyPrice);
    add('onetime_price', widget.plan.oneTimePrice);
    return entries;
  }

  double get _originalPrice {
    for (final e in _availablePeriods) {
      if (e.key == _period) return e.value;
    }
    return 0;
  }

  int get _originalCents => (_originalPrice * 100).round();

  int get _discountCents {
    if (!_couponApplied || _coupon == null) {
      return 0;
    }
    if (_coupon!.type == 1) {
      return _coupon!.value;
    }
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
    final sym = await widget.api.getCommCurrencySymbol();
    if (mounted) setState(() => _currencySymbol = sym);
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
        AppToast.show(context, '优惠码已生效', type: AppToastType.success);
      } else {
        AppToast.show(context, '优惠码无效', type: AppToastType.error);
      }
    } catch (e) {
      if (mounted) AppToast.show(context, '验证失败：$e', type: AppToastType.error);
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
      );
    } catch (e) {
      if (mounted) AppToast.show(context, '提交失败：$e', type: AppToastType.error);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    if (widget.compact) {
      return AppBottomSheet(
        title: '确认订单',
        subtitle: widget.plan.title,
        maxHeightFactor: 0.92,
        children: [_buildContent(c)],
      );
    }
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 580,
          constraints: const BoxConstraints(maxHeight: 560),
          decoration: BoxDecoration(
            color: c.cardBg,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(color: c.softBorder),
            boxShadow: [
              BoxShadow(
                color: c.shadow,
                blurRadius: 32,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(c),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
                  child: _buildContent(c),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(AppColors c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildPeriodSelector(c),
        const SizedBox(height: 20),
        _buildCouponRow(c),
        const SizedBox(height: 20),
        _buildSummary(c),
        const SizedBox(height: 24),
        _buildActions(c),
      ],
    );
  }

  Widget _buildHeader(AppColors c) {
    return Container(
      padding: const EdgeInsets.fromLTRB(28, 24, 20, 20),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.softBorder)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '确认订单',
                  style: AppTextStyles.pageTitle.copyWith(color: c.textPrimary),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.plan.title,
                  style: AppTextStyles.body.copyWith(color: c.textSecondary),
                ),
              ],
            ),
          ),
          IconActionBtn(
            icon: LucideIcons.x,
            onTap: () => Navigator.of(context).pop(),
            c: c,
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector(AppColors c) {
    final periods = _availablePeriods;
    if (periods.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 4),
        Text(
          '选择周期',
          style: AppTextStyles.sectionTitle.copyWith(color: c.textPrimary),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: periods.map((e) {
            final selected = _period == e.key;
            return GestureDetector(
              onTap: () => setState(() {
                _period = e.key;
                _couponApplied = false;
                _coupon = null;
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: selected ? c.primarySoft : c.surfaceMuted,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(
                    color: selected ? c.primary : c.border,
                    width: selected ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _periodLabels[e.key] ?? e.key,
                      style: AppTextStyles.bodyStrong.copyWith(
                        color: selected ? c.primary : c.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$_currencySymbol${e.value.toStringAsFixed(2)}',
                      style: AppTextStyles.body.copyWith(
                        color: selected ? c.primary : c.textMuted,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildCouponRow(AppColors c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '优惠码',
          style: AppTextStyles.sectionTitle.copyWith(color: c.textPrimary),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Container(
                height: 42,
                decoration: BoxDecoration(
                  color: _couponApplied
                      ? c.success.withValues(alpha: 0.08)
                      : c.surfaceMuted,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                    color: _couponApplied ? c.success : c.border,
                  ),
                ),
                child: TextField(
                  controller: _couponCtrl,
                  enabled: !_couponApplied,
                  style: AppTextStyles.body.copyWith(color: c.textPrimary),
                  decoration: InputDecoration(
                    hintText: '输入优惠码（可选）',
                    hintStyle: AppTextStyles.body.copyWith(color: c.textMuted),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            if (_couponApplied)
              _SmallBtn(
                label: '移除',
                color: c.danger,
                onTap: _removeCoupon,
                c: c,
              )
            else
              _SmallBtn(
                label: _verifying ? '验证中…' : '验证',
                color: c.primary,
                onTap: _verifying ? null : _verifyCoupon,
                c: c,
              ),
          ],
        ),
        if (_couponApplied && _coupon != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(LucideIcons.tag, size: 13, color: c.success),
              const SizedBox(width: 6),
              Text(
                _coupon!.type == 1
                    ? '已优惠 $_currencySymbol${(_coupon!.value / 100).toStringAsFixed(2)}'
                    : '已优惠 ${_coupon!.value}%',
                style: AppTextStyles.caption.copyWith(color: c.success),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildSummary(AppColors c) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: c.softBorder),
      ),
      child: Column(
        children: [
          _SummaryRow(
            label: '套餐原价',
            value: '$_currencySymbol${_originalPrice.toStringAsFixed(2)}',
            c: c,
          ),
          if (_discountCents > 0) ...[
            const SizedBox(height: 8),
            _SummaryRow(
              label: '优惠减免',
              value:
                  '-$_currencySymbol${(_discountCents / 100).toStringAsFixed(2)}',
              valueColor: c.danger,
              c: c,
            ),
          ],
          Divider(color: c.border, height: 20),
          _SummaryRow(
            label: '应付总计',
            value: '$_currencySymbol${_finalPrice.toStringAsFixed(2)}',
            valueStyle: AppTextStyles.largeNumber(
              fontSize: 20,
            ).copyWith(color: c.primary),
            c: c,
          ),
        ],
      ),
    );
  }

  Widget _buildActions(AppColors c) {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 44,
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: c.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
              ),
              child: Text(
                '取消',
                style: AppTextStyles.button.copyWith(color: c.textSecondary),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: SizedBox(
            height: 44,
            child: ElevatedButton(
              onPressed: _submitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
              ),
              child: Ink(
                decoration: BoxDecoration(
                  gradient: AppPalette.brandGradient,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Center(
                  child: _submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          '提交订单',
                          style: AppTextStyles.button.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── small helper widgets ──────────────────────────────────────────────────────

class _SmallBtn extends StatelessWidget {
  const _SmallBtn({
    required this.label,
    required this.color,
    required this.onTap,
    required this.c,
  });
  final String label;
  final Color color;
  final VoidCallback? onTap;
  final AppColors c;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: AppTextStyles.bodyStrong.copyWith(color: color),
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    required this.c,
    this.valueColor,
    this.valueStyle,
  });
  final String label;
  final String value;
  final AppColors c;
  final Color? valueColor;
  final TextStyle? valueStyle;
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTextStyles.body.copyWith(color: c.textSecondary)),
        Text(
          value,
          style:
              valueStyle ??
              AppTextStyles.bodyStrong.copyWith(
                color: valueColor ?? c.textPrimary,
              ),
        ),
      ],
    );
  }
}
