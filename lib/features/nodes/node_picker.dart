import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/app_controller.dart';
import '../../l10n/l10n.dart';
import '../../shared/layout/app_platform.dart';
import '../../shared/models/app_models.dart';
import '../../shared/services/node_filter.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_radius.dart';
import '../../shared/theme/app_spacing.dart';
import '../../shared/theme/app_text_styles.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_icon_button.dart';
import '../../shared/widgets/app_modal.dart';
import '../../shared/widgets/app_toast.dart';
import '../../shared/widgets/node_latency.dart';
import '../../shared/widgets/page_status_cards.dart';
import '../../shared/widgets/search_input.dart';
import 'widgets/greenfield_node_tile.dart';

Future<void> showNodePicker(BuildContext context) {
  return showAppAdaptiveModal<void>(
    context: context,
    builder: (_) => const _GreenfieldNodePicker(),
  );
}

class _GreenfieldNodePicker extends StatefulWidget {
  const _GreenfieldNodePicker();

  @override
  State<_GreenfieldNodePicker> createState() =>
      _GreenfieldNodePickerState();
}

class _GreenfieldNodePickerState extends State<_GreenfieldNodePicker> {
  static const List<NodeFilterTab> _filters = [
    NodeFilterTab.all,
    NodeFilterTab.asia,
    NodeFilterTab.europe,
    NodeFilterTab.america,
    NodeFilterTab.oceania,
  ];

  NodeFilterTab _filter = NodeFilterTab.all;
  String _query = '';
  bool _testingLatencies = false;

  List<NodeModel> _filteredNodes(AppController ctrl) => NodeFilter.apply(
        nodes: ctrl.nodes,
        query: _query,
        tab: _filter,
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
    if (_testingLatencies) return;
    if (ctrl.nodes.isEmpty) {
      AppToast.show(
        context,
        context.l10n.noTestableNodes,
        type: AppToastType.warning,
      );
      return;
    }

    setState(() => _testingLatencies = true);
    final success = await ctrl.testLatencies();
    if (!mounted) return;
    setState(() => _testingLatencies = false);

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
    final ctrl = AppScope.of(context);
    final nodes = _filteredNodes(ctrl);
    final desktop = AppPlatform.isDesktop;
    final height = (MediaQuery.sizeOf(context).height * (desktop ? 0.62 : 0.70))
        .clamp(desktop ? 360.0 : 420.0, desktop ? 500.0 : 620.0)
        .toDouble();
    final currentVisible = ctrl.autoSelected ||
        ctrl.currentNode.id.isEmpty ||
        nodes.any((node) => node.id == ctrl.currentNode.id);

    return AppAdaptiveModal(
      title: context.l10n.chooseNode,
      subtitle: ctrl.nodes.isEmpty
          ? context.l10n.noNodesSubscription
          : context.l10n.nodeCountSummary(ctrl.nodes.length),
      maxWidth: 680,
      maxHeightFactor: 0.92,
      child: SizedBox(
        height: height,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _PickerToolbar(
              desktop: desktop,
              testing: _testingLatencies,
              onSearchChanged: (value) => setState(() => _query = value),
              onTest: () => _testLatencies(ctrl),
            ),
            const SizedBox(height: AppSpacing.md),
            _PickerFilterBar(
              filters: _filters,
              selected: _filter,
              onSelected: (filter) => setState(() => _filter = filter),
            ),
            const SizedBox(height: AppSpacing.lg),
            _PickerAutoSelect(
              selected: ctrl.autoSelected,
              bestNode: _bestNode(ctrl.nodes),
              desktop: desktop,
              onPressed: () => _selectAuto(ctrl),
            ),
            if (!currentVisible) ...[
              const SizedBox(height: AppSpacing.sm),
              GreenfieldNodeTile(
                node: ctrl.currentNode,
                selected: true,
                favorite: false,
                compact: !desktop,
                pinnedCurrent: true,
                onPressed: () => _selectNode(ctrl, ctrl.currentNode),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: nodes.isEmpty
                  ? AppEmptyState(
                      icon: LucideIcons.searchX,
                      title: context.l10n.noMatchingNodes,
                      subtitle: context.l10n.tryDifferentNodeFilter,
                    )
                  : Scrollbar(
                      child: ListView.separated(
                        primary: true,
                        padding: EdgeInsets.zero,
                        itemCount: nodes.length,
                        itemBuilder: (context, index) {
                          final node = nodes[index];
                          return GreenfieldNodeTile(
                            node: node,
                            selected: !ctrl.autoSelected &&
                                node.id == ctrl.currentNode.id,
                            favorite: false,
                            compact: !desktop,
                            onPressed: () => _selectNode(ctrl, node),
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

  NodeModel? _bestNode(List<NodeModel> nodes) {
    NodeModel? best;
    for (final node in nodes) {
      if (node.latency <= 0 || node.latency >= 9999) continue;
      if (best == null || node.latency < best.latency) best = node;
    }
    return best;
  }
}

class _PickerToolbar extends StatelessWidget {
  const _PickerToolbar({
    required this.desktop,
    required this.testing,
    required this.onSearchChanged,
    required this.onTest,
  });

  final bool desktop;
  final bool testing;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onTest;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: SearchInput(
            hintText: context.l10n.searchNodes,
            onChanged: onSearchChanged,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        if (desktop)
          AppButton(
            label: context.l10n.latencyTest,
            onPressed: onTest,
            loading: testing,
            leadingIcon: LucideIcons.gauge,
            variant: AppButtonVariant.outline,
          )
        else
          AppIconButton(
            icon: LucideIcons.gauge,
            onPressed: onTest,
            loading: testing,
            tooltip: context.l10n.latencyTest,
            variant: AppIconButtonVariant.surface,
          ),
      ],
    );
  }
}

class _PickerFilterBar extends StatelessWidget {
  const _PickerFilterBar({
    required this.filters,
    required this.selected,
    required this.onSelected,
  });

  final List<NodeFilterTab> filters;
  final NodeFilterTab selected;
  final ValueChanged<NodeFilterTab> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final filter in filters) ...[
            _PickerFilterChip(
              label: _filterLabel(context, filter),
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

class _PickerFilterChip extends StatelessWidget {
  const _PickerFilterChip({
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Material(
      color: selected ? c.primarySoft : c.surfaceMuted,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Container(
          constraints: const BoxConstraints(minHeight: 36),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(
              color: selected
                  ? c.primary.withValues(alpha: 0.32)
                  : c.softBorder,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
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

class _PickerAutoSelect extends StatelessWidget {
  const _PickerAutoSelect({
    required this.selected,
    required this.bestNode,
    required this.desktop,
    required this.onPressed,
  });

  final bool selected;
  final NodeModel? bestNode;
  final bool desktop;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return AppCard(
      padding: EdgeInsets.zero,
      color: selected ? c.primarySoft : c.surfaceMuted,
      shadow: AppCardShadow.none,
      borderColor: selected
          ? c.primary.withValues(alpha: 0.36)
          : c.softBorder,
      onTap: onPressed,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: desktop ? 62 : 76),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              Container(
                width: desktop ? 38 : 42,
                height: desktop ? 38 : 42,
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
                NodeLatency(
                  latency: bestNode!.latency,
                  style: NodeLatencyStyle.badge,
                ),
                const SizedBox(width: AppSpacing.sm),
              ],
              Icon(
                selected
                    ? LucideIcons.circleCheck
                    : LucideIcons.chevronRight,
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

String _filterLabel(BuildContext context, NodeFilterTab filter) =>
    switch (filter) {
      NodeFilterTab.asia => context.l10n.asia,
      NodeFilterTab.europe => context.l10n.europe,
      NodeFilterTab.america => context.l10n.america,
      NodeFilterTab.oceania => context.l10n.oceania,
      _ => context.l10n.all,
    };
