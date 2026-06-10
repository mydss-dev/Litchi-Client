import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/app_controller.dart';
import '../../shared/models/app_models.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_palette.dart';
import '../../shared/theme/app_radius.dart';
import '../../shared/theme/app_text_styles.dart';
import '../../shared/widgets/app_badge.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/filter_tabs.dart';
import '../../shared/widgets/page_header.dart';
import 'order_confirm_dialog.dart';

/// Shop page (§12). Three product categories agreed with the user:
/// 周期套餐 (with month/quarter/year toggle) / 一次性套餐 / 流量包.
class ShopPage extends StatefulWidget {
  const ShopPage({super.key});

  @override
  State<ShopPage> createState() => _ShopPageState();
}

class _ShopPageState extends State<ShopPage> {
  static const _categoryTabs = ['周期套餐', '一次性套餐', '流量包'];
  int _categoryIndex = 0;
  BillingCycle _cycle = BillingCycle.monthly;

  PlanCategory get _category => switch (_categoryIndex) {
        0 => PlanCategory.recurring,
        1 => PlanCategory.oneTime,
        _ => PlanCategory.dataPack,
      };

  List<PlanModel> _plans(BuildContext context) =>
      AppScope.of(context).plans.where((p) => p.category == _category).toList();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHeader(title: '商城', subtitle: '选择更适合你的流量套餐和订阅周期'),
          const SizedBox(height: 12),
          FilterTabs(
            tabs: _categoryTabs,
            selectedIndex: _categoryIndex,
            onSelected: (i) => setState(() => _categoryIndex = i),
          ),
          // The billing-cycle toggle only applies to recurring plans.
          if (_category == PlanCategory.recurring) ...[
            const SizedBox(height: 14),
            _CycleSelector(
              cycle: _cycle,
              onChanged: (v) => setState(() => _cycle = v),
            ),
          ],
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              // 560 (not the spec's 680) so the 2-column default (§27.16)
              // triggers at the real ~675px content width.
              final cols = constraints.maxWidth >= 560 ? 2 : 1;
              final plans = _plans(context);
              return GridView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: plans.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cols,
                  mainAxisSpacing: 18,
                  crossAxisSpacing: 18,
                  mainAxisExtent: 400,
                ),
                itemBuilder: (context, i) =>
                    _PlanCard(plan: plans[i], cycle: _cycle),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Segmented month / quarter / year selector (§12 billing selector).
class _CycleSelector extends StatelessWidget {
  const _CycleSelector({required this.cycle, required this.onChanged});

  final BillingCycle cycle;
  final ValueChanged<BillingCycle> onChanged;

  static const _labels = {
    BillingCycle.monthly: '月付',
    BillingCycle.quarterly: '季付',
    BillingCycle.yearly: '年付',
  };

  // Savings hints vs. monthly, shown on the longer cycles.
  static const _savings = {
    BillingCycle.quarterly: '省 10%',
    BillingCycle.yearly: '省 20%',
  };

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: c.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final entry in _labels.entries)
            _CycleChip(
              label: entry.value,
              savings: _savings[entry.key],
              selected: cycle == entry.key,
              onTap: () => onChanged(entry.key),
            ),
        ],
      ),
    );
  }
}

class _CycleChip extends StatelessWidget {
  const _CycleChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.savings,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final String? savings;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? c.cardBg : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            boxShadow: selected
                ? [BoxShadow(color: c.shadow, blurRadius: 8, offset: const Offset(0, 2))]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label,
                  style: AppTextStyles.menu.copyWith(
                    color: selected ? c.primary : c.textSecondary,
                  )),
              if (savings != null) ...[
                const SizedBox(width: 6),
                Text(savings!,
                    style: AppTextStyles.badge.copyWith(color: c.success, fontSize: 9)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.plan, required this.cycle});

  final PlanModel plan;
  final BillingCycle cycle;

  String get _priceLabel {
    final price = plan.category == PlanCategory.recurring
        ? plan.priceForCycle(cycle)
        : plan.oneTimePrice;
    return price == null ? '--' : price.toStringAsFixed(0);
  }

  String get _unitLabel {
    if (plan.category != PlanCategory.recurring) return '一次性';
    return switch (cycle) {
      BillingCycle.monthly => '/ 月',
      BillingCycle.quarterly => '/ 季',
      BillingCycle.yearly => '/ 年',
    };
  }

  IconData get _icon => switch (plan.category) {
        PlanCategory.recurring => LucideIcons.zap,
        PlanCategory.oneTime => LucideIcons.box,
        PlanCategory.dataPack => LucideIcons.plus,
      };

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final featured = plan.featured;

    return AppCard(
      radius: AppRadius.lg,
      padding: const EdgeInsets.all(18),
      border: !featured,
      color: featured ? null : c.cardBg,
      child: Container(
        decoration: featured
            ? BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.lg - 1),
                border: Border.all(color: c.primary, width: 1.5),
              )
            : null,
        padding: featured ? const EdgeInsets.all(2) : EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: c.primarySoft,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Icon(_icon, size: 18, color: c.primary),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(plan.title,
                          style: AppTextStyles.bodyStrong.copyWith(color: c.textPrimary)),
                      Text(plan.capacity,
                          style: AppTextStyles.caption.copyWith(color: c.textMuted)),
                    ],
                  ),
                ),
                if (plan.hot)
                  AppBadge(
                    text: '热门',
                    background: c.danger.withValues(alpha: 0.12),
                    textColor: c.danger,
                    fontSize: 10,
                    height: 20,
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text('¥',
                    style: AppTextStyles.sectionTitle.copyWith(color: c.primary)),
                Text(_priceLabel,
                    style: AppTextStyles.largeNumber(fontSize: 30).copyWith(color: c.primary)),
                const SizedBox(width: 6),
                Text(_unitLabel,
                    style: AppTextStyles.caption.copyWith(color: c.textMuted)),
              ],
            ),
            const SizedBox(height: 16),
            for (final f in plan.features) ...[
              Row(
                children: [
                  Icon(LucideIcons.check, size: 15, color: c.success),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(f,
                        style: AppTextStyles.body.copyWith(color: c.textSecondary)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
            const Spacer(),
            _BuyButton(plan: plan, cycle: cycle, featured: featured),
          ],
        ),
      ),
    );
  }
}

class _BuyButton extends StatelessWidget {
  const _BuyButton({
    required this.plan,
    required this.cycle,
    required this.featured,
  });

  final PlanModel plan;
  final BillingCycle cycle;
  final bool featured;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final ctrl = AppScope.of(context);
    return SizedBox(
      width: double.infinity,
      height: 42,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => showOrderConfirmDialog(
            context: context,
            plan: plan,
            cycle: cycle,
            api: ctrl.api,
          ),
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Ink(
            decoration: BoxDecoration(
              gradient: featured ? AppPalette.brandGradient : null,
              color: featured ? null : c.primary,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Center(
              child: Text('立即购买',
                  style: AppTextStyles.button.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  )),
            ),
          ),
        ),
      ),
    );
  }
}
