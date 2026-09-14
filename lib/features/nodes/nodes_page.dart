import 'dart:async';

import 'package:country_flags/country_flags.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/app_controller.dart';
import '../../app/nav_destinations.dart';
import '../../l10n/l10n.dart';
import '../../shared/layout/app_platform.dart';
import '../../shared/models/app_models.dart';
import '../../shared/services/node_filter.dart';
import '../../shared/services/settings_service.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_motion.dart';
import '../../shared/theme/app_radius.dart';
import '../../shared/theme/app_spacing.dart';
import '../../shared/theme/app_text_styles.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_icon_button.dart';
import '../../shared/widgets/app_toast.dart';
import '../../shared/widgets/filter_tabs.dart';
import '../../shared/widgets/node_latency.dart';
import '../../shared/widgets/no_plan_card.dart';
import '../../shared/widgets/page_header.dart';
import '../../shared/widgets/page_status_cards.dart';
import '../../shared/widgets/search_input.dart';

/// Node selection page. Business behavior remains owned by [AppController];
/// this widget only adapts presentation for pointer and touch platforms.
class NodesPage extends StatefulWidget {
  const NodesPage({super.key});

  @override
  State<NodesPage> createState() => _NodesPageState();
}

class _NodesPageState extends State<NodesPage> {
  int _tab = 0;
  String _query = '';
  String _pendingQuery = '';
  String? _selectedId;
  Set<String> _favorites = {};
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _selectedId ??= AppScope.of(context).currentNode.id;
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }

  Future<void> _loadFavorites() async {
    final favorites = await SettingsService.loadFavorites();
    if (mounted) setState(() => _favorites = favorites);
  }

  void _toggleFavorite(String id) {
    setState(() {
      if (!_favorites.add(id)) _favorites.remove(id);
    });
    SettingsService.saveFavorites(_favorites);
  }

  void _onSearchChanged(String value) {
    _pendingQuery = value;
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 220), () {
      if (!mounted) return;
      setState(() => _query = _pendingQuery);
    });
  }

  NodeFilterTab get _selectedTab => switch (_tab) {
    1 => NodeFilterTab.favorite,
    2 => NodeFilterTab.asia,
    3 => NodeFilterTab.europe,
    4 => NodeFilterTab.america,
    5 => NodeFilterTab.oceania,
    _ => NodeFilterTab.all,
  };

  List<NodeModel> get _filtered => NodeFilter.apply(
    nodes: AppScope.of(context).nodes,
    query: _query,
    tab: _selectedTab,
    favorites: _favorites,
  );

  List<String> _tabs(BuildContext context) => [
    context.l10n.all,
    context.l10n.favorites,
    context.l10n.asia,
    context.l10n.europe,
    context.l10n.america,
    context.l10n.oceania,
  ];

  Future<void> _handleRefresh() async {
    await AppScope.of(context).testLatencies();
    await _loadFavorites();
    if (!mounted) return;
    AppToast.show(
      context,
      context.l10n.refreshed,
      type: AppToastType.success,
    );
  }

  Future<void> _toggleAutoSelect() async {
    final ctrl = AppScope.of(context);
    final error = await ctrl.selectAuto();
    if (!mounted) return;
    if (error != null) {
      AppToast.show(context, error, type: AppToastType.error);
      return;
    }
    setState(() => _selectedId = null);
    AppToast.show(
      context,
      context.l10n.autoSelectEnabled,
      type: AppToastType.success,
    );
  }

  Future<void> _selectNode(NodeModel node) async {
    final ctrl = AppScope.of(context);
    final error = await ctrl.setCurrentNode(node);
    if (!mounted) return;
    if (error != null) {
      AppToast.show(context, error, type: AppToastType.error);
      return;
    }
    setState(() => _selectedId = node.id);
    AppToast.show(
      context,
      context.l10n.switchedToNode(node.name),
      type: AppToastType.success,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppPlatform.isDesktop
        ? _buildDesktop(context)
        : _buildCompact(context);
  }

  Widget _buildDesktop(BuildContext context) {
    final c = AppColors.of(context);
    final ctrl = AppScope.of(context);
    final nodes = _filtered;
    final autoSelected = ctrl.autoSelected;
    final selectedId = autoSelected
        ? '__auto__'
        : (_selectedId ?? ctrl.currentNode.id);
    final noPlan =
        ctrl.hasAccountSummary && !ctrl.isInitialLoading && !ctrl.hasPlan;

    if (noPlan) {
      return NoPlanCard(
        onPurchase: isPageEnabled(AppPage.shop)
            ? () => ctrl.goToPage(AppPage.shop)
            : null,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: SearchInput(
                hintText: context.l10n.searchNodes,
                onChanged: _onSearchChanged,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Text(
              context.l10n.nodeCountSummary(nodes.length),
              style: AppTextStyles.caption.copyWith(color: c.textMuted),
            ),
            const SizedBox(width: AppSpacing.md),
            _LatencyTestButton(ctrl: ctrl, showLabel: true),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        _AutoSelectSurface(
          ctrl: ctrl,
          selected: autoSelected,
          onTap: _toggleAutoSelect,
        ),
        const SizedBox(height: AppSpacing.md),
        FilterTabs(
          tabs: _tabs(context),
          selectedIndex: _tab,
          onSelected: (index) => setState(() => _tab = index),
        ),
        const SizedBox(height: AppSpacing.md),
        if (nodes.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xxl),
            child: AppEmptyState(
              icon: LucideIcons.searchX,
              title: context.l10n.noMatchingNodes,
              subtitle: context.l10n.tryDifferentNodeFilter,
            ),
          )
        else
          _DesktopNodeTable(
            nodes: nodes,
            selectedId: selectedId,
            autoSelected: autoSelected,
            favorites: _favorites,
            onSelect: _selectNode,
            onToggleFavorite: _toggleFavorite,
          ),
      ],
    );
  }

  Widget _buildCompact(BuildContext context) {
    final c = AppColors.of(context);
    final ctrl = AppScope.of(context);
    final nodes = _filtered;
    final autoSelected = ctrl.autoSelected;
    final selectedId = autoSelected
        ? '__auto__'
        : (_selectedId ?? ctrl.currentNode.id);
    final asPrimary = isPrimaryCompactTab(AppPage.nodes);
    final noPlan =
        ctrl.hasAccountSummary && !ctrl.isInitialLoading && !ctrl.hasPlan;

    return RefreshIndicator(
      onRefresh: _handleRefresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (asPrimary)
                  CompactPageHeader(
                    title: context.l10n.nodes,
                    subtitle: context.l10n.selectLineAndLatency,
                  )
                else
                  Row(
                    children: [
                      PageBackButton(
                        onTap: () => ctrl.goToPage(AppPage.dashboard),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.l10n.nodes,
                              style: AppTextStyles.pageTitle.copyWith(
                                color: c.textPrimary,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              context.l10n.selectLineAndLatency,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.caption.copyWith(
                                color: c.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: AppSpacing.lg),
                if (noPlan)
                  NoPlanCard(
                    onPurchase: isPageEnabled(AppPage.shop)
                        ? () => ctrl.goToPage(AppPage.shop)
                        : null,
                  )
                else ...[
                  Row(
                    children: [
                      Expanded(
                        child: SearchInput(
                          hintText: context.l10n.searchNodes,
                          onChanged: _onSearchChanged,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      _LatencyTestButton(ctrl: ctrl),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _AutoSelectSurface(
                    ctrl: ctrl,
                    selected: autoSelected,
                    onTap: _toggleAutoSelect,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  FilterTabs(
                    tabs: _tabs(context),
                    selectedIndex: _tab,
                    onSelected: (index) => setState(() => _tab = index),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
              ],
            ),
          ),
          if (!noPlan)
            if (nodes.isEmpty)
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
                itemCount: nodes.length,
                itemBuilder: (_, index) {
                  final node = nodes[index];
                  return _CompactNodeCard(
                    node: node,
                    selected: !autoSelected && node.id == selectedId,
                    favorite: _favorites.contains(node.id),
                    onTap: () => _selectNode(node),
                    onToggleFavorite: () => _toggleFavorite(node.id),
                  );
                },
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AppSpacing.sm),
              ),
        ],
      ),
    );
  }
}

class _AutoSelectSurface extends StatelessWidget {
  const _AutoSelectSurface({
    required this.ctrl,
    required this.selected,
    required this.onTap,
  });

  final AppController ctrl;
  final bool selected;
  final VoidCallback onTap;

  NodeModel? _bestNode() {
    NodeModel? best;
    for (final node in ctrl.nodes) {
      if (node.latency <= 0 || node.latency >= 9999) continue;
      if (best == null || node.latency < best.latency) best = node;
    }
    return best;
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final best = _bestNode();
    final minHeight = AppPlatform.isDesktop ? 60.0 : 68.0;

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
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? c.primary : c.surfaceMuted,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(
                  LucideIcons.zap,
                  size: 17,
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
                      best == null
                          ? context.l10n.autoSelectBestDescription
                          : best.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption.copyWith(color: c.textMuted),
                    ),
                  ],
                ),
              ),
              if (best != null) ...[
                CountryFlag.fromCountryCode(
                  best.code.isNotEmpty ? best.code : 'UN',
                  theme: const ImageTheme(
                    width: 22,
                    height: 16,
                    shape: RoundedRectangle(3),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                NodeLatency(
                  latency: best.latency,
                  style: NodeLatencyStyle.badge,
                ),
                const SizedBox(width: AppSpacing.sm),
              ],
              if (selected)
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: c.primary,
                    shape: BoxShape.circle,
                  ),
                )
              else
                Icon(LucideIcons.chevronRight, size: 17, color: c.iconMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _LatencyTestButton extends StatefulWidget {
  const _LatencyTestButton({required this.ctrl, this.showLabel = false});

  final AppController ctrl;
  final bool showLabel;

  @override
  State<_LatencyTestButton> createState() => _LatencyTestButtonState();
}

class _LatencyTestButtonState extends State<_LatencyTestButton> {
  bool _loading = false;

  Future<void> _onTap() async {
    if (_loading) return;
    if (widget.ctrl.nodes.isEmpty) {
      AppToast.show(context, context.l10n.noTestableNodes);
      return;
    }
    setState(() => _loading = true);
    final success = await widget.ctrl.testLatencies();
    if (!mounted) return;
    setState(() => _loading = false);
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
    if (widget.showLabel) {
      return AppButton(
        label: context.l10n.latencyTest,
        onPressed: _onTap,
        loading: _loading,
        leadingIcon: LucideIcons.gauge,
        variant: AppButtonVariant.outline,
      );
    }

    return AppIconButton(
      icon: LucideIcons.gauge,
      onPressed: _onTap,
      loading: _loading,
      tooltip: context.l10n.latencyTest,
      variant: AppIconButtonVariant.surface,
    );
  }
}

class _DesktopNodeTable extends StatelessWidget {
  const _DesktopNodeTable({
    required this.nodes,
    required this.selectedId,
    required this.autoSelected,
    required this.favorites,
    required this.onSelect,
    required this.onToggleFavorite,
  });

  final List<NodeModel> nodes;
  final String selectedId;
  final bool autoSelected;
  final Set<String> favorites;
  final ValueChanged<NodeModel> onSelect;
  final ValueChanged<String> onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final height = (MediaQuery.sizeOf(context).height - 330)
        .clamp(260.0, 900.0)
        .toDouble();

    return Container(
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: c.cardBg,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: c.softBorder),
      ),
      child: ListView.separated(
        primary: false,
        padding: EdgeInsets.zero,
        itemCount: nodes.length,
        itemBuilder: (_, index) {
          final node = nodes[index];
          return _DesktopNodeRow(
            node: node,
            selected: !autoSelected && node.id == selectedId,
            favorite: favorites.contains(node.id),
            onTap: () => onSelect(node),
            onToggleFavorite: () => onToggleFavorite(node.id),
          );
        },
        separatorBuilder: (_, _) => Divider(
          height: 1,
          indent: AppSpacing.lg,
          endIndent: AppSpacing.lg,
          color: c.softBorder,
        ),
      ),
    );
  }
}

class _DesktopNodeRow extends StatefulWidget {
  const _DesktopNodeRow({
    required this.node,
    required this.selected,
    required this.favorite,
    required this.onTap,
    required this.onToggleFavorite,
  });

  final NodeModel node;
  final bool selected;
  final bool favorite;
  final VoidCallback onTap;
  final VoidCallback onToggleFavorite;

  @override
  State<_DesktopNodeRow> createState() => _DesktopNodeRowState();
}

class _DesktopNodeRowState extends State<_DesktopNodeRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final node = widget.node;
    final code = node.code.isNotEmpty ? node.code : 'UN';
    final background = widget.selected
        ? c.primarySoft
        : _hovered
        ? c.surfaceMuted
        : Colors.transparent;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Material(
        color: background,
        child: InkWell(
          onTap: widget.onTap,
          child: SizedBox(
            height: 60,
            child: Row(
              children: [
                AnimatedContainer(
                  duration: AppMotion.fast,
                  width: 3,
                  height: widget.selected ? 32 : 0,
                  decoration: BoxDecoration(
                    color: c.primary,
                    borderRadius: const BorderRadius.horizontal(
                      right: Radius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                SizedBox(
                  width: 34,
                  child: Center(
                    child: CountryFlag.fromCountryCode(
                      code,
                      theme: const ImageTheme(
                        width: 26,
                        height: 18,
                        shape: RoundedRectangle(3),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  flex: 4,
                  child: Text(
                    node.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyStrong.copyWith(
                      color: widget.selected ? c.primary : c.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  flex: 3,
                  child: Text(
                    node.englishName.isEmpty ? code : node.englishName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(color: c.textMuted),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                SizedBox(
                  width: 78,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: NodeLatency(
                      latency: node.latency,
                      style: NodeLatencyStyle.badge,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                AppIconButton(
                  icon: LucideIcons.star,
                  onPressed: widget.onToggleFavorite,
                  tooltip: context.l10n.favorites,
                  compact: true,
                  variant: widget.favorite
                      ? AppIconButtonVariant.primary
                      : AppIconButtonVariant.ghost,
                ),
                SizedBox(
                  width: 30,
                  child: Center(
                    child: widget.selected
                        ? Container(
                            width: 9,
                            height: 9,
                            decoration: BoxDecoration(
                              color: c.primary,
                              shape: BoxShape.circle,
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CompactNodeCard extends StatelessWidget {
  const _CompactNodeCard({
    required this.node,
    required this.selected,
    required this.favorite,
    required this.onTap,
    required this.onToggleFavorite,
  });

  final NodeModel node;
  final bool selected;
  final bool favorite;
  final VoidCallback onTap;
  final VoidCallback onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final code = node.code.isNotEmpty ? node.code : 'UN';

    return AppCard(
      padding: EdgeInsets.zero,
      radius: AppRadius.card,
      color: selected ? c.primarySoft : c.cardBg,
      shadow: AppCardShadow.none,
      borderColor: selected ? c.primary : c.softBorder,
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 72),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.sm,
            AppSpacing.sm,
          ),
          child: Row(
            children: [
              CountryFlag.fromCountryCode(
                code,
                theme: const ImageTheme(
                  width: 28,
                  height: 20,
                  shape: RoundedRectangle(3),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      node.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodyStrong.copyWith(
                        color: selected ? c.primary : c.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      node.englishName.isEmpty ? code : node.englishName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption.copyWith(color: c.textMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              NodeLatency(
                latency: node.latency,
                style: NodeLatencyStyle.badge,
              ),
              AppIconButton(
                icon: LucideIcons.star,
                onPressed: onToggleFavorite,
                tooltip: context.l10n.favorites,
                variant: favorite
                    ? AppIconButtonVariant.primary
                    : AppIconButtonVariant.ghost,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
