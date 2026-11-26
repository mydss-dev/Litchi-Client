import 'package:material_ui/material_ui.dart';

import '../../app/app_controller.dart';
import '../../app/core_controller.dart';
import '../../shared/models/app_models.dart';
import '../theme/v3_palette.dart';
import '../theme/v3_motion.dart';
import 'v3_bottom_dock.dart';
import 'v3_components.dart';
import 'v3_empty_state.dart';
import 'v3_node_picker.dart';
import 'v3_locale_copy.dart';
import 'v3_mobile_components.dart';
import 'v3_latency_tier.dart';
import 'v3_node_tags.dart';
import 'v3_toast.dart';
import '../../shared/theme/app_icons.dart';

/// Phone "Select a node" screen — the reference's dot-free list design:
/// a large heading, a capsule search with round utility buttons, one card per
/// node with a circular flag and a radio tick for the active one, and a
/// floating connect pill above the dock.
///
/// Business operations stay in V3NodesPage; this widget only paints and
/// forwards callbacks.
class V3HtmlPhoneNodes extends StatelessWidget {
  const V3HtmlPhoneNodes({
    super.key,
    required this.controller,
    required this.nodes,
    required this.total,
    required this.regions,
    required this.search,
    required this.onQuery,
    required this.region,
    required this.onRegion,
    required this.onTest,
    required this.onTestNode,
    required this.onSelect,
    required this.onSelectAuto,
    required this.pendingId,
    required this.testingNodeId,
  });

  final AppController controller;
  final List<NodeModel> nodes;
  final int total;
  final int regions;
  final TextEditingController search;
  final ValueChanged<String> onQuery;
  final NodeRegion? region;
  final ValueChanged<NodeRegion?> onRegion;
  final VoidCallback onTest;
  final ValueChanged<String> onTestNode;
  final ValueChanged<NodeModel> onSelect;
  final VoidCallback onSelectAuto;
  final String? pendingId;
  final String? testingNodeId;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    final hasQuery = search.text.isNotEmpty;
    final filtered = search.text.trim().isNotEmpty || region != null;
    void clearSearch() {
      search.clear();
      onQuery('');
    }

    final filters = <(NodeRegion?, String)>[
      (null, v3Copy(context, zh: '全部', en: 'All', tw: '全部')),
      (NodeRegion.asia, v3Copy(context, zh: '亚洲', en: 'Asia', tw: '亞洲')),
      (NodeRegion.europe, v3Copy(context, zh: '欧洲', en: 'Europe', tw: '歐洲')),
      (NodeRegion.america, v3Copy(context, zh: '美洲', en: 'Americas', tw: '美洲')),
    ];

    Widget roundButton({
      required String heroKey,
      required String tooltip,
      required VoidCallback? onTap,
      required Widget child,
    }) {
      return Semantics(
        button: true,
        label: tooltip,
        child: Material(
          color: V3MobileDesign.card(context),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(99),
            side: BorderSide(color: V3MobileDesign.stroke(context)),
          ),
          child: InkWell(
            key: ValueKey(heroKey),
            onTap: onTap,
            borderRadius: BorderRadius.circular(99),
            child: SizedBox(width: 46, height: 46, child: child),
          ),
        ),
      );
    }

    final scroll = SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: V3MobileDesign.pageInsets.copyWith(
        bottom: V3MobileDesign.dockClearance + 64),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        V3PrimaryPageHeader(
          title: v3Copy(context, zh: '选择节点', en: 'Select a node',
            tw: '選擇節點'),
          subtitle: v3Copy(context, zh: '选择最适合你的地区',
            en: 'Pick the region that fits you best',
            tw: '選擇最適合你的地區'),
        ),
        const SizedBox(height: 20),
        Row(children: [
          Expanded(
            child: Container(
              height: 46,
              decoration: BoxDecoration(
                color: V3MobileDesign.card(context),
                border: Border.all(color: V3MobileDesign.stroke(context)),
                borderRadius: BorderRadius.circular(99),
              ),
              child: TextField(
                controller: search,
                onChanged: onQuery,
                textInputAction: TextInputAction.search,
                style: TextStyle(color: p.ink, fontSize: 13),
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.only(top: 13),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  prefixIcon: Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Icon(AppIcons.search, color: p.inkMuted, size: 18),
                  ),
                  suffixIcon: hasQuery
                      ? IconButton(
                          key: const ValueKey('v3-node-clear-search'),
                          tooltip: v3Copy(context, zh: '清除搜索',
                            en: 'Clear search', tw: '清除搜尋'),
                          onPressed: clearSearch,
                          icon: const Icon(AppIcons.close, size: 18),
                        )
                      : null,
                  hintText: v3Copy(context, zh: '搜索节点',
                    en: 'Search nodes', tw: '搜尋節點'),
                  hintStyle: TextStyle(color: p.inkMuted,
                    fontWeight: FontWeight.w500, fontSize: 13),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          PopupMenuButton<NodeRegion?>(
            key: const ValueKey('v3-node-region-filter'),
            color: V3MobileDesign.card(context),
            elevation: 8,
            position: PopupMenuPosition.under,
            offset: const Offset(0, 6),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(V3Radius.field),
              side: BorderSide(color: V3MobileDesign.stroke(context)),
            ),
            onSelected: onRegion,
            itemBuilder: (context) => [
              for (final (value, label) in filters)
                PopupMenuItem<NodeRegion?>(
                  key: ValueKey(value == null
                      ? 'v3-map-country-all' : 'v3-region-$value'),
                  value: value,
                  child: Row(children: [
                    Expanded(child: Text(label,
                      style: TextStyle(color: p.ink, fontSize: 13))),
                    if (region == value)
                      Icon(AppIcons.check, size: 16, color: p.aquaInk),
                  ]),
                ),
            ],
            child: roundButton(
              heroKey: 'v3-node-filter-button',
              tooltip: v3Copy(context, zh: '按地区筛选', en: 'Filter by region',
                tw: '依地區篩選'),
              onTap: null,
              child: Icon(AppIcons.sliders, size: 18, color: p.ink),
            ),
          ),
          const SizedBox(width: 8),
          roundButton(
            heroKey: 'v3-node-refresh',
            tooltip: v3Copy(context, zh: '刷新节点', en: 'Refresh nodes',
              tw: '重新整理節點'),
            onTap: controller.isInitialLoading ? null : controller.refreshData,
            child: controller.isInitialLoading
                ? SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2,
                      color: p.lycheeInk))
                : Icon(AppIcons.refresh, size: 18, color: p.ink),
          ),
          const SizedBox(width: 8),
          roundButton(
            heroKey: 'v3-overview-speed-test',
            tooltip: v3Copy(context, zh: '全部测速', en: 'Test all',
              tw: '全部測速'),
            onTap: controller.isLatencyTesting || testingNodeId != null
                ? null : onTest,
            child: controller.isLatencyTesting
                ? SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2,
                      color: p.lycheeInk))
                : Icon(AppIcons.zap, size: 18, color: p.ink),
          ),
        ]),
        const SizedBox(height: 18),
        Material(
          color: controller.autoSelected
              ? p.aqua.withValues(alpha: .10)
              : V3MobileDesign.card(context),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(V3Radius.card),
            side: controller.autoSelected
                ? BorderSide(color: p.aqua.withValues(alpha: .45), width: 1.2)
                : BorderSide(color: V3MobileDesign.stroke(context)),
          ),
          child: InkWell(
            key: const ValueKey('v3-mobile-auto-node'),
            borderRadius: BorderRadius.circular(V3Radius.card),
            onTap: controller.autoSelected || pendingId != null
                ? null : onSelectAuto,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(children: [
                Container(
                  height: 40, width: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: p.surfaceRaised,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(AppIcons.sparkles,
                    color: p.lycheeInk, size: 19),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(v3Copy(context, zh: '自动选择节点',
                        en: 'Automatic selection', tw: '自動選擇節點'),
                      style: TextStyle(color: p.ink,
                        fontSize: 14, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 3),
                    Text(v3Copy(context, zh: '由系统选择合适线路',
                        en: 'Let the app select a route',
                        tw: '由系統選擇合適線路'),
                      style: TextStyle(color: p.inkMuted, fontSize: 11)),
                  ],
                )),
                if (controller.autoSelected)
                  Icon(AppIcons.check, color: p.aquaInk, size: 19),
              ]),
            ),
          ),
        ),
        const SizedBox(height: 14),
        if (controller.isInitialLoading)
          for (var i = 0; i < 3; i++)
            const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: V3NodeSkeletonRow())
        else if (controller.dataLoadError != null && total == 0)
          V3EmptyState(
            icon: AppIcons.error,
            title: v3Copy(context, zh: '节点同步失败',
              en: 'Could not load nodes', tw: '節點同步失敗'),
            subtitle: controller.dataLoadError!,
            actionLabel: v3Copy(context, zh: '重试',
              en: 'Retry', tw: '重試'),
            onAction: controller.refreshData,
          )
        else if (nodes.isEmpty)
          V3EmptyState(
            icon: AppIcons.searchOff,
            title: filtered
                ? v3Copy(context, zh: '没有匹配的节点',
                    en: 'No matching nodes', tw: '沒有符合的節點')
                : v3Copy(context, zh: '暂无可用节点',
                    en: 'No nodes available', tw: '暫無可用節點'),
            subtitle: filtered
                ? v3Copy(context, zh: '试试其他关键词或地区。',
                    en: 'Try another search or region.', tw: '試試其他關鍵字或地區。')
                : v3Copy(context, zh: '刷新后再试一次。',
                    en: 'Refresh to try again.', tw: '重新整理後再試一次。'),
            actionLabel: filtered
                ? v3Copy(context, zh: '清除筛选', en: 'Reset filters', tw: '清除篩選')
                : v3Copy(context, zh: '刷新节点', en: 'Refresh nodes', tw: '重新整理節點'),
            onAction: filtered ? () {
              clearSearch();
              onRegion(null);
            } : controller.refreshData,
          )
        else ...[
          if (filtered) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(2, 0, 2, 10),
              child: Text(v3Copy(context,
                zh: '${nodes.length} 个匹配节点',
                en: '${nodes.length} matching nodes',
                tw: '${nodes.length} 個符合的節點'),
                style: TextStyle(color: p.inkMuted, fontSize: 12)),
            ),
          ],
          for (final node in nodes)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _HtmlNodeRow(
                node: node,
                selected: !controller.autoSelected &&
                  controller.currentNode.id == node.id,
                blocked: pendingId != null,
                pending: pendingId == node.id,
                testing: testingNodeId == node.id ||
                  (controller.isLatencyTesting && testingNodeId == null),
                canTest: pendingId == null &&
                  !controller.isLatencyTesting && testingNodeId == null,
                onTap: () => onSelect(node),
                onTest: () => onTestNode(node.id),
              ),
            ),
        ],
      ]),
    );
    return V3MobileBackdrop(
      child: Stack(children: [
        scroll,
        Positioned(
          left: V3MobileDesign.pageInset,
          right: V3MobileDesign.pageInset,
          bottom: V3BottomDock.height + 14,
          child: _NodesConnectButton(controller: controller),
        ),
      ]),
    );
  }
}

/// The floating connect state pill. Same semantics and tone as the dashboard
/// action; the visible label is the connection *state*, the spoken label the
/// *action*, so a screen reader still knows what a tap will do.
class _NodesConnectButton extends StatelessWidget {
  const _NodesConnectButton({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    final status = controller.connectionStatus;
    final busy = status == ConnectionStatus.connecting ||
        status == ConnectionStatus.disconnecting;
    final connected = status == ConnectionStatus.connected;
    final locked = controller.connectionActionLocked;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final tone = connected ? p.success : p.lychee;
    final foreground = busy ? p.ink : (dark ? p.onLychee : Colors.white);
    final spoken = connected
        ? v3Copy(context, zh: '断开连接', en: 'Disconnect', tw: '中斷連線')
        : v3Copy(context, zh: '立即连接', en: 'Connect', tw: '立即連線');
    final visible = busy
        ? v3Copy(context, zh: '连接处理中', en: 'Processing', tw: '連線處理中')
        : connected
            ? v3Copy(context, zh: '已连接', en: 'Connected', tw: '已連線')
            : v3Copy(context, zh: '未连接', en: 'Not connected', tw: '未連線');

    Future<void> runToggle() async {
      final error = await controller.toggleConnection();
      if (error == null && context.mounted &&
          controller.connectionStatus == ConnectionStatus.connected) {
        V3Toast.show(context, v3Copy(context,
            zh: '连接成功', en: 'Connected', tw: '連線成功'),
            type: V3ToastType.success);
      }
    }

    return Semantics(
      button: true,
      enabled: !locked,
      label: spoken,
      child: Center(
        child: AnimatedContainer(
          duration: v3ReducedMotion(context) ? Duration.zero : V3Motion.fast,
          width: 220,
          height: 46,
          decoration: BoxDecoration(
            gradient: busy ? null : LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color.lerp(tone, Colors.white, .18)!, tone],
            ),
            color: busy ? p.surfaceRaised : null,
            borderRadius: BorderRadius.circular(99),
            border: busy ? Border.all(color: p.line) : null,
            boxShadow: busy ? null : [
              BoxShadow(color: tone.withValues(alpha: dark ? .28 : .32),
                blurRadius: 16, offset: const Offset(0, 6)),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              key: const ValueKey('v3-nodes-connect-pill'),
              onTap: locked ? null : runToggle,
              borderRadius: BorderRadius.circular(99),
              child: Center(
                child: busy
                    ? SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2, color: p.warningInk))
                    : Row(
                        key: ValueKey('v3-nodes-connect-${connected ? 'on' : 'off'}'),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(connected ? AppIcons.check : AppIcons.power,
                            size: 17, color: foreground),
                          const SizedBox(width: 8),
                          Text(visible,
                            style: TextStyle(color: foreground,
                              fontSize: 15, fontWeight: FontWeight.w700)),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HtmlNodeRow extends StatelessWidget {
  const _HtmlNodeRow({
    required this.node, required this.selected,
    required this.blocked, required this.pending,
    required this.testing, required this.canTest, required this.onTap,
    required this.onTest,
  });

  final NodeModel node;
  final bool selected;
  final bool blocked;
  final bool pending;
  final bool testing;
  final bool canTest;
  final VoidCallback onTap;
  final VoidCallback onTest;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return Material(
      color: selected ? p.aqua.withValues(alpha: .09) : V3MobileDesign.card(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(V3Radius.card),
        side: selected
            ? BorderSide(color: p.aqua.withValues(alpha: .45), width: 1.2)
            : BorderSide(color: V3MobileDesign.stroke(context)),
      ),
      child: InkWell(
        key: ValueKey('v3-html-node-${node.id}'),
        borderRadius: BorderRadius.circular(V3Radius.card),
        onTap: blocked || selected ? null : onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 72),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
            child: Row(children: [
              Container(
                height: 40, width: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? p.surface : p.surfaceRaised,
                  shape: BoxShape.circle,
                ),
                child: V3NodeFlag(code: node.code),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(node.name, maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: p.ink,
                      fontSize: 14, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  if (node.tags.isNotEmpty)
                    V3NodeTags(
                      tags: node.tags, maxVisible: 2,
                      chipMaxWidth: 60, showOverflow: false)
                  else if (node.englishName.isNotEmpty)
                    Text(node.englishName, maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: p.inkMuted, fontSize: 11)),
                ],
              )),
              const SizedBox(width: 6),
              if (selected)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Icon(AppIcons.check, size: 19, color: p.aquaInk),
                ),
              // Untested: outline bolt. Testing: spinner. Result: the shared
              // region-aware latency capsule. The same hit area retests.
              SizedBox(
                width: 72, height: 44,
                child: TextButton(
                  key: ValueKey('v3-node-latency-${node.id}'),
                  onPressed: canTest ? onTest : null,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    foregroundColor: p.inkMuted,
                    minimumSize: const Size(48, 44)),
                  child: AnimatedSwitcher(
                    duration: V3Motion.fast,
                    switchInCurve: Curves.easeOut,
                    switchOutCurve: Curves.easeIn,
                    child: testing
                      ? SizedBox(
                          key: const ValueKey('v3-node-speed-loading'),
                          width: 18, height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2, color: p.lycheeInk))
                      : node.latency <= 0
                        ? Icon(AppIcons.zap,
                            key: const ValueKey('v3-node-speed-untested'),
                            size: 21, color: p.inkMuted)
                        : V3LatencyBadge(
                            key: ValueKey('v3-node-speed-result-${node.id}'),
                            region: node.region, latency: node.latency),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
