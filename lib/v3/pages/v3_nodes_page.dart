import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../shared/models/app_models.dart';
import '../theme/v3_palette.dart';
import '../ui/v3_layout.dart';
import '../ui/v3_components.dart';
import '../ui/v3_locale_copy.dart';
import '../ui/v3_node_coverage_map.dart';
import '../ui/v3_node_tags.dart';

/// The nodes page is informational. Switching nodes remains on the dashboard.
class V3NodesPage extends StatelessWidget {
  const V3NodesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final p = V3Palette.of(context);
    final nodes = controller.nodes.where((node) => !node.isAuto).toList();
    return SingleChildScrollView(
      padding: V3Layout.pageInsets,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          V3PageHeader(
            kicker: v3Copy(context, zh: '节点列表', en: 'NODE LIST', tw: '節點列表'),
            title: v3Copy(context, zh: '节点概览', en: 'Node overview', tw: '節點概覽'),
          ),
          const SizedBox(height: 18),
          V3NodeCoverageMap(
            nodes: controller.nodes,
            selectedCode: null,
            onSelected: (_) {},
            readOnly: true,
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Text(
                  v3Copy(context, zh: '节点列表', en: 'Nodes', tw: '節點列表'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Text(
                v3Copy(
                  context,
                  zh: '共 ${nodes.length} 个',
                  en: '${nodes.length} total',
                  tw: '共 ${nodes.length} 個',
                ),
                style: TextStyle(color: p.inkMuted, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (nodes.isEmpty)
            V3Panel(
              padding: const EdgeInsets.all(26),
              child: Text(
                v3Copy(context, zh: '暂无节点', en: 'No nodes yet', tw: '暫無節點'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            )
          else
            V3Panel(
              padding: EdgeInsets.zero,
              child: Column(children: [
                for (var index = 0; index < nodes.length; index++) ...[
                  if (index > 0)
                    Divider(color: p.line, height: 1,
                      indent: 16, endIndent: 16),
                  _OverviewNodeRow(
                    node: nodes[index],
                    current: !controller.autoSelected &&
                        controller.currentNode.id == nodes[index].id,
                  ),
                ],
              ]),
            ),
        ],
      ),
    );
  }
}

class _OverviewNodeRow extends StatelessWidget {
  const _OverviewNodeRow({required this.node, required this.current});
  final NodeModel node;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    // Latency is the most recent known test result, not a live uptime feed.
    final statusColor = node.latency >= 9999
        ? p.dangerInk
        : node.latency > 0
        ? p.successInk
        : p.inkMuted;
    final latencyLabel = node.latency == -1
        ? v3Copy(context, zh: '检测中', en: 'Testing', tw: '檢測中')
        : node.latency >= 9999
        ? v3Copy(context, zh: '超时', en: 'Timeout', tw: '逾時')
        : node.latency > 0
        ? '${node.latency}ms'
        : v3Copy(context, zh: '未检测', en: 'Not tested', tw: '未檢測');
    return Padding(
      key: ValueKey('v3-node-overview-${node.id}'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          V3NodeFlag(code: node.code),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  node.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 3),
                Text(
                  node.englishName.isNotEmpty ? node.englishName : node.code,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (node.tags.isNotEmpty) ...[
                  const SizedBox(height: 7),
                  V3NodeTags(tags: node.tags),
                ],
              ],
            ),
          ),
          if (current) ...[
            Text(
              v3Copy(context, zh: '当前', en: 'Current', tw: '目前'),
              style: TextStyle(
                color: p.lycheeInk,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 10),
          ],
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 7),
          Text(
            latencyLabel,
            style: TextStyle(
              color: statusColor,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
