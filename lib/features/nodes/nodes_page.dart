import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../app/nav_destinations.dart';
import '../../l10n/l10n.dart';
import '../../shared/models/app_models.dart';
import '../../shared/services/node_filter.dart';
import '../../shared/services/settings_service.dart';
import '../../shared/widgets/app_toast.dart';
import 'widgets/greenfield_nodes_browser.dart';

class NodesPage extends StatefulWidget {
  const NodesPage({super.key});

  @override
  State<NodesPage> createState() => _NodesPageState();
}

class _NodesPageState extends State<NodesPage> {
  NodeFilterTab _filter = NodeFilterTab.all;
  String _query = '';
  String _pendingQuery = '';
  String? _selectedId;
  Set<String> _favorites = {};
  Timer? _searchDebounce;
  bool _testingLatencies = false;

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

  List<NodeModel> get _filtered => NodeFilter.apply(
        nodes: AppScope.of(context).nodes,
        query: _query,
        tab: _filter,
        favorites: _favorites,
      );

  Future<void> _handleRefresh() async {
    await _runLatencyTest(showToast: false);
    await _loadFavorites();
    if (!mounted) return;
    AppToast.show(
      context,
      context.l10n.refreshed,
      type: AppToastType.success,
    );
  }

  Future<void> _runLatencyTest({bool showToast = true}) async {
    if (_testingLatencies) return;
    final ctrl = AppScope.of(context);
    if (ctrl.nodes.isEmpty) {
      if (showToast) AppToast.show(context, context.l10n.noTestableNodes);
      return;
    }

    setState(() => _testingLatencies = true);
    final success = await ctrl.testLatencies();
    if (!mounted) return;
    setState(() => _testingLatencies = false);

    if (showToast) {
      AppToast.show(
        context,
        success
            ? context.l10n.latencyTestComplete
            : context.l10n.latencyTestFailed,
        type: success ? AppToastType.success : AppToastType.warning,
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
    final ctrl = AppScope.of(context);
    final noPlan =
        ctrl.hasAccountSummary && !ctrl.isInitialLoading && !ctrl.hasPlan;
    final selectedId = ctrl.autoSelected
        ? null
        : (_selectedId?.isNotEmpty == true ? _selectedId : ctrl.currentNode.id);

    return GreenfieldNodesBrowser(
      key: const ValueKey('greenfield-nodes-browser'),
      allNodes: ctrl.nodes,
      visibleNodes: _filtered,
      currentNode: ctrl.currentNode,
      selectedNodeId: selectedId,
      autoSelected: ctrl.autoSelected,
      favorites: _favorites,
      selectedFilter: _filter,
      testingLatencies: _testingLatencies,
      noPlan: noPlan,
      onSearchChanged: _onSearchChanged,
      onFilterChanged: (filter) => setState(() => _filter = filter),
      onAutoSelect: () => _toggleAutoSelect(),
      onSelectNode: (node) => _selectNode(node),
      onToggleFavorite: _toggleFavorite,
      onLatencyTest: () => _runLatencyTest(),
      onRefresh: _handleRefresh,
      onPurchase: isPageEnabled(AppPage.shop)
          ? () => ctrl.goToPage(AppPage.shop)
          : null,
    );
  }
}
