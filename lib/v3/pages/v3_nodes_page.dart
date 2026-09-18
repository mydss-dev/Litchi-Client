import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../shared/models/app_models.dart';
import '../theme/v3_palette.dart';
import '../ui/v3_components.dart';
import '../ui/v3_locale_copy.dart';
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

  Future<void> _run(String id, Future<String?> Function() action,
      String success) async {
    if (_pending != null || _testing) return;
    setState(() { _pending = id; _feedback = null; });
    try {
      final error = await action();
      if (!mounted) return;
      setState(() { _failed = error != null; _feedback = error ?? success; });
    } catch (_) {
      if (mounted) {
        setState(() {
          _failed = true;
          _feedback = v3Copy(context, zh: '操作失败，请检查网络后重试。',
            en: 'Operation failed. Check your network and retry.',
            tw: '操作失敗，請檢查網路後重試。');
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
      final matchesQuery = query.isEmpty ||
          node.name.toLowerCase().contains(query) ||
          node.englishName.toLowerCase().contains(query) ||
          node.code.toLowerCase().contains(query);
      return matchesQuery &&
          (_region == null || node.region == _region) &&
          (countryCode == null || node.code.trim().toUpperCase() == countryCode);
    }).toList();
    final p = V3Palette.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 26, 24, 36),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        V3PageHeader(
          kicker: v3Copy(context, zh: '节点列表', en: 'NODE LIST', tw: '節點列表'),
          title: v3Copy(context, zh: '选择节点', en: 'Select a node', tw: '選擇節點'),
          description: v3Copy(context,
            zh: '地图筛选地区，列表选择节点；选中不等于已经连接。',
            en: 'Filter regions on the map and choose a node in the list. Selection does not mean connected.',
            tw: '透過地圖篩選地區，並從列表選擇節點；選取不代表已連線。'),
          trailing: V3ActionButton(
            label: _testing ? v3Copy(context, zh: '测速中',
              en: 'Testing', tw: '測速中') : v3Copy(context,
              zh: '全部测速', en: 'Test all', tw: '全部測速'),
            icon: Icons.speed_rounded,
            busy: _testing,
            secondary: true,
            onPressed: _testing || _pending != null || controller.nodes.isEmpty
                ? null
                : () async {
                    setState(() => _testing = true);
                    try {
                      final ok = await controller.testLatencies();
                      if (mounted) {
                        setState(() {
                          _failed = !ok;
                          _feedback = ok ? v3Copy(context,
                            zh: '测速完成', en: 'Latency test complete', tw: '測速完成')
                            : v3Copy(context,
                            zh: '测速未完成，请检查连接后重试。',
                            en: 'Latency test did not finish. Check your connection and retry.',
                            tw: '測速未完成，請檢查連線後重試。');
                        });
                      }
                    } catch (_) {
                      if (mounted) {
                        setState(() {
                          _failed = true;
                          _feedback = v3Copy(context, zh: '测速失败，请重试。',
                            en: 'Latency test failed. Retry.', tw: '測速失敗，請重試。');
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
            _region = null;
          }),
        ),
        const SizedBox(height: 20),
        TextField(
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search_rounded),
            hintText: v3Copy(context, zh: '搜索国家、城市或节点名称',
              en: 'Search country, city or node name',
              tw: '搜尋國家、城市或節點名稱'),
          ),
          onChanged: (value) => setState(() => _query = value),
        ),
        const SizedBox(height: 18),
        Row(children: [
          Expanded(child: Semantics(
            liveRegion: true,
            child: Text(
              _pending != null
                  ? v3Copy(context, zh: '正在处理，请稍候…',
                      en: 'Processing, please wait…', tw: '正在處理，請稍候…')
                  : _feedback ?? v3Copy(context,
                      zh: '已选节点不代表已经连接，请在连接页确认状态。',
                      en: 'A selected node is not necessarily connected. Check the connection page.',
                      tw: '選取節點不代表已連線，請至連線頁確認狀態。'),
              style: TextStyle(fontSize: 12,
                color: _failed && _pending == null ? p.dangerInk : p.inkMuted),
            ),
          )),
          TextButton.icon(
            onPressed: _pending != null || _testing ? null
                : () => _run('refresh', () async {
                    await controller.refreshData();
                    return controller.dataLoadError;
                  }, v3Copy(context, zh: '节点已刷新',
                    en: 'Nodes refreshed', tw: '節點已重新整理')),
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: Text(v3Copy(context, zh: '刷新', en: 'Refresh', tw: '重新整理')),
          ),
        ]),
        const SizedBox(height: 8),
        LayoutBuilder(builder: (context, constraints) {
          final desktop = constraints.maxWidth >= 720;
          final list = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              V3AutoRouteRow(
                controller: controller,
                busy: _pending == 'auto',
                onTap: _pending != null || _testing || controller.autoSelected
                    ? null
                    : () => _run('auto', controller.selectAuto,
                      v3Copy(context,
                        zh: '已选择自动节点，请在连接页确认连接状态。',
                        en: 'Automatic node selected. Confirm your connection on the connection page.',
                        tw: '已選擇自動節點，請至連線頁確認連線狀態。')),
              ),
              const SizedBox(height: 12),
              if (nodes.isEmpty)
                V3Panel(
                  padding: const EdgeInsets.all(28),
                  child: Text(controller.nodes.isEmpty
                    ? v3Copy(context,
                      zh: '暂无可用节点，请刷新订阅后重试。',
                      en: 'No nodes available. Refresh your subscription and retry.',
                      tw: '暫無可用節點，請重新整理訂閱後再試。')
                    : v3Copy(context,
                      zh: '没有匹配的节点，请调整搜索或地区筛选。',
                      en: 'No matching nodes. Change the search or region filter.',
                      tw: '沒有符合的節點，請調整搜尋或地區篩選。'),
                    style: Theme.of(context).textTheme.bodySmall),
                )
              else ...nodes.map((node) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: V3NodeRow(
                  node: node,
                  controller: controller,
                  busy: _pending == node.id,
                  onTap: _pending != null || _testing ||
                    (!controller.autoSelected &&
                      controller.currentNode.id == node.id)
                    ? null
                    : () => _run(node.id,
                      () => controller.setCurrentNode(node),
                      v3Copy(context,
                        zh: '已选择 ${node.name}，请在连接页确认连接状态。',
                        en: '${node.name} selected. Confirm your connection on the connection page.',
                        tw: '已選擇 ${node.name}，請至連線頁確認連線狀態。')),
                ),
              )),
            ],
          );
          if (!desktop) {
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _RegionRail(selected: _region, horizontal: true,
                  onSelected: (value) => setState(() {
                    _region = value;
                    _countryCode = null;
                  })),
                const SizedBox(height: 14),
                list,
              ]);
          }
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 172, child: _RegionRail(selected: _region,
              onSelected: (value) => setState(() {
                _region = value;
                _countryCode = null;
              }))),
            const SizedBox(width: 18),
            Expanded(child: list),
          ]);
        }),
      ]),
    );
  }
}

class _RegionRail extends StatelessWidget {
  const _RegionRail({required this.selected, required this.onSelected,
    this.horizontal = false});
  final NodeRegion? selected;
  final ValueChanged<NodeRegion?> onSelected;
  final bool horizontal;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    final items = <(NodeRegion?, String)>[
      (null, v3Copy(context, zh: '全部', en: 'All', tw: '全部')),
      ...NodeRegion.values.map((region) =>
        (region, _regionLabel(context, region))),
    ];
    if (horizontal) {
      return Wrap(spacing: 8, runSpacing: 8, children: [
        for (final item in items)
          ChoiceChip(
            label: Text(item.$2),
            selected: selected == item.$1,
            onSelected: (_) => onSelected(item.$1),
            side: v3ChipSide(p, selected: selected == item.$1),
            showCheckmark: false,
          ),
      ]);
    }
    return V3Panel(
      padding: const EdgeInsets.all(10),
      tone: V3PanelTone.raised,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
          child: V3SectionLabel(v3Copy(context,
            zh: '地区', en: 'Regions', tw: '地區'))),
        ...items.map((item) {
          final active = item.$1 == selected;
          return Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => onSelected(item.$1),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                decoration: BoxDecoration(
                  color: active ? p.surface : Colors.transparent,
                  borderRadius: BorderRadius.circular(10)),
                child: Text(item.$2, style: TextStyle(
                  color: active ? p.lycheeInk : p.ink, fontSize: 12,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500)),
              ),
            ),
          );
        }),
      ]),
    );
  }
}

String _regionLabel(BuildContext context, NodeRegion region) => switch (region) {
  NodeRegion.asia => v3Copy(context, zh: '亚洲', en: 'Asia', tw: '亞洲'),
  NodeRegion.europe => v3Copy(context, zh: '欧洲', en: 'Europe', tw: '歐洲'),
  NodeRegion.america => v3Copy(context, zh: '美洲', en: 'Americas', tw: '美洲'),
  NodeRegion.oceania => v3Copy(context, zh: '大洋洲', en: 'Oceania', tw: '大洋洲'),
};
