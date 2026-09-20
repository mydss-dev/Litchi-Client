import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../theme/v3_palette.dart';
import '../ui/v3_components.dart';
import '../ui/v3_locale_copy.dart';
import '../ui/v3_node_coverage_map.dart';
import '../ui/v3_node_picker.dart';
import '../ui/v3_toast.dart';

/// The node overview: explore the fleet, filter by region, search, test
/// latency and switch. It is the deep-dive view over the same controller
/// state as the dashboard's quick switcher, so the two stay in sync — the
/// overview is where you browse carefully, the dashboard is where you
/// connect.
class V3NodesPage extends StatefulWidget {
  const V3NodesPage({super.key});

  @override
  State<V3NodesPage> createState() => _V3NodesPageState();
}

class _V3NodesPageState extends State<V3NodesPage> {
  String _query = '';
  String? _region;
  bool _latencyFirst = false;
  String? _pending;

  Future<void> _testLatencies() async {
    final controller = AppScope.read(context);
    if (controller.isLatencyTesting || controller.nodes.isEmpty) return;
    final overlay = Overlay.of(context, rootOverlay: true);
    final failureText = v3Copy(context,
      zh: '测速失败或所有节点超时',
      en: 'Test failed or all nodes timed out',
      tw: '測速失敗或所有節點逾時');
    final ok = await controller.testLatencies();
    if (!ok && mounted) {
      V3Toast.showInOverlay(overlay, failureText, type: V3ToastType.warning);
    }
  }

  Future<void> _select(
    String id,
    Future<String?> Function() action,
    String success,
  ) async {
    if (_pending != null) return;
    final overlay = Overlay.of(context, rootOverlay: true);
    // Resolve locale before awaiting. A failed request must not use a stale context.
    final failureMessage = v3Copy(context,
      zh: '操作失败，请检查网络后重试。',
      en: 'Operation failed. Check your network and retry.',
      tw: '操作失敗，請檢查網路後重試。');
    setState(() => _pending = id);
    String? error;
    try {
      error = await action();
    } catch (_) {
      error = failureMessage;
    }
    if (!mounted) return;
    // Root overlay outlives any navigation, so feedback stays visible.
    V3Toast.showInOverlay(overlay, error ?? success,
      type: error == null ? V3ToastType.success : V3ToastType.error);
    setState(() => _pending = null);
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final p = V3Palette.of(context);
    final query = _query.trim().toLowerCase();
    final all = controller.nodes.where((node) => !node.isAuto).toList();
    final nodes = all
        .where((node) =>
            (_region == null ||
                node.code.trim().toUpperCase() == _region) &&
            (query.isEmpty ||
                node.name.toLowerCase().contains(query) ||
                node.englishName.toLowerCase().contains(query) ||
                node.code.toLowerCase().contains(query) ||
                node.tags.any((tag) => tag.toLowerCase().contains(query))))
        .toList();
    if (_latencyFirst) {
      int rank(int latency) => latency > 0 && latency < 9999
          ? latency
          : latency >= 9999 ? 9999 : 10000;
      nodes.sort((a, b) => rank(a.latency).compareTo(rank(b.latency)));
    }
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 26, 24, 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          V3PageHeader(
            kicker: v3Copy(context, zh: '节点列表', en: 'NODE LIST', tw: '節點列表'),
            title: v3Copy(context, zh: '节点概览', en: 'Node overview', tw: '節點概覽'),
            description: v3Copy(context,
              zh: '查看全球节点分布与延迟，点击节点即可切换。',
              en: 'See node coverage and latency. Tap a node to switch.',
              tw: '查看全球節點分佈與延遲，點擊節點即可切換。'),
          ),
          const SizedBox(height: 18),
          V3NodeCoverageMap(
            nodes: controller.nodes,
            selectedCode: _region,
            onSelected: (code) => setState(() => _region = code),
          ),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: TextField(
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search_rounded),
                hintText: v3Copy(context,
                  zh: '搜索节点', en: 'Search nodes', tw: '搜尋節點')),
              onChanged: (value) => setState(() => _query = value))),
            const SizedBox(width: 10),
            SizedBox(height: 48, child: OutlinedButton.icon(
              key: const Key('v3-overview-speed-test'),
              onPressed: controller.isLatencyTesting ||
                  _pending != null || controller.nodes.isEmpty
                  ? null : _testLatencies,
              icon: controller.isLatencyTesting
                  ? const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.speed_rounded, size: 17),
              label: Text(v3Copy(context, zh: '测速', en: 'Test', tw: '測速')))),
          ]),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: Text(
              v3Copy(context, zh: '节点列表', en: 'Nodes', tw: '節點列表'),
              style: Theme.of(context).textTheme.titleMedium)),
            Text(v3Copy(context,
              zh: '共 ${nodes.length} 个', en: '${nodes.length} total',
              tw: '共 ${nodes.length} 個'),
              style: TextStyle(color: p.inkMuted, fontSize: 11)),
            const SizedBox(width: 12),
            ChoiceChip(
              label: Text(v3Copy(context,
                zh: '延迟优先', en: 'Fastest first', tw: '延遲優先')),
              selected: _latencyFirst, showCheckmark: false,
              side: v3ChipSide(p, selected: _latencyFirst),
              onSelected: (value) =>
                  setState(() => _latencyFirst = value)),
          ]),
          const SizedBox(height: 12),
          if (all.isEmpty)
            V3Panel(
              padding: const EdgeInsets.all(26),
              child: Text(
                v3Copy(context, zh: '暂无节点', en: 'No nodes yet', tw: '暫無節點'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            )
          else ...[
            V3AutoRouteRow(
              controller: controller,
              busy: _pending == 'auto',
              onTap: _pending != null || controller.autoSelected
                  ? null
                  : () => _select('auto', controller.selectAuto, v3Copy(context,
                      zh: '已选择自动节点，请在连接页确认连接状态。',
                      en: 'Automatic node selected. Confirm your connection on the connection page.',
                      tw: '已選擇自動節點，請至連線頁確認連線狀態。')),
            ),
            const SizedBox(height: 8),
            if (nodes.isEmpty)
              V3Panel(
                padding: const EdgeInsets.all(26),
                child: Text(
                  v3Copy(context,
                    zh: '没有匹配的节点，请调整搜索或地区筛选。',
                    en: 'No matching nodes. Change the search or region filter.',
                    tw: '沒有符合的節點，請調整搜尋或地區篩選。'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              )
            else
              for (final node in nodes)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: V3NodeRow(
                    node: node,
                    controller: controller,
                    busy: _pending == node.id,
                    onTap: _pending != null ||
                        (!controller.autoSelected &&
                            controller.currentNode.id == node.id)
                        ? null
                        : () => _select(
                            node.id,
                            () => controller.setCurrentNode(node),
                            v3Copy(context,
                              zh: '已选择 ${node.name}，请在连接页确认连接状态。',
                              en: '${node.name} selected. Confirm your connection on the connection page.',
                              tw: '已選擇 ${node.name}，請至連線頁確認連線狀態。')),
                  ),
                ),
          ],
        ],
      ),
    );
  }
}
