import 'package:flutter/material.dart';

import '../../shared/models/app_models.dart';
import '../theme/v3_palette.dart';
import 'v3_components.dart';
import 'v3_locale_copy.dart';

/// An offline schematic of locations present in the actual node list.
/// In read-only mode, markers are informational and filters are omitted.
class V3NodeCoverageMap extends StatelessWidget {
  const V3NodeCoverageMap({super.key, required this.nodes,
    required this.selectedCode, required this.onSelected,
    this.readOnly = false});
  final List<NodeModel> nodes;
  final String? selectedCode;
  final ValueChanged<String?> onSelected;
  final bool readOnly;

  static const Map<String, Offset> _positions = {
    'US': Offset(.18, .42), 'CA': Offset(.19, .25),
    'MX': Offset(.16, .59), 'BR': Offset(.31, .76),
    'GB': Offset(.46, .27), 'FR': Offset(.48, .37),
    'DE': Offset(.53, .33), 'NL': Offset(.50, .29),
    'ES': Offset(.46, .45), 'IT': Offset(.54, .47),
    'RU': Offset(.68, .21), 'IN': Offset(.71, .58),
    'HK': Offset(.78, .59), 'TW': Offset(.83, .65),
    'JP': Offset(.90, .42), 'KR': Offset(.83, .44),
    'SG': Offset(.77, .79), 'MY': Offset(.73, .73),
    'TH': Offset(.73, .65), 'VN': Offset(.78, .69),
    'PH': Offset(.88, .72), 'ID': Offset(.80, .84),
    'AU': Offset(.89, .88), 'NZ': Offset(.96, .92),
    'ZA': Offset(.54, .88), 'AE': Offset(.61, .53),
    'TR': Offset(.59, .43),
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

  static String _code(NodeModel node) => node.code.trim().toUpperCase();
  static String _country(BuildContext context, String code) => v3Copy(context,
    zh: _names[code] ?? code,
    en: _englishNames[code] ?? code,
    tw: _traditionalNames[code] ?? code);

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    final counts = <String, int>{};
    var nodeCount = 0;
    for (final node in nodes) {
      if (node.isAuto) continue;
      nodeCount++;
      final code = _code(node);
      if (RegExp(r'^[A-Z]{2}$').hasMatch(code)) {
        counts.update(code, (value) => value + 1, ifAbsent: () => 1);
      }
    }
    final codes = counts.keys.toList()..sort();
    final mapped = codes.where(_positions.containsKey).toList();
    final active = readOnly ? null :
      (counts.containsKey(selectedCode) ? selectedCode : null);
    return V3Panel(
      padding: const EdgeInsets.all(16),
      tone: V3PanelTone.raised,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.public_rounded, size: 18, color: p.lycheeInk),
          const SizedBox(width: 8),
          Expanded(child: Text(v3Copy(context, zh: '节点覆盖地图',
            en: 'Node coverage map', tw: '節點覆蓋地圖'),
            style: Theme.of(context).textTheme.titleMedium)),
          Text(v3Copy(context,
            zh: '${codes.length} 个地区 · $nodeCount 个节点',
            en: '${codes.length} regions · $nodeCount nodes',
            tw: '${codes.length} 個地區 · $nodeCount 個節點'),
            style: TextStyle(color: p.inkMuted, fontSize: 11)),
        ]),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Container(
            height: 178, width: double.infinity, color: p.surface,
            child: LayoutBuilder(builder: (context, constraints) => Stack(
              children: [
                Positioned.fill(child: CustomPaint(painter: _WorldSketchPainter(p))),
                for (final code in mapped)
                  Positioned(
                    key: ValueKey('v3-map-marker-$code'),
                    left: (constraints.maxWidth - 32) * _positions[code]!.dx,
                    top: 146 * _positions[code]!.dy,
                    child: Semantics(
                      button: !readOnly,
                      selected: !readOnly && active == code,
                      label: readOnly
                        ? v3Copy(context,
                            zh: '${_country(context, code)}，${counts[code]} 个节点',
                            en: '${_country(context, code)}, ${counts[code]} nodes',
                            tw: '${_country(context, code)}，${counts[code]} 個節點')
                        : v3Copy(context,
                            zh: '${_country(context, code)}，${counts[code]} 个节点，筛选地区',
                            en: '${_country(context, code)}, ${counts[code]} nodes, filter region',
                            tw: '${_country(context, code)}，${counts[code]} 個節點，篩選地區'),
                      child: Tooltip(
                        message: v3Copy(context,
                          zh: '${_country(context, code)} · ${counts[code]} 个节点',
                          en: '${_country(context, code)} · ${counts[code]} nodes',
                          tw: '${_country(context, code)} · ${counts[code]} 個節點'),
                        child: readOnly
                          ? _CoverageDot(palette: p, selected: false)
                          : InkWell(
                              onTap: () => onSelected(active == code ? null : code),
                              customBorder: const CircleBorder(),
                              child: _CoverageDot(palette: p,
                                selected: active == code),
                            ),
                      ),
                    ),
                  ),
                if (nodes.isEmpty)
                  Center(child: DecoratedBox(
                    decoration: BoxDecoration(color: p.surface,
                      borderRadius: BorderRadius.circular(10)),
                    child: Padding(padding: const EdgeInsets.all(10),
                      child: Text(v3Copy(context,
                        zh: '暂无节点，地图将在同步后点亮',
                        en: 'No nodes yet. The map will light up after sync.',
                        tw: '暫無節點，地圖會在同步後亮起'),
                        style: TextStyle(color: p.inkMuted, fontSize: 12))),
                  )),
              ],
            )),
          ),
        ),
        if (!readOnly) ...[
          const SizedBox(height: 8),
          Text(v3Copy(context,
            zh: '离线示意图，光点表示有节点的地区；不代表实时在线状态或精确位置。',
            en: 'Offline schematic: dots indicate regions with nodes, not live status or exact locations.',
            tw: '離線示意圖：光點表示有節點的地區，不代表即時連線狀態或精確位置。'),
            style: TextStyle(color: p.inkMuted, fontSize: 10)),
          if (codes.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(spacing: 7, runSpacing: 7, children: [
              ChoiceChip(
                key: const ValueKey('v3-map-country-all'),
                label: Text(v3Copy(context,
                  zh: '全部地区', en: 'All regions', tw: '全部地區')),
                selected: active == null,
                showCheckmark: false,
                side: v3ChipSide(p, selected: active == null),
                onSelected: (_) => onSelected(null),
              ),
              for (final code in codes)
                ChoiceChip(
                  key: ValueKey('v3-map-country-$code'),
                  label: Text('${_country(context, code)} ${counts[code]}'),
                  selected: active == code,
                  showCheckmark: false,
                  side: v3ChipSide(p, selected: active == code),
                  onSelected: (_) => onSelected(active == code ? null : code),
                ),
            ]),
          ],
        ],
      ]),
    );
  }
}

class _CoverageDot extends StatelessWidget {
  const _CoverageDot({required this.palette, required this.selected});
  final V3Palette palette;
  final bool selected;

  @override
  Widget build(BuildContext context) => SizedBox(width: 32, height: 32,
    child: Center(child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: selected ? 18 : 13,
      height: selected ? 18 : 13,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? palette.citrus : palette.lychee,
        border: Border.all(color: palette.ink, width: 1.2),
        boxShadow: [BoxShadow(
          color: palette.lychee.withValues(alpha: .22),
          blurRadius: 7, spreadRadius: 2)],
      ),
    )),
  );
}

class _WorldSketchPainter extends CustomPainter {
  const _WorldSketchPainter(this.palette);
  final V3Palette palette;
  static const _shapes = <List<Offset>>[
    [Offset(.07,.23), Offset(.17,.15), Offset(.29,.18), Offset(.33,.32),
     Offset(.26,.41), Offset(.23,.55), Offset(.17,.56), Offset(.12,.43)],
    [Offset(.25,.56), Offset(.35,.59), Offset(.39,.68), Offset(.34,.85),
     Offset(.31,.96), Offset(.28,.80)],
    [Offset(.42,.27), Offset(.49,.20), Offset(.57,.25), Offset(.60,.37),
     Offset(.55,.48), Offset(.48,.48), Offset(.43,.38)],
    [Offset(.45,.51), Offset(.56,.48), Offset(.62,.60), Offset(.59,.78),
     Offset(.54,.95), Offset(.49,.82)],
    [Offset(.57,.19), Offset(.74,.12), Offset(.90,.22), Offset(.93,.39),
     Offset(.86,.50), Offset(.82,.67), Offset(.72,.62), Offset(.66,.51),
     Offset(.60,.42)],
    [Offset(.80,.77), Offset(.92,.74), Offset(.97,.90), Offset(.88,.96),
     Offset(.81,.88)],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()..color = palette.line.withValues(alpha: .42)
      ..strokeWidth = .6;
    for (var i = 1; i < 5; i++) {
      final y = size.height * i / 5;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    for (var i = 1; i < 9; i++) {
      final x = size.width * i / 9;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    final fill = Paint()..color = palette.inkMuted.withValues(alpha: .15);
    final stroke = Paint()..color = palette.line
      ..strokeWidth = 1..style = PaintingStyle.stroke;
    for (final polygon in _shapes) {
      final path = Path()
        ..moveTo(polygon.first.dx * size.width, polygon.first.dy * size.height);
      for (final point in polygon.skip(1)) {
        path.lineTo(point.dx * size.width, point.dy * size.height);
      }
      path.close();
      canvas.drawPath(path, fill);
      canvas.drawPath(path, stroke);
    }
  }

  @override
  bool shouldRepaint(covariant _WorldSketchPainter oldDelegate) =>
      oldDelegate.palette != palette;
}
