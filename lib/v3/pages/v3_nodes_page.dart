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
      padding: const EdgeInsets.fromLTRB(30, 28, 30, 34),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          V3PageHeader(
            kicker: 'Route library',
            title: 'Choose your route',
            description:
                'Fast, transparent node selection with one calm default.',
            trailing: V3ActionButton(
              label: _testing ? 'Testing' : 'Test all',
              icon: Icons.speed_rounded,
              busy: _testing,
              secondary: true,
              onPressed: _testing || controller.nodes.isEmpty
                  ? null
                  : () async {
                      setState(() => _testing = true);
                      try {
                        await controller.testLatencies();
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
              hintText: 'Search country, city, or code',
            ),
            onChanged: (value) => setState(() => _query = value),
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final desktop = constraints.maxWidth >= 720;
              final list = Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _AutoRouteRow(controller: controller),
                  const SizedBox(height: 12),
                  if (nodes.isEmpty)
                    V3Panel(
                      padding: const EdgeInsets.all(28),
                      child: Text(
                        controller.nodes.isEmpty
                            ? 'No routes available yet.'
                            : 'No routes match this search.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    )
                  else
                    ...nodes.map(
                      (node) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _NodeRow(node: node, controller: controller),
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
  const _RegionRail({required this.selected, required this.onSelected});

  final NodeRegion? selected;
  final ValueChanged<NodeRegion?> onSelected;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    final items = <(NodeRegion?, String)>[
      (null, 'All routes'),
      ...NodeRegion.values.map((region) => (region, _regionLabel(region))),
    ];
    return V3Panel(
      padding: const EdgeInsets.all(10),
      tone: V3PanelTone.raised,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(8, 4, 8, 8),
            child: V3SectionLabel('Regions'),
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
  const _AutoRouteRow({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    final active = controller.autoSelected;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () async {
        final error = await controller.selectAuto();
        if (error != null && context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(error)));
        }
      },
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
                    'Litchi Auto',
                    style: TextStyle(
                      color: active ? Colors.white : p.ink,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Best available route, selected automatically',
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
            if (active)
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
  const _NodeRow({required this.node, required this.controller});

  final NodeModel node;
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    final selected =
        !controller.autoSelected && controller.currentNode.id == node.id;
    final latencyColor = node.latency > 0 && node.latency <= 120
        ? p.success
        : node.latency > 120 && node.latency < 9999
        ? p.warning
        : p.inkMuted;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () async {
        final error = await controller.setCurrentNode(node);
        if (error != null && context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(error)));
        }
      },
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
            Text(
              node.flag.isEmpty ? '◎' : node.flag,
              style: const TextStyle(fontSize: 22),
            ),
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
  NodeRegion.asia => 'Asia',
  NodeRegion.europe => 'Europe',
  NodeRegion.america => 'Americas',
  NodeRegion.oceania => 'Oceania',
};

String _latency(int value) {
  if (value == -1) return 'TEST';
  if (value <= 0) return '--';
  if (value >= 9999) return 'TIMEOUT';
  return '${value}ms';
}
