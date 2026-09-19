import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../shared/models/app_models.dart';
import '../theme/v3_palette.dart';
import '../ui/v3_components.dart';
import 'v3_locale_copy.dart';
import 'v3_sheet.dart';

/// Pick a node without leaving the current page.
class V3NodePicker extends StatefulWidget {
  const V3NodePicker({super.key});

  static Future<void> show(BuildContext context) => showV3Sheet<void>(
    context,
    title: v3Copy(context, zh: '切换节点', en: 'Change node', tw: '切換節點'),
    builder: (_) => const V3NodePicker(),
  );

  @override
  State<V3NodePicker> createState() => _V3NodePickerState();
}

class _V3NodePickerState extends State<V3NodePicker> {
  String _query = '';
  String? _pending;

  Future<void> _select(String id, Future<String?> Function() action,
      String success) async {
    if (_pending != null) return;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
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
    final nodes = controller.nodes.where((node) => query.isEmpty ||
      node.name.toLowerCase().contains(query) ||
      node.englishName.toLowerCase().contains(query) ||
      node.code.toLowerCase().contains(query)).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      TextField(
        autofocus: true,
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.search_rounded),
          hintText: v3Copy(context, zh: '搜索国家、城市或节点名称',
            en: 'Search country, city or node name',
            tw: '搜尋國家、城市或節點名稱'),
        ),
        onChanged: (value) => setState(() => _query = value),
      ),
      const SizedBox(height: 16),
      V3AutoRouteRow(
        controller: controller,
        busy: _pending == 'auto',
        onTap: _pending != null || controller.autoSelected ? null
          : () => _select('auto', controller.selectAuto,
              v3Copy(context,
                zh: '已选择自动节点，请在连接页确认连接状态。',
                en: 'Automatic node selected. Confirm your connection on the connection page.',
                tw: '已選擇自動節點，請至連線頁確認連線狀態。')),
      ),
      const SizedBox(height: 12),
      if (nodes.isEmpty)
        V3Panel(padding: const EdgeInsets.all(28),
          child: Text(controller.nodes.isEmpty
              ? v3Copy(context, zh: '暂无可用节点，请刷新订阅后重试。',
                  en: 'No nodes available. Refresh your subscription and retry.',
                  tw: '暫無可用節點，請重新整理訂閱後再試。')
              : v3Copy(context, zh: '没有匹配的节点，请调整搜索。',
                  en: 'No matching nodes. Change the search.',
                  tw: '沒有符合的節點，請調整搜尋。'),
            style: Theme.of(context).textTheme.bodySmall))
      else for (final node in nodes)
        Padding(padding: const EdgeInsets.only(bottom: 8),
          child: V3NodeRow(node: node, controller: controller,
            busy: _pending == node.id,
            onTap: _pending != null ||
                (!controller.autoSelected && controller.currentNode.id == node.id)
              ? null : () => _select(node.id,
                  () => controller.setCurrentNode(node),
                  v3Copy(context,
                    zh: '已选择 ${node.name}，请在连接页确认连接状态。',
                    en: '${node.name} selected. Confirm your connection on the connection page.',
                    tw: '已選擇 ${node.name}，請至連線頁確認連線狀態。')))),
    ]);
  }
}

/// The "let the app decide" row, above the list of nodes.
class V3AutoRouteRow extends StatelessWidget {
  const V3AutoRouteRow({super.key, required this.controller,
    required this.onTap, required this.busy});
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
          color: active ? p.lycheeSoft : p.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: active ? p.lychee : p.line)),
        child: Row(children: [
          Container(width: 38, height: 38,
            decoration: BoxDecoration(
              color: p.surfaceRaised,
              borderRadius: BorderRadius.circular(11)),
            child: Icon(Icons.auto_awesome_rounded,
              color: active ? p.lycheeInk : p.ink, size: 19)),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(v3Copy(context, zh: '自动选择',
                en: 'Automatic selection', tw: '自動選擇'),
                style: TextStyle(color: p.ink, fontSize: 14,
                  fontWeight: FontWeight.w700)),
              const SizedBox(height: 3),
              Text(v3Copy(context, zh: '自动选择可用节点',
                en: 'Automatically choose an available node',
                tw: '自動選擇可用節點'),
                style: TextStyle(color: p.inkMuted, fontSize: 11)),
            ],
          )),
          if (busy)
            const SizedBox(width: 18, height: 18,
              child: CircularProgressIndicator(strokeWidth: 2))
          else if (active)
            Icon(Icons.check_circle_rounded, color: p.lycheeInk, size: 20),
        ]),
      ),
    );
  }
}

class V3NodeRow extends StatelessWidget {
  const V3NodeRow({super.key, required this.node,
    required this.controller, required this.onTap, required this.busy});
  final NodeModel node;
  final AppController controller;
  final VoidCallback? onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    final selected = !controller.autoSelected &&
        controller.currentNode.id == node.id;
    final latencyColor = node.latency > 0 && node.latency <= 120
        ? p.successInk
        : node.latency > 120 && node.latency < 9999
          ? p.warningInk : p.inkMuted;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? p.lycheeSoft : p.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? p.lychee : p.line)),
        child: Row(children: [
          V3NodeFlag(code: node.code),
          const SizedBox(width: 13),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(node.name, maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 3),
              Text(node.englishName.isNotEmpty ? node.englishName : node.code,
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall),
            ])),
          Container(width: 7, height: 7,
            decoration: BoxDecoration(color: latencyColor,
              shape: BoxShape.circle)),
          const SizedBox(width: 7),
          Text(_localizedLatencyLabel(context, node.latency),
            style: TextStyle(color: latencyColor, fontSize: 11,
              fontWeight: FontWeight.w700)),
          const SizedBox(width: 12),
          if (busy)
            const SizedBox(width: 18, height: 18,
              child: CircularProgressIndicator(strokeWidth: 2))
          else
            Icon(selected ? Icons.check_circle_rounded
              : Icons.chevron_right_rounded,
              color: selected ? p.lycheeInk : p.inkMuted, size: 19),
        ]),
      ),
    );
  }
}

String _localizedLatencyLabel(BuildContext context, int value) {
  if (value == -1) {
    return v3Copy(context, zh: '测速中', en: 'Testing', tw: '測速中');
  }
  if (value <= 0) {
    return v3Copy(context, zh: '未测速', en: 'Not tested', tw: '未測速');
  }
  if (value >= 9999) {
    return v3Copy(context, zh: '超时', en: 'Timeout', tw: '逾時');
  }
  return '${value}ms';
}

// Public legacy formatting contract remains stable for existing callers.
String v3LatencyLabel(int value) {
  if (value == -1) return '测速中';
  if (value <= 0) return '未测速';
  if (value >= 9999) return '超时';
  return '${value}ms';
}