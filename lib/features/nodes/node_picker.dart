import 'package:country_flags/country_flags.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/app_controller.dart';
import '../../l10n/l10n.dart';
import '../../shared/models/app_models.dart';
import '../../shared/services/node_filter.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_radius.dart';
import '../../shared/theme/app_shadows.dart';
import '../../shared/theme/app_text_styles.dart';
import '../../shared/widgets/app_card.dart';
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
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.86,
        minChildSize: 0.58,
        maxChildSize: 0.94,
        expand: false,
        builder: (_, scrollController) => _buildSurface(scrollController),
      ),
    );
  }

  Widget _buildSurface([ScrollController? scrollController]) {
    final ctrl = AppScope.of(context);
    final c = AppColors.of(context);
    final nodes = _filteredNodes(ctrl);
    final testing = ctrl.nodes.any((node) => node.latency < 0);
    const horizontal = 18.0;
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
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: horizontal),
              child: FilterTabs(
                tabs: _filterLabels(context),
                selectedIndex: _filterIndex,
                onSelected: (index) => setState(() => _filterIndex = index),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: CustomScrollView(
                controller: scrollController,
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      horizontal,
                      0,
                      horizontal,
                      0,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: _AutoSelectTile(
                        ctrl: ctrl,
                        selected: ctrl.autoSelected,
                        onTap: () => _selectAuto(ctrl),
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 10)),
                  if (nodes.isEmpty)
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(
                        horizontal,
                        38,
                        horizontal,
                        20,
                      ),
                      sliver: SliverToBoxAdapter(
                        child: AppCard(
                          color: c.surfaceMuted,
                          shadow: AppCardShadow.none,
                          child: AppEmptyState(
                            icon: _query.trim().isNotEmpty || _filterIndex != 0
                                ? LucideIcons.searchX
                                : LucideIcons.globe2,
                            title: _query.trim().isNotEmpty || _filterIndex != 0
                                ? context.l10n.noMatchingNodes
                                : context.l10n.noNodes,
                            subtitle:
                                _query.trim().isNotEmpty || _filterIndex != 0
                                ? context.l10n.tryDifferentNodeFilter
                                : context.l10n.waitForSubscription,
                          ),
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

  Widget _buildNodeSliver(
    AppController ctrl,
    List<NodeModel> nodes,
    double horizontal,
  ) {
    Widget tileAt(int index) {
      final node = nodes[index];
      return _NodeTile(
        node: node,
        selected: !ctrl.autoSelected && ctrl.currentNode.id == node.id,
        onTap: () => _selectNode(ctrl, node),
      );
    }

    return SliverPadding(
      padding: EdgeInsets.fromLTRB(horizontal, 0, horizontal, 18),
      sliver: SliverList.separated(
        itemCount: nodes.length,
        itemBuilder: (_, index) => tileAt(index),
        separatorBuilder: (_, _) => const SizedBox(height: 10),
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
      padding: const EdgeInsets.only(top: 8),
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
      padding: const EdgeInsets.fromLTRB(18, 14, 10, 10),
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
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 3),
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
          IconButton(
            tooltip: context.l10n.latencyTest,
            onPressed: testing ? null : onTest,
            icon: testing
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: c.primary,
                    ),
                  )
                : Icon(LucideIcons.gauge, color: c.primary, size: 19),
          ),
          IconButton(
            tooltip: context.l10n.close,
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(LucideIcons.x, color: c.iconMuted, size: 19),
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
    final c = AppColors.of(context);
    final best = _bestNode();
    return _SelectableSurface(
      selected: selected,
      onTap: onTap,
      child: Row(
        children: [
          _NodeIcon(icon: LucideIcons.zap, selected: selected),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.autoSelect,
                  style: AppTextStyles.bodyStrong.copyWith(
                    color: c.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                if (best != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CountryFlag.fromCountryCode(
                        best.code.isNotEmpty ? best.code : 'UN',
                        theme: const ImageTheme(
                          width: 18,
                          height: 13,
                          shape: RoundedRectangle(2),
                        ),
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          '${best.name} · ${best.latency} ms',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.caption.copyWith(
                            color: c.textMuted,
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  Text(
                    context.l10n.autoSelectBestDescription,
                    style: AppTextStyles.caption.copyWith(color: c.textMuted),
                  ),
              ],
            ),
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
    final c = AppColors.of(context);
    return _SelectableSurface(
      selected: selected,
      onTap: onTap,
      child: Row(
        children: [
          _FlagBox(node: node),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  node.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyStrong.copyWith(
                    color: c.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  node.englishName.isEmpty
                      ? _regionLabel(context, node.region)
                      : node.englishName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(color: c.textMuted),
                ),
              ],
            ),
          ),
          NodeLatency(latency: node.latency),
        ],
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
    required this.child,
  });

  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected ? c.primarySoft : null,
            gradient: selected ? null : c.cardGradient,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: selected ? c.primary : c.softBorder),
          ),
          child: child,
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
        color: selected ? c.cardBg : c.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Icon(icon, color: c.primary, size: 19),
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
