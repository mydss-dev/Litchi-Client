import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/app_controller.dart';
import '../../shared/models/app_models.dart';
import '../../shared/responsive/breakpoints.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_radius.dart';
import '../../shared/theme/app_shadows.dart';
import '../../shared/theme/app_text_styles.dart';
import '../../shared/widgets/app_toast.dart';
import '../../shared/widgets/page_header.dart';
import '../mobile/mobile_back_button.dart';
import '../mobile/mobile_page_header.dart';
import 'order_confirm_dialog.dart';

/// Shop — a single responsive page.
///
/// Two-layout merge. Wide keeps the desktop design (responsive plan-card grid);
/// compact keeps the mobile design (pull-to-refresh single-column list with the
/// child-page back header). `_tab` and `_filtered` are shared; the tab label set
/// differs slightly so the mobile one is kept as `_compactTabs`. The mobile
/// sub-widgets are kept verbatim under a `C` suffix to avoid colliding with the
/// desktop set. Split keyed on window width.
class ShopPage extends StatefulWidget {
  const ShopPage({super.key});

  @override
  State<ShopPage> createState() => _ShopPageState();
}

class _ShopPageState extends State<ShopPage> {
  static const _tabs = ['全部', '周期套餐', '一次性', '流量包'];
  static const _compactTabs = ['全部', '周期性', '一次性', '流量包'];
  int _tab = 0;

  List<PlanModel> _filtered(List<PlanModel> plans) {
    return plans.where((plan) {
      return switch (_tab) {
        1 => plan.category == PlanCategory.recurring,
        2 => plan.category == PlanCategory.oneTime,
        3 => plan.category == PlanCategory.dataPack,
        _ => true,
      };
    }).toList();
  }

  Future<void> _handlePullRefresh() async {
    final ctrl = AppScope.of(context);
    await ctrl.refreshData();
    if (!mounted || ctrl.dataLoadError != null) return;
    AppToast.show(context, '已刷新', type: AppToastType.success);
  }

  @override
  Widget build(BuildContext context) {
    return context.isCompact ? _buildCompact(context) : _buildWide(context);
  }

  // ── Wide (sidebar) layout ──────────────────────────────────────────────
  Widget _buildWide(BuildContext context) {
    final ctrl = AppScope.of(context);
    final c = AppColors.of(context);
    final plans = _filtered(ctrl.plans);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHeader(title: '购买套餐', subtitle: '选择适合你的套餐和流量包'),
          const SizedBox(height: 12),
          _ShopTabs(
            tabs: _tabs,
            selected: _tab,
            onSelected: (index) => setState(() => _tab = index),
          ),
          const SizedBox(height: 14),
          if (plans.isEmpty)
            SizedBox(
              height: 220,
              child: Center(
                child: Text(
                  '暂无套餐信息',
                  style: AppTextStyles.body.copyWith(color: c.textMuted),
                ),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final cols = constraints.maxWidth >= 980
                    ? 3
                    : constraints.maxWidth >= 620
                    ? 2
                    : 1;
                return GridView.builder(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: plans.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: cols,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    mainAxisExtent: 310,
                  ),
                  itemBuilder: (context, index) => _PlanCard(
                    key: ValueKey(plans[index].id),
                    plan: plans[index],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // ── Compact (bottom-nav) layout ────────────────────────────────────────
  Widget _buildCompact(BuildContext context) {
    final ctrl = AppScope.of(context);
    final c = AppColors.of(context);
    final plans = _filtered(ctrl.plans);
    final asChild = ctrl.mobileProfileChildPage;

    return RefreshIndicator(
      onRefresh: _handlePullRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        children: [
          if (asChild)
            Row(
              children: [
                MobileBackButton(onTap: () => ctrl.goToPage(AppPage.account)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '套餐购买',
                    style: AppTextStyles.pageTitle.copyWith(fontSize: 26),
                  ),
                ),
              ],
            )
          else
            const MobilePageHeader(title: '套餐', subtitle: '选择适合你的流量方案'),
          const SizedBox(height: 14),
          _ShopTabsC(
            tabs: _compactTabs,
            selected: _tab,
            onSelected: (index) => setState(() => _tab = index),
          ),
          const SizedBox(height: 14),
          if (plans.isEmpty)
            SizedBox(
              height: 220,
              child: Center(
                child: Text(
                  '暂无套餐信息',
                  style: AppTextStyles.body.copyWith(color: c.textMuted),
                ),
              ),
            )
          else
            for (var i = 0; i < plans.length; i++) ...[
              _PlanCardC(plan: plans[i]),
              if (i != plans.length - 1) const SizedBox(height: 12),
            ],
        ],
      ),
    );
  }
}

// ── Wide-layout widgets (original desktop ShopPage, verbatim) ─────────────

class _ShopTabs extends StatelessWidget {
  const _ShopTabs({
    required this.tabs,
    required this.selected,
    required this.onSelected,
  });

  final List<String> tabs;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: c.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Row(
        children: [
          for (var i = 0; i < tabs.length; i++)
            Expanded(
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () => onSelected(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 140),
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected == i ? c.cardBg : Colors.transparent,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      boxShadow: selected == i ? AppShadows.soft(c) : null,
                    ),
                    child: Text(
                      tabs[i],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption.copyWith(
                        color: selected == i ? c.primary : c.textMuted,
                        fontWeight: selected == i
                            ? FontWeight.w800
                            : FontWeight.w600,
                      ),
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

class _PlanCard extends StatefulWidget {
  const _PlanCard({super.key, required this.plan});

  final PlanModel plan;

  @override
  State<_PlanCard> createState() => _PlanCardState();
}

class _PlanCardState extends State<_PlanCard> {
  late BillingCycle _cycle;

  PlanModel get plan => widget.plan;

  @override
  void initState() {
    super.initState();
    final cycles = _availableCycles;
    _cycle = cycles.isEmpty ? BillingCycle.monthly : cycles.first;
  }

  @override
  void didUpdateWidget(covariant _PlanCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final cycles = _availableCycles;
    if (!cycles.contains(_cycle)) {
      _cycle = cycles.isEmpty ? BillingCycle.monthly : cycles.first;
    }
  }

  List<BillingCycle> get _cycleOptions {
    if (plan.category != PlanCategory.recurring) return const [];
    return const [
      BillingCycle.monthly,
      BillingCycle.quarterly,
      BillingCycle.halfYear,
      BillingCycle.yearly,
    ];
  }

  List<BillingCycle> get _availableCycles => _cycleOptions
      .where((cycle) => plan.priceForCycle(cycle) != null)
      .toList();

  double? get _price {
    if (plan.category == PlanCategory.recurring) {
      return plan.priceForCycle(_cycle) ??
          plan.monthlyPrice ??
          plan.quarterlyPrice ??
          plan.halfYearPrice ??
          plan.yearlyPrice;
    }
    return plan.oneTimePrice ??
        plan.monthlyPrice ??
        plan.quarterlyPrice ??
        plan.halfYearPrice ??
        plan.yearlyPrice;
  }

  String get _unit => switch (plan.category) {
    PlanCategory.recurring => _cycleUnit(_cycle),
    PlanCategory.oneTime => '/ 不限时',
    PlanCategory.dataPack => '',
  };

  String get _categoryLabel => switch (plan.category) {
    PlanCategory.recurring => '周期套餐',
    PlanCategory.oneTime => '一次性套餐',
    PlanCategory.dataPack => '流量包',
  };

  String get _metaText {
    final parts = <String>[_categoryLabel];
    final capacity = plan.capacity.trim();
    if (_hasCapacity(plan)) parts.add(capacity);
    if (plan.deviceLimit != null) {
      parts.add(plan.deviceLimit! > 0 ? '${plan.deviceLimit} 台设备' : '不限设备');
    }
    return parts.join(' · ');
  }

  IconData get _icon => switch (plan.category) {
    PlanCategory.recurring => LucideIcons.zap,
    PlanCategory.oneTime => LucideIcons.box,
    PlanCategory.dataPack => LucideIcons.plus,
  };

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final ctrl = AppScope.of(context);
    final price = _price;
    final features = plan.features.map(_cleanFeature).take(3).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.cardBg,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: plan.featured ? c.primary : c.softBorder,
          width: plan.featured ? 1.3 : 1,
        ),
        boxShadow: AppShadows.soft(c),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: c.primarySoft,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(_icon, color: c.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodyStrong.copyWith(
                        color: c.textPrimary,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _metaText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption.copyWith(color: c.textMuted),
                    ),
                  ],
                ),
              ),
              if (plan.hot)
                _MiniBadge(text: '热门', color: c.danger)
              else if (plan.featured)
                _MiniBadge(text: '推荐', color: c.primary),
            ],
          ),
          const SizedBox(height: 14),
          _PricePanel(symbol: ctrl.currencySymbol, price: price, unit: _unit),
          if (_cycleOptions.isNotEmpty) ...[
            const SizedBox(height: 12),
            _CycleSelector(
              cycles: _cycleOptions,
              enabledCycles: _availableCycles,
              selected: _cycle,
              onChanged: (cycle) => setState(() => _cycle = cycle),
            ),
          ],
          if (features.isNotEmpty) ...[
            const SizedBox(height: 12),
            _FeatureList(features: features),
          ],
          const Spacer(),
          _BuyButton(
            enabled: price != null,
            onTap: price == null
                ? null
                : () => showOrderConfirmDialog(
                    context: context,
                    plan: plan,
                    cycle: _cycle,
                    api: ctrl.api,
                  ),
          ),
        ],
      ),
    );
  }
}

class _CycleSelector extends StatelessWidget {
  const _CycleSelector({
    required this.cycles,
    required this.enabledCycles,
    required this.selected,
    required this.onChanged,
  });

  final List<BillingCycle> cycles;
  final List<BillingCycle> enabledCycles;
  final BillingCycle selected;
  final ValueChanged<BillingCycle> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var index = 0; index < cycles.length; index++) ...[
          Expanded(
            child: _CycleChip(
              cycle: cycles[index],
              enabled: enabledCycles.contains(cycles[index]),
              selected: selected == cycles[index],
              onTap: () => onChanged(cycles[index]),
            ),
          ),
          if (index != cycles.length - 1) const SizedBox(width: 6),
        ],
      ],
    );
  }
}

class _CycleChip extends StatelessWidget {
  const _CycleChip({
    required this.cycle,
    required this.enabled,
    required this.selected,
    required this.onTap,
  });

  final BillingCycle cycle;
  final bool enabled;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final fg = selected
        ? c.primary
        : enabled
        ? c.textMuted
        : c.textMuted.withValues(alpha: 0.38);
    final bg = selected
        ? c.primarySoft
        : enabled
        ? c.surfaceMuted
        : c.surfaceMuted.withValues(alpha: 0.22);
    final borderColor = selected
        ? c.primarySoft
        : enabled
        ? c.softBorder
        : c.softBorder.withValues(alpha: 0.35);
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(color: borderColor),
          ),
          child: Text(
            _cycleLabel(cycle),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.caption.copyWith(
              fontSize: 12,
              color: fg,
              fontWeight: selected
                  ? FontWeight.w800
                  : enabled
                  ? FontWeight.w600
                  : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _PricePanel extends StatelessWidget {
  const _PricePanel({
    required this.symbol,
    required this.price,
    required this.unit,
  });

  final String symbol;
  final double? price;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: Text(
              symbol,
              style: AppTextStyles.bodyStrong.copyWith(color: c.textPrimary),
            ),
          ),
          Text(
            price == null ? '--' : price!.toStringAsFixed(0),
            style: AppTextStyles.largeNumber(
              fontSize: 38,
            ).copyWith(color: c.textPrimary),
          ),
          if (unit.isNotEmpty) ...[
            const SizedBox(width: 6),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                unit,
                style: AppTextStyles.caption.copyWith(color: c.textMuted),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FeatureList extends StatelessWidget {
  const _FeatureList({required this.features});

  final List<String> features;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Column(
      children: [
        for (final feature in features) ...[
          Row(
            children: [
              Icon(LucideIcons.check, size: 15, color: c.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  feature,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(color: c.textSecondary),
                ),
              ),
            ],
          ),
          if (feature != features.last) const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _MiniBadge extends StatelessWidget {
  const _MiniBadge({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        text,
        style: AppTextStyles.badge.copyWith(color: color, fontSize: 10),
      ),
    );
  }
}

class _BuyButton extends StatelessWidget {
  const _BuyButton({required this.enabled, required this.onTap});

  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: enabled ? c.primary : c.surfaceMuted,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Text(
            enabled ? '立即购买' : '暂不可购买',
            style: AppTextStyles.button.copyWith(
              color: enabled ? Colors.white : c.textMuted,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Compact-layout widgets (original MobileShopPage, verbatim, C-suffixed) ─

class _ShopTabsC extends StatelessWidget {
  const _ShopTabsC({
    required this.tabs,
    required this.selected,
    required this.onSelected,
  });

  final List<String> tabs;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: c.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Row(
        children: [
          for (var i = 0; i < tabs.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => onSelected(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected == i ? c.cardBg : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    boxShadow: selected == i ? AppShadows.soft(c) : null,
                  ),
                  child: Text(
                    tabs[i],
                    style: AppTextStyles.caption.copyWith(
                      color: selected == i ? c.primary : c.textMuted,
                      fontWeight: selected == i
                          ? FontWeight.w800
                          : FontWeight.w600,
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

class _PlanCardC extends StatefulWidget {
  const _PlanCardC({required this.plan});

  final PlanModel plan;

  @override
  State<_PlanCardC> createState() => _PlanCardStateC();
}

class _PlanCardStateC extends State<_PlanCardC> {
  late BillingCycle _cycle;

  PlanModel get plan => widget.plan;

  @override
  void initState() {
    super.initState();
    final cycles = _availableCycles;
    _cycle = cycles.isEmpty ? BillingCycle.monthly : cycles.first;
  }

  @override
  void didUpdateWidget(covariant _PlanCardC oldWidget) {
    super.didUpdateWidget(oldWidget);
    final cycles = _availableCycles;
    if (!cycles.contains(_cycle)) {
      _cycle = cycles.isEmpty ? BillingCycle.monthly : cycles.first;
    }
  }

  List<BillingCycle> get _cycleOptions {
    if (plan.category != PlanCategory.recurring) return const [];
    return const [
      BillingCycle.monthly,
      BillingCycle.quarterly,
      BillingCycle.halfYear,
      BillingCycle.yearly,
    ];
  }

  List<BillingCycle> get _availableCycles => _cycleOptions
      .where((cycle) => plan.priceForCycle(cycle) != null)
      .toList();

  double? get _price {
    if (plan.category == PlanCategory.recurring) {
      return plan.priceForCycle(_cycle) ??
          plan.monthlyPrice ??
          plan.quarterlyPrice ??
          plan.halfYearPrice ??
          plan.yearlyPrice;
    }
    return plan.oneTimePrice ??
        plan.monthlyPrice ??
        plan.quarterlyPrice ??
        plan.halfYearPrice ??
        plan.yearlyPrice;
  }

  String get _unit => switch (plan.category) {
    PlanCategory.recurring => _cycleUnit(_cycle),
    PlanCategory.oneTime => '/ 不限时',
    PlanCategory.dataPack => '',
  };

  String get _categoryLabel => switch (plan.category) {
    PlanCategory.recurring => '周期套餐',
    PlanCategory.oneTime => '一次性套餐',
    PlanCategory.dataPack => '流量包',
  };

  String get _metaText {
    final parts = <String>[_categoryLabel];
    final capacity = plan.capacity.trim();
    if (_hasCapacity(plan)) {
      parts.add(capacity);
    }
    if (plan.deviceLimit != null) {
      parts.add(plan.deviceLimit! > 0 ? '${plan.deviceLimit} 台设备' : '不限设备');
    }
    return parts.join(' · ');
  }

  IconData get _icon => switch (plan.category) {
    PlanCategory.recurring => LucideIcons.zap,
    PlanCategory.oneTime => LucideIcons.box,
    PlanCategory.dataPack => LucideIcons.plus,
  };

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final ctrl = AppScope.of(context);
    final price = _price;
    final features = plan.features.map(_cleanFeature).take(4).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.cardBg,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: plan.featured ? c.primary : c.softBorder,
          width: plan.featured ? 1.3 : 1,
        ),
        boxShadow: AppShadows.soft(c),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: c.primarySoft,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(_icon, color: c.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodyStrong.copyWith(
                        color: c.textPrimary,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _metaText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption.copyWith(color: c.textMuted),
                    ),
                  ],
                ),
              ),
              if (plan.hot)
                _MiniBadge(text: '热门', color: c.danger)
              else if (plan.featured)
                _MiniBadge(text: '推荐', color: c.primary),
            ],
          ),
          const SizedBox(height: 20),
          _PricePanel(symbol: ctrl.currencySymbol, price: price, unit: _unit),
          if (_cycleOptions.isNotEmpty) ...[
            const SizedBox(height: 12),
            _CycleSelectorC(
              cycles: _cycleOptions,
              enabledCycles: _availableCycles,
              selected: _cycle,
              onChanged: (cycle) => setState(() => _cycle = cycle),
            ),
          ],
          if (features.isNotEmpty) ...[
            const SizedBox(height: 14),
            _FeatureList(features: features),
          ],
          const SizedBox(height: 14),
          GestureDetector(
            onTap: price == null
                ? null
                : () => showOrderConfirmDialog(
                    context: context,
                    plan: plan,
                    cycle: _cycle,
                    api: ctrl.api,
                  ),
            child: Container(
              width: double.infinity,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: price == null ? c.surfaceMuted : c.primary,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Text(
                price == null ? '暂不可购买' : '立即购买',
                style: AppTextStyles.button.copyWith(
                  color: price == null ? c.textMuted : Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CycleSelectorC extends StatelessWidget {
  const _CycleSelectorC({
    required this.cycles,
    required this.enabledCycles,
    required this.selected,
    required this.onChanged,
  });

  final List<BillingCycle> cycles;
  final List<BillingCycle> enabledCycles;
  final BillingCycle selected;
  final ValueChanged<BillingCycle> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var index = 0; index < cycles.length; index++) ...[
          Expanded(
            child: _CycleChipC(
              cycle: cycles[index],
              enabled: enabledCycles.contains(cycles[index]),
              selected: selected == cycles[index],
              onTap: () => onChanged(cycles[index]),
            ),
          ),
          if (index != cycles.length - 1) const SizedBox(width: 6),
        ],
      ],
    );
  }
}

class _CycleChipC extends StatelessWidget {
  const _CycleChipC({
    required this.cycle,
    required this.enabled,
    required this.selected,
    required this.onTap,
  });

  final BillingCycle cycle;
  final bool enabled;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final fg = selected
        ? c.primary
        : enabled
        ? c.textMuted
        : c.textMuted.withValues(alpha: 0.38);
    final bg = selected
        ? c.primarySoft
        : enabled
        ? c.surfaceMuted
        : c.surfaceMuted.withValues(alpha: 0.22);
    final borderColor = selected
        ? c.primarySoft
        : enabled
        ? c.softBorder
        : c.softBorder.withValues(alpha: 0.35);
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: borderColor),
        ),
        child: Text(
          _cycleLabel(cycle),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.caption.copyWith(
            fontSize: 12,
            color: fg,
            fontWeight: selected
                ? FontWeight.w800
                : enabled
                ? FontWeight.w600
                : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}


String _cycleLabel(BillingCycle cycle) => switch (cycle) {
  BillingCycle.monthly => '月付',
  BillingCycle.quarterly => '季付',
  BillingCycle.halfYear => '半年',
  BillingCycle.yearly => '年付',
};

String _cycleUnit(BillingCycle cycle) => switch (cycle) {
  BillingCycle.monthly => '/ 月',
  BillingCycle.quarterly => '/ 季',
  BillingCycle.halfYear => '/ 半年',
  BillingCycle.yearly => '/ 年',
};

String _cleanFeature(String value) {
  return value
      .replaceFirst(RegExp(r'^[^\p{L}\p{N}]+', unicode: true), '')
      .trim();
}

bool _hasCapacity(PlanModel plan) {
  final capacity = plan.capacity.trim();
  return capacity.isNotEmpty && capacity != '0 GB' && capacity != '0 TB';
}
