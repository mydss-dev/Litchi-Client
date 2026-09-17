import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../shared/models/app_models.dart';
import '../theme/v3_palette.dart';
import '../ui/v3_components.dart';
import '../ui/v3_node_coverage_map.dart';
import '../ui/v3_node_picker.dart';

class V3NodesPage extends StatefulWidget {
  const V3NodesPage({super.key});

  @override
  State<V3NodesPage> createState() => _V3NodesPageState();
}

class _V3NodesPageState extends State<V3NodesPage> {
  String _query = '';
  NodeRegion? _region;
  String? _countryCode;
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
    final availableCodes = controller.nodes
        .where((node) => !node.isAuto)
        .map((node) => node.code.trim().toUpperCase())
        .where((code) => RegExp(r'^[A-Z]{2}$').hasMatch(code))
        .toSet();
    // A refreshed subscription can remove the chosen country. Never strand
    // users on a zero-result filter they can no longer see or clear.
    final countryCode = availableCodes.contains(_countryCode) ? _countryCode : null;
    final query = _query.trim().toLowerCase();
    final nodes = controller.nodes.where((node) {
      final matchesQuery =
          query.isEmpty ||
          node.name.toLowerCase().contains(query) ||
          node.englishName.toLowerCase().contains(query) ||
          node.code.toLowerCase().contains(query);
      return matchesQuery &&
          (_region == null || node.region == _region) &&
          (countryCode == null || node.code.trim().toUpperCase() == countryCode);
    }).toList();
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 26, 24, 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          V3PageHeader(
            kicker: '节点列表',
            title: '选择节点',
            description: '地图筛选地区，列表选择节点；选中不等于已经连接。',
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
          const SizedBox(height: 20),
          V3NodeCoverageMap(
            nodes: controller.nodes,
            selectedCode: countryCode,
            onSelected: (code) => setState(() {
              _countryCode = code;
              // Country and continent are alternative navigation filters:
              // a HK tap must work even when Europe was selected earlier.
              _region = null;
            }),
          ),
          const SizedBox(height: 20),
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
                  V3AutoRouteRow(
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
                        child: V3NodeRow(
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
                      onSelected: (value) => setState(() {
                        _region = value;
                        _countryCode = null;
                      }),
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
                      onSelected: (value) => setState(() {
                        _region = value;
                        _countryCode = null;
                      }),
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
              side: v3ChipSide(p, selected: selected == item.$1),
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
                    color: active ? p.surface : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    item.$2,
                    style: TextStyle(
                      color: active ? p.lycheeInk : p.ink,
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

String _regionLabel(NodeRegion region) => switch (region) {
  NodeRegion.asia => '亚洲',
  NodeRegion.europe => '欧洲',
  NodeRegion.america => '美洲',
  NodeRegion.oceania => '大洋洲',
};
