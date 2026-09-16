import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../shared/models/app_models.dart';
import '../theme/v3_palette.dart';
import '../ui/v3_components.dart';
import 'v3_sheet.dart';

/// Pick a node without leaving the page you are on.
///
/// The rows below are the nodes page's own, lifted out of it rather than
/// rewritten: 切换节点 on the dashboard used to navigate to that page, which
/// meant leaving the connect workspace — and the connection state you were
/// looking at — just to change one setting, then navigating back. The list
/// already knew how to say which node is chosen; only the container changed.
class V3NodePicker extends StatefulWidget {
  const V3NodePicker({super.key});

  static Future<void> show(BuildContext context) => showV3Sheet<void>(
    context,
    title: '切换节点',
    builder: (_) => const V3NodePicker(),
  );

  @override
  State<V3NodePicker> createState() => _V3NodePickerState();
}

class _V3NodePickerState extends State<V3NodePicker> {
  String _query = '';
  String? _pending;

  /// Switches to [id], then closes — on success only.
  ///
  /// A failure keeps the sheet open, because the reason to stay is to pick a
  /// different node. Reporting it in a snack bar over a sheet that had already
  /// closed would leave the user looking at the page they started on, with no
  /// sign of what went wrong beyond a message that fades.
  Future<void> _select(
    String id,
    Future<String?> Function() action,
    String success,
  ) async {
    if (_pending != null) return;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _pending = id);
    String? error;
    try {
      error = await action();
    } catch (_) {
      error = '操作失败，请检查网络后重试。';
    }
    // The sheet may have been dismissed while the request was in flight; the
    // navigator captured above would then pop the page underneath it.
    if (!mounted) return;
    messenger.showSnackBar(SnackBar(content: Text(error ?? success)));
    if (error == null) {
      navigator.pop();
    } else {
      setState(() => _pending = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final query = _query.trim().toLowerCase();
    final nodes = controller.nodes
        .where(
          (node) =>
              query.isEmpty ||
              node.name.toLowerCase().contains(query) ||
              node.englishName.toLowerCase().contains(query) ||
              node.code.toLowerCase().contains(query),
        )
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          autofocus: true,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search_rounded),
            hintText: '搜索国家、城市或节点名称',
          ),
          onChanged: (value) => setState(() => _query = value),
        ),
        const SizedBox(height: 16),
        V3AutoRouteRow(
          controller: controller,
          busy: _pending == 'auto',
          onTap: _pending != null || controller.autoSelected
              ? null
              : () => _select(
                  'auto',
                  controller.selectAuto,
                  '已选择自动节点，请在连接页确认连接状态。',
                ),
        ),
        const SizedBox(height: 12),
        if (nodes.isEmpty)
          V3Panel(
            padding: const EdgeInsets.all(28),
            child: Text(
              controller.nodes.isEmpty ? '暂无可用节点，请刷新订阅后重试。' : '没有匹配的节点，请调整搜索。',
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
                onTap:
                    _pending != null ||
                        (!controller.autoSelected &&
                            controller.currentNode.id == node.id)
                    ? null
                    : () => _select(
                        node.id,
                        () => controller.setCurrentNode(node),
                        '已选择 ${node.name}，请在连接页确认连接状态。',
                      ),
              ),
            ),
      ],
    );
  }
}

/// The "let the app decide" row, above the list of nodes.
class V3AutoRouteRow extends StatelessWidget {
  const V3AutoRouteRow({
    super.key,
    required this.controller,
    required this.onTap,
    required this.busy,
  });

  final AppController controller;
  final VoidCallback? onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    final active = controller.autoSelected;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          // The same chosen-card treatment [V3NodeRow] below uses, so the two
          // rows in this list do not disagree about what "selected" looks like.
          color: active ? p.lycheeSoft : p.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: active ? p.lychee : p.line),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: active ? p.citrus : p.surfaceRaised,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(
                Icons.auto_awesome_rounded,
                color: active ? p.night : p.ink,
                size: 19,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '自动选择',
                    style: TextStyle(
                      color: p.ink,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '自动选择可用节点',
                    style: TextStyle(color: p.inkMuted, fontSize: 11),
                  ),
                ],
              ),
            ),
            if (busy)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else if (active)
              // The check is the only thing saying which row is chosen, so it
              // owes the 3:1 a UI shape is held to — and the base lychee on the
              // row's own soft fill is 2.8:1.
              Icon(Icons.check_circle_rounded, color: p.lycheeInk, size: 20),
          ],
        ),
      ),
    );
  }
}

/// One node: flag, names, latency, and whether it is the chosen one.
class V3NodeRow extends StatelessWidget {
  const V3NodeRow({
    super.key,
    required this.node,
    required this.controller,
    required this.onTap,
    required this.busy,
  });

  final NodeModel node;
  final AppController controller;
  final VoidCallback? onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    final selected =
        !controller.autoSelected && controller.currentNode.id == node.id;
    // The Ink variants: this drives the latency label as well as the status dot,
    // and the label is small text that has to clear AA on a light ground.
    final latencyColor = node.latency > 0 && node.latency <= 120
        ? p.successInk
        : node.latency > 120 && node.latency < 9999
        ? p.warningInk
        : p.inkMuted;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? p.lycheeSoft : p.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? p.lychee : p.line),
        ),
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
                ],
              ),
            ),
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: latencyColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 7),
            Text(
              v3LatencyLabel(node.latency),
              style: TextStyle(
                color: latencyColor,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 12),
            if (busy)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.chevron_right_rounded,
                color: selected ? p.lycheeInk : p.inkMuted,
                size: 19,
              ),
          ],
        ),
      ),
    );
  }
}

String v3LatencyLabel(int value) {
  if (value == -1) return '测速中';
  if (value <= 0) return '未测速';
  if (value >= 9999) return '超时';
  return '${value}ms';
}
