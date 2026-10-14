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
    final plans = controller.plans.where((plan) =>
        _category == null || plan.category == _category).toList(growable: false);
    return LayoutBuilder(builder: (context, constraints) {
      // Horizontal gutters follow the shared page insets so the card-width
      // math matches what the scroll view actually applies.
      const padding = V3Layout.pageGutter;
      const spacing = 12.0;
      final contentWidth = constraints.maxWidth - padding * 2;
      final twoColumns = contentWidth >= 600;
      final cardWidth = twoColumns ? (contentWidth - spacing) / 2 : contentWidth;
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: V3Layout.pageInsets,
        child: V3WaveColumn(crossAxisAlignment: CrossAxisAlignment.start, children: [
          V3PageHeader(title: _tr(context, '选择套餐', 'Choose a plan', '選擇方案')),
          const SizedBox(height: 18),
          _CurrentPlanBadge(controller: controller),
          const SizedBox(height: 14),
          _CategoryDeck(selected: _category,
            onChanged: (value) => setState(() => _category = value)),
          const SizedBox(height: 14),
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
          else if (controller.dataLoadError != null && plans.isEmpty)
            // Failure is not emptiness: name the error and offer the retry.
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
                          onBuy: () => _openOrder(controller, plan,
                            v3DefaultCycle(plan)))),
                      if (plans.length - i == 1) const Expanded(child: SizedBox()),
                    ]))),
            ])
          else Wrap(spacing: spacing, runSpacing: spacing, children: [
            for (final plan in plans) SizedBox(width: cardWidth,
              child: _PlanCard(plan: plan,
                currencySymbol: controller.currencySymbol,
                desktop: twoColumns,
                onBuy: () => _openOrder(controller, plan, v3DefaultCycle(plan)))),
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
      plan.expiry,
    ];
    return V3Panel(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(children: [
        Icon(plan.usable ? Icons.verified_rounded : Icons.info_outline_rounded,
          size: 17, color: plan.usable ? p.successInk : p.inkMuted),
        const SizedBox(width: 9),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(plan.shortLabel, maxLines: 1,
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
    required this.desktop, required this.onBuy});
  final PlanModel plan;
  final String currencySymbol;
  final bool desktop;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    final cycle = v3DefaultCycle(plan);
    final price = v3PlanPrice(plan, cycle);
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
            style: TextStyle(color: p.ink, fontSize: price == null ? 14 : 24,
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
            onPressed: plan.soldOut || price == null ? null : onBuy,
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
