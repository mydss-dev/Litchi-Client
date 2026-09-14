import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/nav_destinations.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/layout/app_platform.dart';
import '../../../shared/models/app_models.dart';
import '../../../shared/services/node_filter.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_radius.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_text_styles.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_icon_button.dart';
import '../../../shared/widgets/page_status_cards.dart';
import '../../../shared/widgets/search_input.dart';
import 'greenfield_node_tile.dart';

class GreenfieldNodesBrowser extends StatelessWidget {
  const GreenfieldNodesBrowser({
    super.key,
    required this.allNodes,
    required this.visibleNodes,
    required this.currentNode,
    required this.selectedNodeId,
    required this.autoSelected,
    required this.favorites,
    required this.selectedFilter,
    required this.testingLatencies,
    required this.noPlan,
    required this.onSearchChanged,
    required this.onFilterChanged,
    required this.onAutoSelect,
    required this.onSelectNode,
    required this.onToggleFavorite,
    required this.onLatencyTest,
    required this.onRefresh,
    this.onPurchase,
  });

  final List<NodeModel> allNodes;
  final List<NodeModel> visibleNodes;
  final NodeModel currentNode;
  final String? selectedNodeId;
  final bool autoSelected;
  final Set<String> favorites;
  final NodeFilterTab selectedFilter;
  final bool testingLatencies;
  final bool noPlan;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<NodeFilterTab> onFilterChanged;
  final VoidCallback onAutoSelect;
  final ValueChanged<NodeModel> onSelectNode;
  final ValueChanged<String> onToggleFavorite;
  final VoidCallback onLatencyTest;
  final RefreshCallback onRefresh;
  final VoidCallback? onPurchase;

  static const List<NodeFilterTab> _filters = [
    NodeFilterTab.all,
    NodeFilterTab.favorite,
    NodeFilterTab.asia,
    NodeFilterTab.europe,
    NodeFilterTab.america,
    NodeFilterTab.oceania,
  ];

  @override
  Widget build(BuildContext context) {
    if (AppPlatform.isDesktop) return _buildDesktop(context);
    return _buildCompact(context);
  }

  Widget _buildDesktop(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : (MediaQuery.sizeOf(context).height - 160).clamp(440.0, 900.0);

        return SizedBox(
          height: availableHeight,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _DesktopToolbar(
                visibleCount: visibleNodes.length,
                testingLatencies: testingLatencies,
                onSearchChanged: onSearchChanged,
                onLatencyTest: onLatencyTest,
              ),
              const SizedBox(height: AppSpacing.lg),
              Expanded(
                child: noPlan
                    ? _NoPlanSurface(onPurchase: onPurchase)
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            width: 144,
                            child: _FilterRail(
                              filters: _filters,
                              selected: selectedFilter,
                              counts: _counts(),
                              onSelected: onFilterChanged,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.lg),
                          Expanded(child: _DesktopNodePane(browser: this)),
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCompact(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _CompactHeader(
                  testingLatencies: testingLatencies,
                  onLatencyTest: onLatencyTest,
                ),
                const SizedBox(height: AppSpacing.lg),
                SearchInput(
                  hintText: context.l10n.searchNodes,
                  onChanged: onSearchChanged,
                ),
                const SizedBox(height: AppSpacing.md),
                _CompactFilterChips(
                  filters: _filters,
                  selected: selectedFilter,
                  counts: _counts(),
                  onSelected: onFilterChanged,
                ),
                const SizedBox(height: AppSpacing.lg),
                if (noPlan)
                  _NoPlanSurface(onPurchase: onPurchase)
                else ...[
                  _AutoSelectSurface(
                    selected: autoSelected,
                    bestNode: _bestNode(),
                    compact: true,
                    onPressed: onAutoSelect,
                  ),
                  if (_shouldPinCurrent()) ...[
                    const SizedBox(height: AppSpacing.md),
                    GreenfieldNodeTile(
                      node: currentNode,
                      selected: true,
                      favorite: favorites.contains(currentNode.id),
                      compact: true,
                      pinnedCurrent: true,
                      onPressed: () => onSelectNode(currentNode),
                      onToggleFavorite: () => onToggleFavorite(currentNode.id),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                ],
              ],
            ),
          ),
          if (!noPlan)
            if (visibleNodes.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xxl),
                  child: AppEmptyState(
                    icon: LucideIcons.searchX,
                    title: context.l10n.noMatchingNodes,
                    subtitle: context.l10n.tryDifferentNodeFilter,
                  ),
                ),
              )
            else
              SliverList.separated(
                itemCount: visibleNodes.length,
                itemBuilder: (context, index) {
                  final node = visibleNodes[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: GreenfieldNodeTile(
                      node: node,
                      selected: !autoSelected && node.id == selectedNodeId,
                      favorite: favorites.contains(node.id),
                      compact: true,
                      onPressed: () => onSelectNode(node),
                      onToggleFavorite: () => onToggleFavorite(node.id),
                    ),
                  );
                },
                separatorBuilder: (_, _) => const SizedBox.shrink(),
              ),
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xxl)),
        ],
      ),
    );
  }

  NodeModel? _bestNode() {
    NodeModel? best;
    for (final node in allNodes) {
      if (node.latency <= 0 || node.latency >= 9999) continue;
      if (best == null || node.latency < best.latency) best = node;
    }
    return best;
  }

  bool _shouldPinCurrent() {
    if (autoSelected || currentNode.id.isEmpty) return false;
    return !visibleNodes.any((node) => node.id == currentNode.id);
  }

  Map<NodeFilterTab, int> _counts() {
    int region(NodeRegion target) =>
        allNodes.where((node) => node.region == target).length;

    return {
      NodeFilterTab.all: allNodes.length,
      NodeFilterTab.favorite:
          allNodes.where((node) => favorites.contains(node.id)).length,
      NodeFilterTab.asia: region(NodeRegion.asia),
      NodeFilterTab.europe: region(NodeRegion.europe),
      NodeFilterTab.america: region(NodeRegion.america),
      NodeFilterTab.oceania: region(NodeRegion.oceania),
    };
  }
}

class _DesktopToolbar extends StatelessWidget {
  const _DesktopToolbar({
    required this.visibleCount,
    required this.testingLatencies,
    required this.onSearchChanged,
    required this.onLatencyTest,
  });

  final int visibleCount;
  final bool testingLatencies;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onLatencyTest;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Row(
      children: [
        SizedBox(
          width: 132,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.nodes,
                style: AppTextStyles.pageTitle.copyWith(color: c.textPrimary),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                context.l10n.nodeCountSummary(visibleCount),
                style: AppTextStyles.caption.copyWith(color: c.textMuted),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.lg),
        Expanded(
          child: SearchInput(
            hintText: context.l10n.searchNodes,
            onChanged: onSearchChanged,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        AppButton(
          label: context.l10n.latencyTest,
          onPressed: onLatencyTest,
          loading: testingLatencies,
          leadingIcon: LucideIcons.gauge,
          variant: AppButtonVariant.outline,
        ),
      ],
    );
  }
}

class _CompactHeader extends StatelessWidget {
  const _CompactHeader({
    required this.testingLatencies,
    required this.onLatencyTest,
  });

  final bool testingLatencies;
  final VoidCallback onLatencyTest;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.nodes,
                style: AppTextStyles.pageTitle.copyWith(color: c.textPrimary),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                context.l10n.selectLineAndLatency,
                style: AppTextStyles.caption.copyWith(color: c.textMuted),
              ),
            ],
          ),
        ),
        AppIconButton(
          icon: LucideIcons.gauge,
          onPressed: onLatencyTest,
          loading: testingLatencies,
          tooltip: context.l10n.latencyTest,
          variant: AppIconButtonVariant.surface,
        ),
      ],
    );
  }
}

class _FilterRail extends StatelessWidget {
  const _FilterRail({
    required this.filters,
    required this.selected,
    required this.counts,
    required this.onSelected,
  });

  final List<NodeFilterTab> filters;
  final NodeFilterTab selected;
  final Map<NodeFilterTab, int> counts;
  final ValueChanged<NodeFilterTab> onSelected;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.cardBg,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: c.softBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final filter in filters) ...[
              _FilterRailItem(
                filter: filter,
                label: _filterLabel(context, filter),
                count: counts[filter] ?? 0,
                selected: selected == filter,
                onPressed: () => onSelected(filter),
              ),
              if (filter != filters.last)
                const SizedBox(height: AppSpacing.xs),
            ],
          ],
        ),
      ),
    );
  }
}

class _FilterRailItem extends StatelessWidget {
  const _FilterRailItem({
    required this.filter,
    required this.label,
    required this.count,
    required this.selected,
    required this.onPressed,
  });

  final NodeFilterTab filter;
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final icon = filter == NodeFilterTab.favorite
        ? LucideIcons.star
        : LucideIcons.globe2;

    return Material(
      color: selected ? c.primarySoft : Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: SizedBox(
          height: 44,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Row(
              children: [
                Icon(icon, size: 16, color: selected ? c.primary : c.iconMuted),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyStrong.copyWith(
                      color: selected ? c.primary : c.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ),
                Text(
                  '$count',
                  style: AppTextStyles.caption.copyWith(
                    color: selected ? c.primary : c.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CompactFilterChips extends StatelessWidget {
  const _CompactFilterChips({
    required this.filters,
    required this.selected,
    required this.counts,
    required this.onSelected,
  });

  final List<NodeFilterTab> filters;
  final NodeFilterTab selected;
  final Map<NodeFilterTab, int> counts;
  final ValueChanged<NodeFilterTab> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final filter in filters) ...[
            _FilterChipButton(
              label: _filterLabel(context, filter),
              count: counts[filter] ?? 0,
              selected: selected == filter,
              onPressed: () => onSelected(filter),
            ),
            if (filter != filters.last)
              const SizedBox(width: AppSpacing.sm),
          ],
        ],
      ),
    );
  }
}

class _FilterChipButton extends StatelessWidget {
  const _FilterChipButton({
    required this.label,
    required this.count,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Material(
      color: selected ? c.primarySoft : c.cardBg,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Container(
          constraints: const BoxConstraints(minHeight: 40),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(
              color: selected ? c.primary.withValues(alpha: 0.32) : c.softBorder,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            '$label  $count',
            style: AppTextStyles.bodyStrong.copyWith(
              color: selected ? c.primary : c.textSecondary,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}

class _DesktopNodePane extends StatelessWidget {
  const _DesktopNodePane({required this.browser});

  final GreenfieldNodesBrowser browser;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final pinCurrent = browser._shouldPinCurrent();

    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.cardBg,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: c.softBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _AutoSelectSurface(
              selected: browser.autoSelected,
              bestNode: browser._bestNode(),
              compact: false,
              onPressed: browser.onAutoSelect,
            ),
            if (pinCurrent) ...[
              const SizedBox(height: AppSpacing.sm),
              GreenfieldNodeTile(
                node: browser.currentNode,
                selected: true,
                favorite: browser.favorites.contains(browser.currentNode.id),
                compact: false,
                pinnedCurrent: true,
                onPressed: () => browser.onSelectNode(browser.currentNode),
                onToggleFavorite: () =>
                    browser.onToggleFavorite(browser.currentNode.id),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: browser.visibleNodes.isEmpty
                  ? AppEmptyState(
                      icon: LucideIcons.searchX,
                      title: context.l10n.noMatchingNodes,
                      subtitle: context.l10n.tryDifferentNodeFilter,
                    )
                  : Scrollbar(
                      child: ListView.separated(
                        primary: true,
                        padding: EdgeInsets.zero,
                        itemCount: browser.visibleNodes.length,
                        itemBuilder: (context, index) {
                          final node = browser.visibleNodes[index];
                          return GreenfieldNodeTile(
                            node: node,
                            selected: !browser.autoSelected &&
                                node.id == browser.selectedNodeId,
                            favorite: browser.favorites.contains(node.id),
                            compact: false,
                            onPressed: () => browser.onSelectNode(node),
                            onToggleFavorite: () =>
                                browser.onToggleFavorite(node.id),
                          );
                        },
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: AppSpacing.sm),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AutoSelectSurface extends StatelessWidget {
  const _AutoSelectSurface({
    required this.selected,
    required this.bestNode,
    required this.compact,
    required this.onPressed,
  });

  final bool selected;
  final NodeModel? bestNode;
  final bool compact;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return AppCard(
      padding: EdgeInsets.zero,
      color: selected ? c.primarySoft : c.surfaceMuted,
      shadow: AppCardShadow.none,
      borderColor: selected ? c.primary.withValues(alpha: 0.36) : c.softBorder,
      onTap: onPressed,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: compact ? 76 : 66),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              Container(
                width: compact ? 42 : 38,
                height: compact ? 42 : 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: selected ? c.brandGradient : null,
                  color: selected ? null : c.cardBg,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(
                  LucideIcons.zap,
                  size: 18,
                  color: selected ? Colors.white : c.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.autoSelect,
                      style: AppTextStyles.bodyStrong.copyWith(
                        color: selected ? c.primary : c.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      bestNode?.name ?? context.l10n.autoSelectBestDescription,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption.copyWith(color: c.textMuted),
                    ),
                  ],
                ),
              ),
              if (bestNode != null) ...[
                NodeLatencyBadge(node: bestNode!),
                const SizedBox(width: AppSpacing.sm),
              ],
              Icon(
                selected ? LucideIcons.circleCheck : LucideIcons.chevronRight,
                size: 18,
                color: selected ? c.primary : c.iconMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class NodeLatencyBadge extends StatelessWidget {
  const NodeLatencyBadge({super.key, required this.node});

  final NodeModel node;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.of(context).cardBg,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        node.latency > 0 && node.latency < 9999 ? '${node.latency} ms' : '--',
        style: AppTextStyles.caption.copyWith(
          color: AppColors.of(context).textSecondary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _NoPlanSurface extends StatelessWidget {
  const _NoPlanSurface({this.onPurchase});

  final VoidCallback? onPurchase;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: AppCard(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: c.primarySoft,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: Icon(LucideIcons.packageOpen, color: c.primary, size: 26),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                context.l10n.noCurrentPlan,
                textAlign: TextAlign.center,
                style: AppTextStyles.sectionTitle.copyWith(color: c.textPrimary),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                context.l10n.noPlanDescription,
                textAlign: TextAlign.center,
                style: AppTextStyles.body.copyWith(
                  color: c.textSecondary,
                  height: 1.45,
                ),
              ),
              if (onPurchase != null) ...[
                const SizedBox(height: AppSpacing.xl),
                AppButton(
                  label: context.l10n.buyPlans,
                  onPressed: onPurchase,
                  leadingIcon: LucideIcons.shoppingBag,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

String _filterLabel(BuildContext context, NodeFilterTab filter) => switch (filter) {
      NodeFilterTab.favorite => context.l10n.favorites,
      NodeFilterTab.asia => context.l10n.asia,
      NodeFilterTab.europe => context.l10n.europe,
      NodeFilterTab.america => context.l10n.america,
      NodeFilterTab.oceania => context.l10n.oceania,
      _ => context.l10n.all,
    };
