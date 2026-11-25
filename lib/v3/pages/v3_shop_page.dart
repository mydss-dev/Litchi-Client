import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../app/plan_presentation.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../l10n/generated/app_localizations_zh.dart';
import '../../shared/models/app_models.dart';
import '../commerce/v3_order_dialog.dart';
import '../theme/v3_motion.dart';
import '../theme/v3_palette.dart';
import '../ui/v3_components.dart';
import '../ui/v3_empty_state.dart';
import '../ui/v3_layout.dart';
import '../ui/v3_plan_labels.dart';
import '../ui/v3_sheet.dart';

// The checkout body key now lives with the shared order dialog; re-export it so
// the shop's visual tests keep importing it from here.
export '../commerce/v3_order_dialog.dart' show kV3PurchaseDialogBodyKey;

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
    final plans = controller.plans.where((plan) {
      if (_category == null) return true;
      if (_category == PlanCategory.oneTime) {
        return plan.category == PlanCategory.oneTime ||
            (plan.category == PlanCategory.dataPack &&
              plan.oneTimePrice != null);
      }
      return plan.category == _category;
    }).toList(growable: false);
    return LayoutBuilder(builder: (context, constraints) {
      // Horizontal gutters follow the shared page insets so the card-width
      // math matches what the scroll view actually applies.
      final phone = constraints.maxWidth < V3Layout.paneCompact;
      final padding = phone ? 12.0 : V3Layout.pageGutter;
      const spacing = 12.0;
      final contentWidth = constraints.maxWidth - padding * 2;
      final twoColumns = contentWidth >= 600;
      final cardWidth = twoColumns ? (contentWidth - spacing) / 2 : contentWidth;
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: phone
            ? const EdgeInsets.fromLTRB(12, 12, 12, 112)
            : V3Layout.pageInsets,
        child: V3WaveColumn(crossAxisAlignment: CrossAxisAlignment.start, children: [
          V3PageHeader(
            title: phone ? _tr(context, '套餐订阅', 'Plans', '套餐訂閱')
                : _tr(context, '套餐', 'Plans', '套餐'),
            subtitle: phone
                ? _tr(context, '选择适合你的连接与流量方案',
                    'Find a connection and data plan that fits',
                    '選擇適合你的連線與流量方案')
                : _tr(context,
                    '${controller.plans.length} 个可用套餐',
                    '${controller.plans.length} available plans',
                    '${controller.plans.length} 個可用套餐')),
          const SizedBox(height: 18),
          if (phone)
            _MobileCategoryFilters(
              selected: _category,
              count: plans.length,
              onChanged: (kind) => setState(() => _category = kind))
          else
            _CategoryDeck(selected: _category,
              onChanged: (value) => setState(() => _category = value)),
          if (!phone) ...[
            const SizedBox(height: 14),
            _CurrentPlanBadge(controller: controller),
          ],
          const SizedBox(height: 14),
          // Redemption entry (§13.3): gift cards fold into the shop strip
          // instead of a second-level page on compact. The strip notes the
          // condition (no active plan required) and opens the redemption
          // sheet that already exists.
          if (controller.hasConfirmedNoPlan &&
              isPageEnabled(AppPage.giftCard)) ...[
            _RedeemStrip(controller: controller),
            const SizedBox(height: 14),
          ],
          if (controller.isInitialLoading)
            // First-load placeholders in the shape of plan cards, so the
            // loaded grid hands in without an empty-state flash (the tickets
            // page's loading-space rule).
            ...[
              if (twoColumns)
                Row(children: [
                  for (var i = 0; i < 2; i++) ...[
                    if (i > 0) const SizedBox(width: spacing),
                    const Expanded(child: _PlanCardSkeleton()),
                  ],
                ])
              else
                Wrap(spacing: spacing, runSpacing: spacing, children: [
                  for (var i = 0; i < 2; i++)
                    SizedBox(width: cardWidth,
                      child: const _PlanCardSkeleton()),
                ]),
            ]
          else if (controller.dataLoadError != null && controller.plans.isEmpty)
            // Failure is not emptiness: name the error and offer the retry.
            // Judged on the unfiltered list, so an empty category under no
            // global failure stays with the category empty state below.
            V3EmptyState(
              icon: Icons.error_outline_rounded,
              title: _tr(context, '套餐加载失败',
                  'Could not load plans', '方案載入失敗'),
              subtitle: controller.dataLoadError!,
              actionLabel: _tr(context, '重试', 'Retry', '重試'),
              onAction: controller.refreshData,
            )
          else if (plans.isEmpty)
            // Shared empty-state voice (icon tile, one muted line, one step).
            V3EmptyState(
              icon: Icons.inventory_2_rounded,
              title: _tr(context, '当前分类没有可购买套餐',
                  'No plans available in this category', '目前類別沒有可購買的方案'),
              subtitle: _tr(context, '切换分类看看，或刷新套餐列表。',
                  'Try another category, or refresh the list.',
                  '切換類別看看，或重新整理方案清單。'),
              actionLabel: _tr(context, '刷新套餐', 'Refresh plans', '重新整理方案'),
              onAction: controller.refreshData,
            )
          else if (twoColumns)
            // Pairs under an IntrinsicHeight: each row sizes to its taller
            // card, both price rows anchor to the card bottom, and short
            // feature lists stop leaving a dead band under a fixed 380px box
            // (the pricing-table convention on desktop).
            Column(children: [
              for (var i = 0; i < plans.length; i += 2)
                Padding(padding: EdgeInsets.only(top: i == 0 ? 0 : spacing),
                  child: IntrinsicHeight(child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final plan in plans.skip(i).take(2))
                        Expanded(child: _PlanCard(plan: plan,
                          currencySymbol: controller.currencySymbol,
                          desktop: true,
                          onBuy: (cycle) => _openOrder(controller, plan, cycle))),
                      if (plans.length - i == 1) const Expanded(child: SizedBox()),
                    ]))),
            ])
          else Wrap(spacing: spacing, runSpacing: spacing, children: [
            for (final plan in plans) SizedBox(width: cardWidth,
              child: _PlanCard(plan: plan,
                currencySymbol: controller.currencySymbol,
                desktop: twoColumns,
                onBuy: (cycle) => _openOrder(controller, plan, cycle))),
          ]),
        ]),
      );
    });
  }

  Future<void> _openOrder(AppController controller, PlanModel plan,
      BillingCycle cycle) => showV3OrderDialog(
    context: context,
    plan: plan,
    initialCycle: cycle,
    api: controller.api,
    currencySymbol: controller.currencySymbol,
    onPaid: controller.refreshData,
    onViewOrders: () => openV3Page(context, AppPage.orders),
  );
}


/// Approved V15: categories filter the catalog; billing cycles live in each
/// individual recurring plan card instead of a global selector.
class _MobileCategoryFilters extends StatelessWidget {
  const _MobileCategoryFilters({required this.selected,
    required this.count, required this.onChanged});
  final PlanCategory? selected;
  final int count;
  final ValueChanged<PlanCategory?> onChanged;
  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    final options = <(PlanCategory?, String, IconData, String)>[
      (null, _tr(context, '全部', 'All', '全部'), Icons.grid_view_rounded, 'all'),
      (PlanCategory.recurring, _tr(context, '周期性', 'Recurring', '週期性'),
        Icons.access_time_rounded, 'recurring'),
      (PlanCategory.oneTime, _tr(context, '一次性', 'One-time', '一次性'),
        Icons.shopping_bag_outlined, 'once'),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Text(_tr(context, '可购买套餐',
            'Available plans', '可購買套餐'),
          style: TextStyle(color: p.ink, fontSize: 16,
            fontWeight: FontWeight.w800))),
        Text(_tr(context, '共 $count 个方案', '$count plans',
              '共 $count 個方案'),
          style: TextStyle(color: p.inkMuted, fontSize: 10)),
      ]),
      const SizedBox(height: 13),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final (kind, label, glyph, keyName) in options)
          Material(
            color: selected == kind ? p.night : p.surface,
            borderRadius: BorderRadius.circular(25),
            child: InkWell(
              key: ValueKey('shop-filter-$keyName'),
              onTap: () => onChanged(kind),
              borderRadius: BorderRadius.circular(25),
              child: Container(
                constraints: const BoxConstraints(minHeight: 39),
                padding: const EdgeInsets.symmetric(horizontal: 13,
                  vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(color: selected == kind
                      ? p.night : p.line)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(glyph, size: 14, color: selected == kind
                      ? Colors.white : p.inkMuted),
                  const SizedBox(width: 6),
                  Text(label, style: TextStyle(fontSize: 12,
                    color: selected == kind ? Colors.white : p.ink,
                    fontWeight: FontWeight.w700)),
                ]),
              ),
            ),
          ),
      ]),
    ]);
  }
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
        // V3Pressable paints the ink above the panel's opaque fill instead of
        // on the root Material beneath it.
        for (final item in items) Expanded(child: V3Pressable(
          borderRadius: BorderRadius.circular(V3Radius.control),
          onTap: () => onChanged(item.$1),
          child: AnimatedContainer(
            duration: v3ReducedMotion(context)
                ? Duration.zero
                : V3Motion.fast,
            curve: V3Motion.ease,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: selected == item.$1 ? p.surface : Colors.transparent,
              borderRadius: BorderRadius.circular(V3Radius.control),
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

/// Redemption entry folded into the shop (§13.3): a quiet strip that names
/// the condition and opens the existing redemption sheet.
class _RedeemStrip extends StatelessWidget {
  const _RedeemStrip({required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return V3Panel(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      child: Row(children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: p.surfaceRaised,
            borderRadius: BorderRadius.circular(V3Radius.control),
          ),
          child: Icon(Icons.redeem_rounded, size: 18, color: p.inkMuted),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _tr(context, '有兑换卡？立即兑换', 'Have a gift card?',
                    '有兌換卡？立即兌換'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: p.ink,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _tr(context, '仅限当前无套餐账户使用',
                    'Available for accounts without an active plan',
                    '僅限目前無套餐帳戶使用'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: p.inkMuted, fontSize: 11),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        FilledButton(
          onPressed: () => openV3Page(context, AppPage.giftCard),
          style: FilledButton.styleFrom(
            backgroundColor: p.lychee,
            foregroundColor: p.onLychee,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            minimumSize: const Size(0, 36),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(V3Radius.field),
            ),
          ),
          child: Text(_tr(context, '立即兑换', 'Redeem', '立即兌換')),
        ),
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
    // Expiry rides the visible meta line, not a hover tooltip: touch has no
    // hover (Apple HIG: never gate essential info; M3 tooltips are desktop
    // supplements).
    final meta = <String>[
      if (controller.traffic.totalGb > 0)
        _tr(context,
          '剩余 ${controller.traffic.remainGb.toStringAsFixed(1)} GB',
          '${controller.traffic.remainGb.toStringAsFixed(1)} GB remaining',
          '剩餘 ${controller.traffic.remainGb.toStringAsFixed(1)} GB'),
      v3PlanExpiryLabel(context, plan),
    ];
    return V3Panel(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(children: [
        Icon(plan.statusKind == PlanStatus.normal
            ? Icons.verified_rounded : Icons.info_outline_rounded,
          size: 17, color: v3PlanStatusColor(p, plan.statusKind)),
        const SizedBox(width: 9),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(v3PlanShortLabel(context, plan), maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: p.ink, fontSize: 12,
                fontWeight: FontWeight.w700)),
            const SizedBox(height: 3),
            Text(meta.join(' · '), maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: p.inkMuted, fontSize: 11)),
          ])),
      ]),
    );
  }
}

/// First-load placeholder in the shape of a plan card, so the loaded grid
/// hands in without the empty state flashing first (the tickets page's
/// loading-space rule).
class _PlanCardSkeleton extends StatelessWidget {
  const _PlanCardSkeleton();
  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return V3Panel(padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const FractionallySizedBox(widthFactor: .62,
            alignment: Alignment.centerLeft,
            child: V3SkeletonBlock(height: 14)),
        const SizedBox(height: 9),
        const FractionallySizedBox(widthFactor: .4,
            alignment: Alignment.centerLeft,
            child: V3SkeletonBlock(height: 9)),
        const SizedBox(height: 18),
        const FractionallySizedBox(widthFactor: .45,
            alignment: Alignment.centerLeft,
            child: V3SkeletonBlock(height: 22)),
        const SizedBox(height: 15),
        for (final factor in const [.8, .72, .5]) Padding(
          padding: const EdgeInsets.only(bottom: 9),
          child: FractionallySizedBox(widthFactor: factor,
            alignment: Alignment.centerLeft,
            child: const V3SkeletonBlock(height: 12))),
        Divider(color: p.line, height: 1),
        const SizedBox(height: 11),
        const FractionallySizedBox(widthFactor: .3,
            alignment: Alignment.centerLeft,
            child: V3SkeletonBlock(height: 18)),
        const SizedBox(height: 12),
        const SizedBox(width: double.infinity, height: 44,
          child: V3SkeletonBlock(height: 44, radius: V3Radius.field)),
      ]));
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.plan, required this.currencySymbol,
    required this.desktop, required this.onBuy, this.chosenCycle});
  final PlanModel plan;
  final String currencySymbol;
  final bool desktop;
  final BillingCycle? chosenCycle;
  final ValueChanged<BillingCycle> onBuy;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    final cycle = plan.category == PlanCategory.recurring
        ? (chosenCycle ?? v3DefaultCycle(plan))
        : v3DefaultCycle(plan);
    final price = v3PlanPrice(plan, cycle);
    if (!desktop) {
      return _HtmlPhonePlanCard(
        key: ValueKey('shop-mobile-plan-${plan.id}'),
        plan: plan,
        currencySymbol: currencySymbol,
        onBuy: onBuy,
      );
    }
    final features = plan.features.take(3).toList(growable: false);
    final info = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Text(plan.title, maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: p.ink, fontSize: 16,
            fontWeight: FontWeight.w800))),
        if (plan.featured || plan.hot)
          V3StatusBadge(label: plan.featured
              ? _tr(context, '推荐', 'Recommended', '推薦')
              : _tr(context, '热门', 'Popular', '熱門'),
            color: p.lychee, compact: true),
      ]),
      const SizedBox(height: 4),
      Text(v3CategoryLabel(context, plan.category),
        style: TextStyle(color: p.inkMuted, fontSize: 11)),
      const SizedBox(height: 15),
      Text(plan.capacity.isEmpty
          ? _tr(context, '流量未标注', 'Traffic not specified', '未標示流量')
          : plan.capacity,
        style: TextStyle(color: p.ink, fontSize: 28, fontWeight: FontWeight.w900,
          fontFeatures: const [FontFeature.tabularFigures()])),
      const SizedBox(height: 12),
      // No divider here: title → capacity → features already read as one
      // group; the card keeps a single rule above the price block.
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
              minimumSize: const Size(0, 32)),
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
            style: TextStyle(color: p.ink, fontSize: price == null ? 14 : 22,
              fontWeight: FontWeight.w900,
              fontFeatures: const [FontFeature.tabularFigures()]))),
          Text(plan.category == PlanCategory.recurring
              ? v3CycleLabel(context, cycle)
              : _tr(context, '一次性', 'One-time', '一次性'),
            style: TextStyle(color: p.inkMuted, fontSize: 11)),
        ]),
        const SizedBox(height: 12),
        SizedBox(width: double.infinity, height: 44,
          child: FilledButton(
            onPressed: plan.soldOut || price == null ? null : () => onBuy(cycle),
            style: FilledButton.styleFrom(backgroundColor: p.lychee,
              foregroundColor: p.onLychee,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(V3Radius.field))),
            child: Text(plan.soldOut
                ? _tr(context, '已售罄', 'Sold out', '已售罄')
                : _tr(context, '选择套餐', 'Choose plan', '選擇方案')))),
      ]);
    return V3Panel(padding: const EdgeInsets.all(16),
      child: desktop
        ? Column(crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // IntrinsicHeight sizes every card to its tallest sibling; the
              // price anchors to the card bottom (pricing-table convention).
              Expanded(child: info),
              purchase])
        : Column(crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [info, const SizedBox(height: 14), purchase]));
  }
}


/// Mobile cycle options use only periods actually priced by the backend.
List<BillingCycle> _mobileAvailableCycles(PlanModel plan) => [
  if (plan.monthlyPrice != null) BillingCycle.monthly,
  if (plan.quarterlyPrice != null) BillingCycle.quarterly,
  if (plan.halfYearPrice != null) BillingCycle.halfYear,
  if (plan.yearlyPrice != null) BillingCycle.yearly,
  if (plan.twoYearPrice != null) BillingCycle.twoYears,
  if (plan.threeYearPrice != null) BillingCycle.threeYears,
];

class _HtmlPhonePlanCard extends StatefulWidget {
  const _HtmlPhonePlanCard({super.key, required this.plan,
    required this.currencySymbol, required this.onBuy});
  final PlanModel plan;
  final String currencySymbol;
  final ValueChanged<BillingCycle> onBuy;

  @override
  State<_HtmlPhonePlanCard> createState() => _HtmlPhonePlanCardState();
}

class _HtmlPhonePlanCardState extends State<_HtmlPhonePlanCard> {
  BillingCycle? _selected;
  @override
  void didUpdateWidget(covariant _HtmlPhonePlanCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.plan.id != widget.plan.id) _selected = null;
  }

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    final plan = widget.plan;
    final recurring = plan.category == PlanCategory.recurring;
    final cycles = recurring ? _mobileAvailableCycles(plan) : <BillingCycle>[];
    final cycle = cycles.contains(_selected) ? _selected!
        : (cycles.isEmpty ? BillingCycle.monthly : cycles.first);
    final price = v3PlanPrice(plan, cycle);
    // Recommendation is an explicit data flag only. No inferred ranking.
    final recommended = plan.featured;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = dark ? const Color(0xFFF4F2F2) : const Color(0xFF202226);
    final muted = dark ? const Color(0xFFA4A0A5) : const Color(0xFF83858C);
    final line = dark ? const Color(0xFF333439)
        : const Color(0xFFEBEBEE);
    final surface = dark ? const Color(0xFF202126) : Colors.white;
    final benefits = plan.features.length > 1
        ? plan.features.skip(1).toList(growable: false) : <String>[];

    return Container(
      key: ValueKey('shop-card-${plan.id}'),
      decoration: BoxDecoration(
        color: recommended
            ? (dark ? const Color(0xFF3E2F34)
                : const Color(0xFFFFE9E4))
            : surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: recommended
            ? (dark ? const Color(0xFF68494C)
                : const Color(0xFFF1D4CE))
            : line),
        boxShadow: dark ? null : const [BoxShadow(
          color: Color(0x0C241D21), offset: Offset(0, 7),
          blurRadius: 20)],
      ),
      child: Stack(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(19, 19, 19, 18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(flex: 51, child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(plan.title, maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: ink, fontSize: 20,
                      fontWeight: FontWeight.w800, height: 1.22)),
                  if (plan.features.isNotEmpty) ...[
                    const SizedBox(height: 7),
                    Text(plan.features.first, maxLines: 5,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: muted, fontSize: 11.5,
                        height: 1.5)),
                  ],
                ],
              )),
              const SizedBox(width: 8),
              Expanded(flex: 49, child: Padding(
                // V15: same price anchor with or without recommendation.
                padding: const EdgeInsets.only(top: 34),
                child: Column(crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (price == null)
                      Text(_tr(context, '价格待公布', 'Price unavailable',
                          '價格待公佈'),
                        textAlign: TextAlign.right,
                        style: TextStyle(color: muted, fontSize: 12))
                    else ...[
                      SizedBox(width: double.infinity, child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Row(mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.end, children: [
                          Padding(padding: const EdgeInsets.only(bottom: 4),
                            child: Text(widget.currencySymbol,
                              style: TextStyle(color: ink,
                                fontSize: 16, fontWeight: FontWeight.w800))),
                          Text(price.toStringAsFixed(2),
                            key: ValueKey('shop-price-${plan.id}'),
                            style: TextStyle(color: ink,
                              fontSize: 40, height: 1.1,
                              letterSpacing: -1.6,
                              fontWeight: FontWeight.w900,
                              fontFeatures: const [FontFeature.tabularFigures()])),
                        ]),
                      )),
                      const SizedBox(height: 2),
                      Text(recurring ? '/ ${v3CycleLabel(context, cycle)}'
                          : _tr(context, '一次性', 'One-time', '一次性'),
                        style: TextStyle(color: muted, fontSize: 11)),
                    ],
                  ],
                ),
              )),
            ]),
            if (plan.capacity.isNotEmpty ||
                (plan.deviceLimit != null && plan.deviceLimit! > 0)) ...[
              const SizedBox(height: 16),
              Wrap(spacing: 8, runSpacing: 8, children: [
                if (plan.capacity.isNotEmpty)
                  _MobilePlanSpec(icon: Icons.grid_view_rounded,
                    text: _tr(context, '流量 ${plan.capacity}',
                      'Data ${plan.capacity}', '流量 ${plan.capacity}')),
                if (plan.deviceLimit != null && plan.deviceLimit! > 0)
                  _MobilePlanSpec(icon: Icons.devices_outlined,
                    text: _tr(context, '设备 ${plan.deviceLimit} 台',
                      '${plan.deviceLimit} devices',
                      '裝置 ${plan.deviceLimit} 台')),
              ]),
            ],
            // The one-time plan never gets a pseudo-second purchase button.
            if (recurring && cycles.isNotEmpty) ...[
              const SizedBox(height: 18),
              Text(_tr(context, '购买周期', 'Billing period', '購買週期'),
                style: TextStyle(color: muted, fontSize: 11,
                  fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              LayoutBuilder(builder: (context, bounds) {
                final width = (bounds.maxWidth - 16) / 3;
                return Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final option in cycles)
                    SizedBox(width: width, height: 36,
                      child: _MobileCycleChip(
                        key: ValueKey('shop-cycle-${plan.id}-${option.name}'),
                        label: v3CycleLabel(context, option),
                        selected: cycle == option,
                        onTap: () => setState(() => _selected = option))),
                ]);
              }),
            ],
            if (benefits.isNotEmpty) ...[
              const SizedBox(height: 17),
              Divider(color: line, height: 1),
              const SizedBox(height: 16),
              for (final benefit in benefits)
                Padding(padding: const EdgeInsets.only(bottom: 11),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.check_rounded, size: 16,
                        color: recommended ? p.lycheeInk : muted),
                      const SizedBox(width: 9),
                      Expanded(child: Text(benefit,
                        style: TextStyle(color: ink,
                          fontSize: 12, height: 1.45))),
                    ])),
            ],
            const SizedBox(height: 17),
            SizedBox(width: double.infinity, height: 46,
              child: FilledButton(
                key: ValueKey('shop-buy-${plan.id}'),
                onPressed: plan.soldOut || price == null
                    ? null : () => widget.onBuy(cycle),
                style: FilledButton.styleFrom(
                  backgroundColor: dark ? const Color(0xFFF3E4E1)
                    : const Color(0xFF252429),
                  foregroundColor: dark ? const Color(0xFF2D2529)
                    : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16))),
                child: Text(plan.soldOut
                  ? _tr(context, '已售罄', 'Sold out', '已售罄')
                  : price == null
                    ? _tr(context, '暂不可购买', 'Unavailable', '暫不可購買')
                    : _tr(context, '选择此套餐',
                        'Choose this plan', '選擇此方案'),
                  style: const TextStyle(fontWeight: FontWeight.w700))),
            ),
          ]),
        ),
        if (recommended)
          Positioned(top: 13, right: 18,
            child: IgnorePointer(child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: dark ? const Color(0xFF322C30)
                  : const Color(0xFFFFF9F6),
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: dark
                  ? const Color(0xFF68494C)
                  : const Color(0xFFF1D4CE))),
              child: Text(_tr(context, '★ 推荐',
                  '★ Recommended', '★ 推薦'),
                style: TextStyle(color: p.lycheeInk,
                  fontSize: 11, fontWeight: FontWeight.w700)),
            ))),
      ]),
    );
  }
}

class _MobilePlanSpec extends StatelessWidget {
  const _MobilePlanSpec({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF313238)
          : const Color(0xFFF4F4F5),
        borderRadius: BorderRadius.circular(10)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: dark
          ? const Color(0xFFAEB1B8) : const Color(0xFF737780)),
        const SizedBox(width: 6),
        Text(text, style: TextStyle(fontSize: 11,
          color: dark ? const Color(0xFFAEB1B8)
            : const Color(0xFF737780), fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class _MobileCycleChip extends StatelessWidget {
  const _MobileCycleChip({super.key, required this.label,
    required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: selected
        ? (dark ? const Color(0xFFF4F2F2) : const Color(0xFF252429))
        : (dark ? const Color(0xFF24252A) : Colors.white),
      borderRadius: BorderRadius.circular(99),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(99),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 9),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border.all(color: selected
              ? (dark ? const Color(0xFFF4F2F2) : const Color(0xFF252429))
              : (dark ? const Color(0xFF3A393F)
                : const Color(0xFFECEBEF))),
            borderRadius: BorderRadius.circular(99)),
          child: Text(label, maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
              color: selected
                ? (dark ? const Color(0xFF252429) : Colors.white)
                : (dark ? const Color(0xFFF4F2F2)
                  : const Color(0xFF202226)))),
        ),
      ),
    );
  }
}

Future<void> _showPlanDetails(BuildContext context, PlanModel plan) =>
    showV3Sheet<void>(context, title: plan.title, builder: (sheetContext) {
  final p = V3Palette.of(sheetContext);
  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text('${v3CategoryLabel(sheetContext, plan.category)} · ${plan.capacity}',
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
