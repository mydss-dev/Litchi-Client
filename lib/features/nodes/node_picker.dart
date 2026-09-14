import 'package:country_flags/country_flags.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/app_controller.dart';
import '../../l10n/l10n.dart';
import '../../shared/layout/app_platform.dart';
import '../../shared/models/app_models.dart';
import '../../shared/services/node_filter.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_radius.dart';
import '../../shared/theme/app_shadows.dart';
import '../../shared/theme/app_spacing.dart';
import '../../shared/theme/app_text_styles.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_icon_button.dart';
import '../../shared/widgets/app_modal.dart';
import '../../shared/widgets/app_toast.dart';
import '../../shared/widgets/filter_tabs.dart';
import '../../shared/widgets/node_latency.dart';
import '../../shared/widgets/page_status_cards.dart';
import '../../shared/widgets/search_input.dart';

Future<void> showNodePicker(BuildContext context) {
  return showAppAdaptiveModal<void>(
    context: context,
    builder: (_) => const _NodePicker(),
  );
}

class _NodePicker extends StatefulWidget {
  const _NodePicker();

  @override
  State<_NodePicker> createState() => _NodePickerState();
}

class _NodePickerState extends State<_NodePicker> {
  static const _filterTabs = [
    NodeFilterTab.all,
    NodeFilterTab.asia,
    NodeFilterTab.europe,
    NodeFilterTab.america,
    NodeFilterTab.oceania,
  ];

  int _filterIndex = 0;
  String _query = '';

  List<String> _filterLabels(BuildContext context) => [
    context.l10n.all,
    context.l10n.asia,
    context.l10n.europe,
    context.l10n.america,
    context.l10n.oceania,
  ];

  List<NodeModel> _filteredNodes(AppController ctrl) => NodeFilter.apply(
    nodes: ctrl.nodes,
    query: _query,
    tab: _filterTabs[_filterIndex],
  );

  Future<void> _selectAuto(AppController ctrl) async {
    final error = await ctrl.selectAuto();
    if (!mounted) return;
    Navigator.of(context).pop();
    AppToast.show(
      context,
      error ?? context.l10n.autoSelectEnabled,
      type: error == null ? AppToastType.success : AppToastType.error,
    );
  }

  Future<void> _selectNode(AppController ctrl, NodeModel node) async {
    final error = await ctrl.setCurrentNode(node);
    if (!mounted) return;
    Navigator.of(context).pop();
    AppToast.show(
      context,
      error ?? context.l10n.switchedToNode(node.name),
      type: error == null ? AppToastType.success : AppToastType.error,
    );
  }

  Future<void> _testLatencies(AppController ctrl) async {
    if (ctrl.nodes.isEmpty) {
      AppToast.show(
        context,
        context.l10n.noTestableNodes,
        type: AppToastType.warning,
      );
      return;
    }
    final success = await ctrl.testLatencies();
    if (!mounted) return;
    AppToast.show(
      context,
      success
          ? context.l10n.latencyTestComplete
          : context.l10n.latencyTestFailed,
      type: success ? AppToastType.success : AppToastType.warning,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (AppPlatform.isDesktop) return _buildDesktopModal();

    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.86,
        minChildSize: 0.58,
        maxChildSize: 0.94,
        expand: false,
        builder: (_, scrollController) => _buildCompactSurface(scrollController),
      ),
    );
  }

  Widget _buildDesktopModal() {
    final ctrl = AppScope.of(context);
    final c = AppColors.of(context);
    final nodes = _filteredNodes(ctrl);
    final testing = ctrl.nodes.any((node) => node.latency < 0);
    final listHeight = (MediaQuery.sizeOf(context).height * 0.58)
        .clamp(360.0, 520.0)
        .toDouble();

    return AppAdaptiveModal(
      title: context.l10n.chooseNode,
      subtitle: ctrl.nodes.isNotEmpty
          ? context.l10n.nodeCountSummary(ctrl.nodes.length)
          : context.l10n.noNodesSubscription,
      maxWidth: 720,
      maxHeightFactor: 0.88,
      child: SizedBox(
        height: listHeight,
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: SearchInput(
                    hintText: context.l10n.searchNodes,
                    onChanged: (value) => setState(() => _query = value),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                AppButton(
                  label: context.l10n.latencyTest,
                  leadingIcon: LucideIcons.gauge,
                  variant: AppButtonVariant.outline,
                  loading: testing,
                  onPressed: () => _testLatencies(ctrl),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            FilterTabs(
              tabs: _filterLabels(context),
              selectedIndex: _filterIndex,
              onSelected: (index) => setState(() => _filterIndex = index),
            ),
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: _AutoSelectTile(
                      ctrl: ctrl,
                      selected: ctrl.autoSelected,
                      onTap: () => _selectAuto(ctrl),
                    ),
                  ),
                  const SliverToBoxAdapter(
                    child: SizedBox(height: AppSpacing.sm),
                  ),
                  if (nodes.isEmpty)
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.xl,
                      ),
                      sliver: SliverToBoxAdapter(
                        child: AppCard(
                          color: c.surfaceMuted,
                          shadow: AppCardShadow.none,
                          child: _buildEmptyState(context),
                        ),
                      ),
                    )
                  else
                    _buildNodeSliver(ctrl, nodes, 0),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactSurface(ScrollController scrollController) {
    final ctrl = AppScope.of(context);
    final c = AppColors.of(context);
    final nodes = _filteredNodes(ctrl);
    final testing = ctrl.nodes.any((node) => node.latency < 0);
    const horizontal = AppSpacing.lg;
    const surfaceRadius = BorderRadius.vertical(
      top: Radius.circular(AppRadius.xl),
    );

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: c.cardBg,
        borderRadius: surfaceRadius,
        border: Border(top: BorderSide(color: c.softBorder)),
        boxShadow: AppShadows.soft(c),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            const _SheetHandle(),
            _PickerHeader(
              nodeCount: ctrl.nodes.length,
              testing: testing,
              onTest: () => _testLatencies(ctrl),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: horizontal),
              child: SearchInput(
                hintText: context.l10n.searchNodes,
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: horizontal),
              child: FilterTabs(
                tabs: _filterLabels(context),
                selectedIndex: _filterIndex,
                onSelected: (index) => setState(() => _filterIndex = index),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: CustomScrollView(
                controller: scrollController,
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: horizontal),
                    sliver: SliverToBoxAdapter(
                      child: _AutoSelectTile(
                        ctrl: ctrl,
                        selected: ctrl.autoSelected,
                        onTap: () => _selectAuto(ctrl),
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(
                    child: SizedBox(height: AppSpacing.sm),
                  ),
                  if (nodes.isEmpty)
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(
                        horizontal,
                        AppSpacing.xxl,
                        horizontal,
                        AppSpacing.xl,
                      ),
                      sliver: SliverToBoxAdapter(
                        child: AppCard(
                          color: c.surfaceMuted,
                          shadow: AppCardShadow.none,
                          child: _buildEmptyState(context),
                        ),
                      ),
                    )
                  else
                    _buildNodeSliver(ctrl, nodes, horizontal),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final filtered = _query.trim().isNotEmpty || _filterIndex != 0;
    return AppEmptyState(
      icon: filtered ? LucideIcons.searchX : LucideIcons.globe2,
      title: filtered ? context.l10n.noMatchingNodes : context.l10n.noNodes,
      subtitle: filtered
          ? context.l10n.tryDifferentNodeFilter
          : context.l10n.waitForSubscription,
    );
  }

  Widget _buildNodeSliver(
    AppController ctrl,
    List<NodeModel> nodes,
    double horizontal,
  ) {
    return SliverPadding(
      padding: EdgeInsets.fromLTRB(
        horizontal,
        0,
        horizontal,
        AppSpacing.lg,
      ),
      sliver: SliverList.separated(
        itemCount: nodes.length,
        itemBuilder: (_, index) {
          final node = nodes[index];
          return _NodeTile(
            node: node,
            selected: !ctrl.autoSelected && ctrl.currentNode.id == node.id,
            onTap: () => _selectNode(ctrl, node),
          );
        },
        separatorBuilder: (_, _) =>
            const SizedBox(height: AppSpacing.sm),
      ),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Container(
        width: 38,
        height: 4,
        decoration: BoxDecoration(
          color: c.softBorder,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
      ),
    );
  }
}

class _PickerHeader extends StatelessWidget {
  const _PickerHeader({
    required this.nodeCount,
    required this.testing,
    required this.onTest,
  });

  final int nodeCount;
  final bool testing;
  final VoidCallback onTest;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.chooseNode,
                  style: AppTextStyles.sectionTitle.copyWith(
                    color: c.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  nodeCount > 0
                      ? context.l10n.nodeCountSummary(nodeCount)
                      : context.l10n.noNodesSubscription,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(color: c.textMuted),
                ),
              ],
            ),
          ),
          AppIconButton(
            icon: LucideIcons.gauge,
            tooltip: context.l10n.latencyTest,
            loading: testing,
            onPressed: onTest,
            variant: AppIconButtonVariant.surface,
          ),
          AppIconButton(
            icon: LucideIcons.x,
            tooltip: context.l10n.close,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

class _AutoSelectTile extends StatelessWidget {
  const _AutoSelectTile({
    required this.ctrl,
    required this.selected,
    required this.onTap,
  });

  final AppController ctrl;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final best = _bestNode();
    return _SelectableSurface(
      selected: selected,
      onTap: onTap,
      leading: _NodeIcon(icon: LucideIcons.zap, selected: selected),
      title: context.l10n.autoSelect,
      subtitle: best == null ? context.l10n.autoSelectBestDescription : best.name,
      trailing: best == null
          ? null
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (best.code.isNotEmpty) ...[
                  CountryFlag.fromCountryCode(
                    best.code,
                    theme: const ImageTheme(
                      width: 22,
                      height: 16,
                      shape: RoundedRectangle(3),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                ],
                NodeLatency(
                  latency: best.latency,
                  style: NodeLatencyStyle.badge,
                ),
              ],
            ),
    );
  }

  NodeModel? _bestNode() {
    NodeModel? best;
    for (final node in ctrl.nodes) {
      if (node.latency <= 0 || node.latency >= 9999) continue;
      if (best == null || node.latency < best.latency) best = node;
    }
    return best;
  }
}

class _NodeTile extends StatelessWidget {
  const _NodeTile({
    required this.node,
    required this.selected,
    required this.onTap,
  });

  final NodeModel node;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _SelectableSurface(
      selected: selected,
      onTap: onTap,
      leading: _FlagBox(node: node),
      title: node.name,
      subtitle: node.englishName.isEmpty
          ? _regionLabel(context, node.region)
          : node.englishName,
      trailing: NodeLatency(
        latency: node.latency,
        style: NodeLatencyStyle.badge,
      ),
    );
  }

  String _regionLabel(BuildContext context, NodeRegion region) =>
      switch (region) {
        NodeRegion.asia => context.l10n.asia,
        NodeRegion.europe => context.l10n.europe,
        NodeRegion.america => context.l10n.america,
        NodeRegion.oceania => context.l10n.oceania,
      };
}

class _SelectableSurface extends StatelessWidget {
  const _SelectableSurface({
    required this.selected,
    required this.onTap,
    required this.leading,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final bool selected;
  final VoidCallback onTap;
  final Widget leading;
  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final minHeight = AppPlatform.isDesktop ? 60.0 : 72.0;

    return AppCard(
      padding: EdgeInsets.zero,
      radius: AppRadius.card,
      color: selected ? c.primarySoft : c.cardBg,
      shadow: AppCardShadow.none,
      borderColor: selected ? c.primary : c.softBorder,
      onTap: onTap,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: minHeight),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              leading,
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodyStrong.copyWith(
                        color: selected ? c.primary : c.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption.copyWith(color: c.textMuted),
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: AppSpacing.md),
                trailing!,
              ],
              if (selected) ...[
                const SizedBox(width: AppSpacing.sm),
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: c.primary,
                    shape: BoxShape.circle,
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

class _NodeIcon extends StatelessWidget {
  const _NodeIcon({required this.icon, required this.selected});

  final IconData icon;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? c.primary : c.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Icon(
        icon,
        color: selected ? Colors.white : c.primary,
        size: 19,
      ),
    );
  }
}

class _FlagBox extends StatelessWidget {
  const _FlagBox({required this.node});

  final NodeModel node;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: c.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: node.code.isEmpty
          ? Icon(LucideIcons.globe2, size: 19, color: c.iconMuted)
          : CountryFlag.fromCountryCode(
              node.code,
              theme: const ImageTheme(
                width: 26,
                height: 18,
                shape: RoundedRectangle(4),
              ),
            ),
    );
  }
}
