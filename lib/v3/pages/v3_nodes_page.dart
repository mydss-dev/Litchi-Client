import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../shared/models/app_models.dart';
import '../theme/v3_palette.dart';
import '../ui/v3_components.dart';

class V3NodesPage extends StatefulWidget {
  const V3NodesPage({super.key});

  @override
  State<V3NodesPage> createState() => _V3NodesPageState();
}

class _V3NodesPageState extends State<V3NodesPage> {
  String _query = '';
  NodeRegion? _region;
  bool _testing = false;
  String? _pending;
  String? _feedback;
  bool _failed = false;

  Future<void> _run(
    String id,
    Future<String?> Function() action,
    String success,
  ) async {
    if (_pending != null || _testing) return;
    setState(() {
      _pending = id;
      _feedback = null;
    });
    try {
      final error = await action();
      if (!mounted) return;
      setState(() {
        _failed = error != null;
        _feedback = error ?? success;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _failed = true;
          _feedback = '操作失败，请检查网络后重试。';
        });
      }
    } finally {
      if (mounted) setState(() => _pending = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final nodes = controller.nodes.where((node) {
      final query = _query.trim().toLowerCase();
      final matchesQuery =
          query.isEmpty ||
          node.name.toLowerCase().contains(query) ||
          node.englishName.toLowerCase().contains(query) ||
          node.code.toLowerCase().contains(query);
      return matchesQuery && (_region == null || node.region == _region);
    }).toList();
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 26, 24, 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          V3PageHeader(
            kicker: '节点列表',
            title: '选择节点',
            description: '选择可用节点，或交给自动选择。',
            trailing: V3ActionButton(
              label: _testing ? '测速中' : '全部测速',
              icon: Icons.speed_rounded,
              busy: _testing,
              secondary: true,
              onPressed:
                  _testing || _pending != null || controller.nodes.isEmpty
                  ? null
                  : () async {
                      setState(() => _testing = true);
                      try {
                        final ok = await controller.testLatencies();
                        if (mounted) {
                          setState(() {
                            _failed = !ok;
                            _feedback = ok ? '测速完成' : '测速未完成，请检查连接后重试。';
                          });
                        }
                      } catch (_) {
                        if (mounted) {
                          setState(() {
                            _failed = true;
                            _feedback = '测速失败，请重试。';
                          });
                        }
                      } finally {
                        if (mounted) setState(() => _testing = false);
                      }
                    },
            ),
          ),
          const SizedBox(height: 22),
          TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search_rounded),
              hintText: '搜索国家、城市或节点名称',
            ),
            onChanged: (value) => setState(() => _query = value),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                // Live region: this line is where a failed latency test or
                // refresh reports back, and it changes without focus moving.
                // Without it a screen reader never learns the outcome.
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    _pending != null
                        ? '正在处理，请稍候…'
                        : _feedback ?? '已选节点不代表已经连接，请在连接页确认状态。',
                    style: TextStyle(
                      fontSize: 12,
                      color: _failed && _pending == null
                          ? V3Palette.of(context).dangerInk
                          : V3Palette.of(context).inkMuted,
                    ),
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: _pending != null || _testing
                    ? null
                    : () => _run('refresh', () async {
                        await controller.refreshData();
                        return controller.dataLoadError;
                      }, '节点已刷新'),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('刷新'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              final desktop = constraints.maxWidth >= 720;
              final list = Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _AutoRouteRow(
                    controller: controller,
                    busy: _pending == 'auto',
                    onTap:
                        _pending != null || _testing || controller.autoSelected
                        ? null
                        : () => _run(
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
                        controller.nodes.isEmpty
                            ? '暂无可用节点，请刷新订阅后重试。'
                            : '没有匹配的节点，请调整搜索或地区筛选。',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    )
                  else
                    ...nodes.map(
                      (node) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _NodeRow(
                          node: node,
                          controller: controller,
                          busy: _pending == node.id,
                          onTap:
                              _pending != null ||
                                  _testing ||
                                  (!controller.autoSelected &&
                                      controller.currentNode.id == node.id)
                              ? null
                              : () => _run(
                                  node.id,
                                  () => controller.setCurrentNode(node),
                                  '已选择 ${node.name}，请在连接页确认连接状态。',
                                ),
                        ),
                      ),
                    ),
                ],
              );
              if (!desktop) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _RegionRail(
                      selected: _region,
                      onSelected: (value) => setState(() => _region = value),
                      horizontal: true,
                    ),
                    const SizedBox(height: 14),
                    list,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 172,
                    child: _RegionRail(
                      selected: _region,
                      onSelected: (value) => setState(() => _region = value),
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(child: list),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _RegionRail extends StatelessWidget {
  const _RegionRail({
    required this.selected,
    required this.onSelected,
    this.horizontal = false,
  });

  final NodeRegion? selected;
  final ValueChanged<NodeRegion?> onSelected;
  final bool horizontal;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    final items = <(NodeRegion?, String)>[
      (null, '全部'),
      ...NodeRegion.values.map((region) => (region, _regionLabel(region))),
    ];
    if (horizontal) {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final item in items)
            ChoiceChip(
              label: Text(item.$2),
              selected: selected == item.$1,
              onSelected: (_) => onSelected(item.$1),
              selectedColor: p.lycheeSoft,
              labelStyle: TextStyle(
                color: selected == item.$1 ? p.lychee : p.ink,
              ),
              showCheckmark: false,
            ),
        ],
      );
    }
    return V3Panel(
      padding: const EdgeInsets.all(10),
      tone: V3PanelTone.raised,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(8, 4, 8, 8),
            child: V3SectionLabel('地区'),
          ),
          ...items.map((item) {
            final active = item.$1 == selected;
            return Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => onSelected(item.$1),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: active ? p.lychee : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    item.$2,
                    style: TextStyle(
                      color: active ? Colors.white : p.ink,
                      fontSize: 12,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _AutoRouteRow extends StatelessWidget {
  const _AutoRouteRow({
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
          color: active ? p.night : p.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: active ? p.night : p.line),
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
                      color: active ? Colors.white : p.ink,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '自动选择可用节点',
                    style: TextStyle(
                      color: active
                          ? Colors.white.withValues(alpha: 0.55)
                          : p.inkMuted,
                      fontSize: 11,
                    ),
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
              const Icon(
                Icons.check_circle_rounded,
                color: Colors.white,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}

class _NodeRow extends StatelessWidget {
  const _NodeRow({
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
              _latency(node.latency),
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
                color: selected ? p.lychee : p.inkMuted,
                size: 19,
              ),
          ],
        ),
      ),
    );
  }
}

String _regionLabel(NodeRegion region) => switch (region) {
  NodeRegion.asia => '亚洲',
  NodeRegion.europe => '欧洲',
  NodeRegion.america => '美洲',
  NodeRegion.oceania => '大洋洲',
};

String _latency(int value) {
  if (value == -1) return '测速中';
  if (value <= 0) return '未测速';
  if (value >= 9999) return '超时';
  return '${value}ms';
}
