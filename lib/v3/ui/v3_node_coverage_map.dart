import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../shared/models/app_models.dart';
import '../theme/v3_palette.dart';
import 'v3_components.dart';
import 'v3_latency_tier.dart';
import 'v3_locale_copy.dart';

/// A result of a client-side latency probe, NOT an authoritative server status.
enum V3NodeProbeState { unknown, responsive, timedOut }

/// Aggregate conservatively: a country is only red when every node timed out.
/// Missing/unfinished measurements must never be presented as online/offline.
V3NodeProbeState v3NodeProbeState(Iterable<NodeModel> nodes) {
  final list = nodes.where((node) => !node.isAuto).toList();
  if (list.isEmpty) return V3NodeProbeState.unknown;
  if (list.any((node) => node.latency > 0 && node.latency < 9999)) {
    return V3NodeProbeState.responsive;
  }
  if (list.every((node) => node.latency >= 9999)) {
    return V3NodeProbeState.timedOut;
  }
  return V3NodeProbeState.unknown;
}

/// Geographic, offline world overview. Node selection is handled on dashboard.
/// The coastlines and markers share an equirectangular longitude/latitude grid.
class V3NodeCoverageMap extends StatelessWidget {
  const V3NodeCoverageMap({super.key, required this.nodes,
    required this.selectedCode, required this.onSelected,
    this.readOnly = false});
  final List<NodeModel> nodes;
  final String? selectedCode;
  final ValueChanged<String?> onSelected;
  final bool readOnly;

  // Approximate geographic country centres, (longitude, latitude) in degrees.
  // Unknown codes are kept in the list/chips instead of inventing a location.
  static const Map<String, Offset> _geo = {
    'US': Offset(-98, 38), 'CA': Offset(-106, 56),
    'MX': Offset(-102, 24), 'BR': Offset(-52, -10),
    'GB': Offset(-3, 54), 'FR': Offset(2, 47),
    'DE': Offset(10, 51), 'NL': Offset(5, 52),
    'ES': Offset(-4, 40), 'IT': Offset(12, 42),
    'RU': Offset(95, 61), 'IN': Offset(78, 22),
    'HK': Offset(114, 22), 'TW': Offset(121, 24),
    'JP': Offset(139, 36), 'KR': Offset(128, 36),
    'SG': Offset(104, 1), 'MY': Offset(102, 4),
    'TH': Offset(101, 15), 'VN': Offset(106, 16),
    'PH': Offset(122, 12), 'ID': Offset(117, -2),
    'AU': Offset(134, -25), 'NZ': Offset(172, -41),
    'ZA': Offset(25, -29), 'AE': Offset(54, 24),
    'TR': Offset(35, 39),
  };

  static const Map<String, String> _names = {
    'US': '美国', 'CA': '加拿大', 'MX': '墨西哥', 'BR': '巴西',
    'GB': '英国', 'FR': '法国', 'DE': '德国', 'NL': '荷兰',
    'ES': '西班牙', 'IT': '意大利', 'RU': '俄罗斯', 'IN': '印度',
    'HK': '香港', 'TW': '台湾', 'JP': '日本', 'KR': '韩国',
    'SG': '新加坡', 'MY': '马来西亚', 'TH': '泰国', 'VN': '越南',
    'PH': '菲律宾', 'ID': '印度尼西亚', 'AU': '澳大利亚',
    'NZ': '新西兰', 'ZA': '南非', 'AE': '阿联酋', 'TR': '土耳其',
  };
  static const Map<String, String> _englishNames = {
    'US': 'United States', 'CA': 'Canada', 'MX': 'Mexico', 'BR': 'Brazil',
    'GB': 'United Kingdom', 'FR': 'France', 'DE': 'Germany',
    'NL': 'Netherlands', 'ES': 'Spain', 'IT': 'Italy', 'RU': 'Russia',
    'IN': 'India', 'HK': 'Hong Kong', 'TW': 'Taiwan', 'JP': 'Japan',
    'KR': 'South Korea', 'SG': 'Singapore', 'MY': 'Malaysia',
    'TH': 'Thailand', 'VN': 'Vietnam', 'PH': 'Philippines',
    'ID': 'Indonesia', 'AU': 'Australia', 'NZ': 'New Zealand',
    'ZA': 'South Africa', 'AE': 'United Arab Emirates', 'TR': 'Turkey',
  };
  static const Map<String, String> _traditionalNames = {
    'US': '美國', 'CA': '加拿大', 'MX': '墨西哥', 'BR': '巴西',
    'GB': '英國', 'FR': '法國', 'DE': '德國', 'NL': '荷蘭',
    'ES': '西班牙', 'IT': '義大利', 'RU': '俄羅斯', 'IN': '印度',
    'HK': '香港', 'TW': '台灣', 'JP': '日本', 'KR': '韓國',
    'SG': '新加坡', 'MY': '馬來西亞', 'TH': '泰國', 'VN': '越南',
    'PH': '菲律賓', 'ID': '印尼', 'AU': '澳洲', 'NZ': '紐西蘭',
    'ZA': '南非', 'AE': '阿拉伯聯合大公國', 'TR': '土耳其',
  };

  static String _country(BuildContext context, String code) => v3Copy(context,
    zh: _names[code] ?? code,
    en: _englishNames[code] ?? code,
    tw: _traditionalNames[code] ?? code);

  /// A country paints the tier of its best measured node: green/amber/red by
  /// the shared per-region latency scale, red when every node timed out, grey
  /// when nothing has been measured. Reachability alone (the old colouring)
  /// collapsed a 128ms Los Angeles and a 150ms Hong Kong into the same green.
  static Color _countryColor(V3Palette p, List<NodeModel> nodes) {
    final measured = nodes
        .where((node) => !node.isAuto && node.latency > 0 && node.latency < 9999)
        .toList();
    if (measured.isNotEmpty) {
      final best = measured.reduce(
        (a, b) => a.latency <= b.latency ? a : b,
      );
      return v3LatencyInk(p, best.region, best.latency);
    }
    final list = nodes.where((node) => !node.isAuto).toList();
    if (list.isNotEmpty &&
        list.every((node) => node.latency >= 9999)) {
      return p.dangerInk;
    }
    return p.inkMuted;
  }

  static String _stateLabel(BuildContext context, V3NodeProbeState state) =>
      switch (state) {
        V3NodeProbeState.responsive => v3Copy(context,
            zh: '测速成功', en: 'Probe succeeded', tw: '測速成功'),
        V3NodeProbeState.timedOut => v3Copy(context,
            zh: '测速超时', en: 'Probe timed out', tw: '測速逾時'),
        V3NodeProbeState.unknown => v3Copy(context,
            zh: '状态未知', en: 'Status unknown', tw: '狀態未知'),
      };

  static double _x(Offset lonLat, double width) =>
      ((lonLat.dx + 180) / 360 * width - 12)
          .clamp(0.0, width - 24).toDouble();
  static double _y(Offset lonLat, double height) =>
      ((90 - lonLat.dy) / 180 * height - 12)
          .clamp(0.0, height - 24).toDouble();

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    final groups = <String, List<NodeModel>>{};
    var nodeCount = 0;
    for (final node in nodes) {
      if (node.isAuto) continue;
      nodeCount++;
      final code = node.code.trim().toUpperCase();
      if (RegExp(r'^[A-Z]{2}$').hasMatch(code)) {
        groups.putIfAbsent(code, () => []).add(node);
      }
    }
    final codes = groups.keys.toList()..sort();
    final mapped = codes.where(_geo.containsKey).toList();
    final active = readOnly ? null :
        (groups.containsKey(selectedCode) ? selectedCode : null);

    return V3Panel(padding: const EdgeInsets.all(16),
      tone: V3PanelTone.raised,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.public_rounded, size: 18, color: p.lycheeInk),
          const SizedBox(width: 8),
          Expanded(child: Text(v3Copy(context, zh: '全球节点地图',
            en: 'World node map', tw: '全球節點地圖'),
            style: Theme.of(context).textTheme.titleMedium)),
          Text(v3Copy(context,
            zh: '${codes.length} 个地区 · $nodeCount 个节点',
            en: '${codes.length} regions · $nodeCount nodes',
            tw: '${codes.length} 個地區 · $nodeCount 個節點'),
            style: TextStyle(color: p.inkMuted, fontSize: 11)),
        ]),
        const SizedBox(height: 12),
        ClipRRect(borderRadius: BorderRadius.circular(V3Radius.field),
          child: Container(color: p.surface,
            child: AspectRatio(aspectRatio: 2,
              child: LayoutBuilder(builder: (context, constraints) => Stack(
                children: [
                  Positioned.fill(child: SvgPicture.asset(
                    'assets/images/world_coastline.svg',
                    fit: BoxFit.fill,
                    semanticsLabel: v3Copy(context,
                      zh: '世界地图', en: 'World map', tw: '世界地圖'))),
                  for (final entry in _geo.entries)
                    if (!groups.containsKey(entry.key))
                      Positioned(
                        left: _x(entry.value, constraints.maxWidth),
                        top: _y(entry.value, constraints.maxHeight),
                        child: const SizedBox(width: 24, height: 24,
                          child: Center(child: _MapDot(
                            color: Colors.grey, diameter: 6))),
                      ),
                  for (final code in mapped)
                    Positioned(
                      key: ValueKey('v3-map-marker-$code'),
                      left: _x(_geo[code]!, constraints.maxWidth),
                      top: _y(_geo[code]!, constraints.maxHeight),
                      child: Semantics(
                        button: !readOnly,
                        selected: !readOnly && active == code,
                        label: '${_country(context, code)} · ${groups[code]!.length} · '
                            '${_stateLabel(context, v3NodeProbeState(groups[code]!))}',
                        child: Tooltip(
                          message: '${_country(context, code)} · '
                              '${groups[code]!.length} · '
                              '${_stateLabel(context, v3NodeProbeState(groups[code]!))}',
                          child: readOnly
                              ? _MapMarker(
                                  color: _countryColor(p, groups[code]!),
                                  selected: false)
                              : InkWell(
                                  onTap: () => onSelected(
                                    active == code ? null : code),
                                  customBorder: const CircleBorder(),
                                  child: _MapMarker(
                                    color: _countryColor(p, groups[code]!),
                                    selected: active == code),
                                ),
                        ),
                      ),
                    ),
                  if (nodeCount == 0)
                    Center(child: DecoratedBox(
                      decoration: BoxDecoration(color: p.surface,
                        borderRadius: BorderRadius.circular(V3Radius.control)),
                      child: Padding(padding: const EdgeInsets.all(8),
                        child: Text(v3Copy(context,
                          zh: '暂无节点', en: 'No nodes yet', tw: '暫無節點'),
                          style: TextStyle(color: p.inkMuted, fontSize: 12))))),
                ],
              )),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(spacing: 13, runSpacing: 6, children: [
          _Legend(color: p.successInk,
            label: v3Copy(context, zh: '快', en: 'Fast', tw: '快')),
          _Legend(color: p.warningInk,
            label: v3Copy(context, zh: '一般', en: 'Okay', tw: '一般')),
          _Legend(color: p.dangerInk,
            label: v3Copy(context, zh: '慢 / 超时',
              en: 'Slow / timeout', tw: '慢 / 逾時')),
          _Legend(color: p.inkMuted,
            label: v3Copy(context, zh: '未测速 / 无节点',
              en: 'Unknown / no nodes', tw: '未測速 / 無節點')),
        ]),
        const SizedBox(height: 5),
        Text(v3Copy(context,
          zh: '颜色仅代表本次测速结果，不是实时在线状态。',
          en: 'Colors show client probe results, not live server health.',
          tw: '顏色僅代表本次測速結果，並非即時在線狀態。'),
          style: TextStyle(color: p.inkMuted, fontSize: 10)),
        if (!readOnly && codes.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(spacing: 7, runSpacing: 7, children: [
            ChoiceChip(key: const ValueKey('v3-map-country-all'),
              label: Text(v3Copy(context, zh: '全部地区',
                en: 'All regions', tw: '全部地區')),
              selected: active == null, showCheckmark: false,
              side: v3ChipSide(p, selected: active == null),
              onSelected: (_) => onSelected(null)),
            for (final code in codes)
              ChoiceChip(key: ValueKey('v3-map-country-$code'),
                label: Text('${_country(context, code)} ${groups[code]!.length}'),
                selected: active == code, showCheckmark: false,
                side: v3ChipSide(p, selected: active == code),
                onSelected: (_) => onSelected(active == code ? null : code)),
          ]),
        ],
      ]),
    );
  }
}

class _MapDot extends StatelessWidget {
  const _MapDot({required this.color, required this.diameter});
  final Color color;
  final double diameter;
  @override
  Widget build(BuildContext context) => Container(
    width: diameter, height: diameter,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle));
}

class _MapMarker extends StatelessWidget {
  const _MapMarker({required this.color, required this.selected});
  final Color color;
  final bool selected;
  @override
  Widget build(BuildContext context) => SizedBox(width: 24, height: 24,
    child: Center(child: Container(
      width: selected ? 17 : 13,
      height: selected ? 17 : 13,
      decoration: BoxDecoration(shape: BoxShape.circle,
        color: color, border: Border.all(
          color: Theme.of(context).colorScheme.surface, width: 2),
        boxShadow: [BoxShadow(
          color: color.withValues(alpha: .32), blurRadius: 5)]),
    )),
  );
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});
  final Color color;
  final String label;
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min,
    children: [
      _MapDot(color: color, diameter: 7),
      const SizedBox(width: 5),
      Text(label, style: TextStyle(
        color: V3Palette.of(context).inkMuted, fontSize: 10)),
    ]);
}
