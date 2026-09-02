import 'dart:async';

import 'package:country_flags/country_flags.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/app_controller.dart';
import '../../app/core_platform_support.dart';
import '../../app/nav_destinations.dart';
import '../../l10n/l10n.dart';
import '../../shared/models/app_models.dart';
import '../../shared/services/node_filter.dart';
import '../../shared/services/settings_service.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_radius.dart';
import '../../shared/theme/app_text_styles.dart';
import '../../shared/utils/latency_status.dart';
import '../../shared/widgets/app_toast.dart';
import '../../shared/widgets/filter_tabs.dart';
import '../../shared/widgets/node_latency.dart';
import '../../shared/widgets/no_plan_card.dart';
import '../../shared/widgets/page_header.dart';
import '../../shared/widgets/page_status_cards.dart';
import '../../shared/widgets/search_input.dart';

/// Node selection page.
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

  Future<void> _loadFavorites() async {
    final favs = await SettingsService.loadFavorites();
    if (mounted) setState(() => _favorites = favs);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ctrl = AppScope.of(context);
    _selectedId ??= ctrl.currentNode.id;
  }

  List<NodeModel> get _filtered => NodeFilter.apply(
    nodes: AppScope.of(context).nodes,
    query: _query,
    tab: _selectedTab,
    favorites: _favorites,
  );

  Future<void> _handleRefresh() async {
    await AppScope.of(context).testLatencies();
    await _loadFavorites();
    if (mounted) {
      AppToast.show(
        context,
        context.l10n.refreshed,
        type: AppToastType.success,
      );
    }
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
    return _buildCompact(context);
  }

  // ── Compact (bottom-nav) layout ──────────────────────────────────────────────

  Widget _buildCompact(BuildContext context) {
    final c = AppColors.of(context);
    final ctrl = AppScope.of(context);
    final isAuto = ctrl.autoSelected;
    final effectiveId = isAuto
        ? '__auto__'
        : (_selectedId ?? ctrl.currentNode.id);
    final asPrimary = isPrimaryCompactTab(AppPage.nodes);
    final nodes = _filtered;
    final noPlan =
        ctrl.hasAccountSummary && !ctrl.isInitialLoading && !ctrl.hasPlan;

    return RefreshIndicator(
      onRefresh: _handleRefresh,
      child: CustomScrollView(
        shrinkWrap: CorePlatformSupport.isDesktop,
        physics: CorePlatformSupport.isDesktop
            ? const NeverScrollableScrollPhysics()
            : const AlwaysScrollableScrollPhysics(),
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
                        onTap: () =>
                            AppScope.of(context).goToPage(AppPage.dashboard),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.l10n.nodes,
                              style: AppTextStyles.pageTitle.copyWith(
                                color: c.textPrimary,
                                fontSize: 26,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              context.l10n.selectLineAndLatency,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.caption.copyWith(
                                color: c.textMuted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 16),
                if (noPlan)
                  NoPlanCard(
                    onPurchase: isPageEnabled(AppPage.shop)
                        ? () => ctrl.goToPage(AppPage.shop)
                        : null,
                  )
                else
                  ..._bodyChildren(context),
              ],
            ),
          ),
          if (!noPlan)
            if (nodes.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 48),
                  child: AppEmptyState(
                    icon: LucideIcons.searchX,
                    title: context.l10n.noMatchingNodes,
                    subtitle: context.l10n.tryDifferentNodeFilter,
                  ),
                ),
              )
            else
              // Lazy node cards: only the visible rows are built instead of
              // materializing every card up front (same pattern as node_picker).
              SliverList.separated(
                itemCount: nodes.length,
                itemBuilder: (_, i) => _NodeCard(
                  node: nodes[i],
                  selected: !isAuto && nodes[i].id == effectiveId,
                  favorite: _favorites.contains(nodes[i].id),
                  onTap: () => _selectNode(nodes[i]),
                  onToggleFavorite: () => _toggleFavorite(nodes[i].id),
                ),
                separatorBuilder: (_, _) => const SizedBox(height: 10),
              ),
        ],
      ),
    );
  }

  // ── Shared body ──────────────────────────────────────────────────────────────

  List<Widget> _bodyChildren(BuildContext context) {
    final ctrl = AppScope.of(context);
    final isAuto = ctrl.autoSelected;

    return [
      Row(
        children: [
          Expanded(
            child: SearchInput(
              hintText: context.l10n.searchNodes,
              onChanged: _onSearchChanged,
            ),
          ),
          const SizedBox(width: 12),
          _LatencyTestButton(ctrl: ctrl),
        ],
      ),
      const SizedBox(height: 14),
      _AutoCard(ctrl: ctrl, selected: isAuto, onTap: _toggleAutoSelect),
      const SizedBox(height: 12),
      FilterTabs(
        tabs: [
          context.l10n.all,
          context.l10n.favorites,
          context.l10n.asia,
          context.l10n.europe,
          context.l10n.america,
          context.l10n.oceania,
        ],
        selectedIndex: _tab,
        onSelected: (i) => setState(() => _tab = i),
      ),
      const SizedBox(height: 14),
    ];
  }
}

// ── Smart recommendation card ──────────────────────────────────────────────

class _AutoCard extends StatelessWidget {
  const _AutoCard({
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
    final nodes = ctrl.nodes;
    final tested = nodes
        .where((n) => n.latency > 0 && n.latency < 9999)
        .toList();
    NodeModel? best;
    for (final n in tested) {
      if (best == null || n.latency < best.latency) best = n;
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: selected ? c.primarySoft : null,
            gradient: selected ? null : c.cardGradient,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(
              color: selected ? c.primary : c.softBorder,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: selected
                      ? LinearGradient(
                          colors: [c.primary, c.secondary],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: selected ? null : c.surfaceMuted,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(
                  LucideIcons.zap,
                  size: 16,
                  color: selected ? Colors.white : c.primary,
                ),
              ),
              const SizedBox(width: 12),
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
                    const SizedBox(height: 2),
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
                          Text(
                            '${best.name} · ${best.latency} ms',
                            style: AppTextStyles.caption.copyWith(
                              color: c.textMuted,
                            ),
                          ),
                        ],
                      )
                    else
                      Text(
                        context.l10n.autoSelectBestDescription,
                        style: AppTextStyles.caption.copyWith(
                          color: c.textMuted,
                        ),
                      ),
                  ],
                ),
              ),
              if (tested.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: _bestColor(best?.latency, c).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    best != null ? '${best.latency} ms' : '--',
                    style: AppTextStyles.badge.copyWith(
                      color: _bestColor(best?.latency, c),
                      fontSize: 11,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Color _bestColor(int? ms, AppColors c) {
    return LatencyStatus.color(ms, c);
  }
}

// ── Latency test button ────────────────────────────────────────────────────

class _LatencyTestButton extends StatefulWidget {
  const _LatencyTestButton({required this.ctrl});
  final AppController ctrl;

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
    final c = AppColors.of(context);
    return Tooltip(
      message: context.l10n.latencyTest,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: _onTap,
          child: Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: c.cardBg,
              borderRadius: BorderRadius.circular(AppRadius.user),
              border: Border.all(color: c.softBorder),
            ),
            child: _loading
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(c.primary),
                    ),
                  )
                : Icon(LucideIcons.gauge, size: 18, color: c.iconDefault),
          ),
        ),
      ),
    );
  }
}

// ── Node card ──────────────────────────────────────────────────────────────

class _NodeCard extends StatelessWidget {
  const _NodeCard({
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

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: selected ? c.primarySoft : null,
            gradient: selected ? null : c.cardGradient,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(
              color: selected ? c.primary : c.softBorder,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CountryFlag.fromCountryCode(
                    code,
                    theme: const ImageTheme(
                      width: 28,
                      height: 20,
                      shape: RoundedRectangle(3),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      node.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodyStrong.copyWith(
                        color: selected ? c.primary : c.textPrimary,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: onToggleFavorite,
                    child: Icon(
                      LucideIcons.star,
                      size: 15,
                      color: favorite ? c.warning : c.iconMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              if (node.englishName.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 38),
                  child: Text(
                    node.englishName,
                    style: AppTextStyles.caption.copyWith(
                      color: c.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ),
              const Spacer(),
              NodeLatency(
                latency: node.latency,
                style: NodeLatencyStyle.dot,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
