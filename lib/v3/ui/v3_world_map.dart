import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../theme/v3_palette.dart';

/// The dot-matrix world map, transcribed from the accepted interaction
/// prototype (`design/elegant_mockup.html`, the `WORLD_ROWS` constant its
/// canvas painter consumes): 48 rows of 96 `0`/`1` cells on an equirectangular
/// grid, `1` marking land.
///
/// Kept as plain string rows instead of a bitmap so the painter can stay a
/// [CustomPainter] and theme itself from [V3Palette] at paint time.
const List<String> kWorldMapRows = <String>[
  '000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000',
  '000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000',
  '000000000000000000000001111111111111111111100000000000000000000000000000010000000000000000000000',
  '000000000000000000000101011101111111111111100000000000000000000000000000011110000000000000000000',
  '000000000000001111100100010000000111111111100000000000000000001000001111111111111000011000000000',
  '000011111111111111111001001111000011111110000000000001111100111110111111111111111111111111111111',
  '110111111111111111111111110111100011110000110000000111111001111111111111111111111111111111111111',
  '000011111111111111111111000111000001100000000000011110111111111111111111111111111111111111111111',
  '000001101111111111111110000111110000000000000000001110111111111111111111111111111111110000100000',
  '000000000000011111111111110111111000000000000101001111111111111111111111111111111111100001100000',
  '000000000000001111111111111111100000000000000001111111111111111111111111111111111111111000000000',
  '000000000000000111111111111111100100000000000001111111111111111111111111111111111111100000000000',
  '000000000000000111111111111111100000000000000111111111110011111111111111111111111111011000000000',
  '000000000000000111111111111100000000000000000111000011011111111111111111111111110100010000000000',
  '000000000000000011111111111100000000000000000011111000000111111111111111111111110001100000000000',
  '000000000000000011111111111000000000000000000111111111111111111111111111111111110000000000000000',
  '000000000000000001111111011000000000000000000111111111111111101111111111111111110000000000000000',
  '000000000000000000111100000000000000000000001111111111111111111100111111111111100000000000000000',
  '000000000000000000001111101100000000000000011111111111111111111000011111011110000000000000000000',
  '000000000000000000000111100000000000000000011111111111111111110000001100011110001000000000000000',
  '000000000000000000000000110000000000000000011111111111111111000000001000001110001000000000000000',
  '000000000000000000000000011111110000000000001111111111111111110000001000001000000000000000000000',
  '000000000000000000000000000111111100000000000111111111111111100000000000000000000000000000000000',
  '000000000000000000000000000111111110000000000000001111111111000000000000001001111000000000000000',
  '000000000000000000000000001111111111000000000000001111111110000000000000000101101000000000000000',
  '000000000000000000000000001111111111111000000000000111111110000000000000000000000000110010000000',
  '000000000000000000000000000111111111110000000000000111111110000000000000000000000000011000000000',
  '000000000000000000000000000011111111110000000000000111111110100000000000000000000011001000000000',
  '000000000000000000000000000011111111110000000000000111111110100000000000000000000111111000000000',
  '000000000000000000000000000001111111100000000000000011111100100000000000000000011111111100000000',
  '000000000000000000000000000001111111000000000000000011111000100000000000000000111111111110000000',
  '000000000000000000000000000001111110000000000000000011110000000000000000000000111111111110000000',
  '000000000000000000000000000011111100000000000000000011110000000000000000000000111111111110000000',
  '000000000000000000000000000011111000000000000000000000000000000000000000000000000000011100000010',
  '000000000000000000000000000011110000000000000000000000000000000000000000000000000000000000000010',
  '000000000000000000000000000011100000000000000000000000000000000000000000000000000000000000000100',
  '000000000000000000000000000011000000000000000000000000000000000000000000000000000000000000000000',
  '000000000000000000000000000011000000000000000000000000000000000000000000000000000000000000000000',
  '000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000000',
  '000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000',
  '000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000',
  '000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000',
  '000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000',
  '000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000',
  '000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000',
  '000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000',
  '000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000',
  '000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000',
];

/// The low-contrast dot-matrix world map painter. Contain-fits the 96x48 grid
/// into its canvas, centered, and draws one dot per land cell with a diameter
/// of `cellWidth * 0.52` - the mockup's geometry, dot for dot.
///
/// Colors resolve from [palette]: light draws the ink at 13% alpha, dark lifts
/// white to 10% (the mockup ships the same wash as `--f-dots` /
/// `--f-dots-alpha`). Dot centers and the dot radius are snapped to the
/// device-pixel grid so the field stays crisp on real screens. Missing or
/// malformed data paints a silent blank canvas - the map is ambience, never a
/// surface worth an error.
class V3WorldMapPainter extends CustomPainter {
  const V3WorldMapPainter({required this.palette, this.devicePixelRatio = 1.0});

  final V3Palette palette;

  /// The screen's pixel ratio, used to snap geometry onto the physical pixel
  /// grid. Zero and negative values fall back to 1.0.
  final double devicePixelRatio;

  static const int _cols = 96;
  static const int _gridRows = 48;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rows = kWorldMapRows;
    if (rows.isEmpty) return; // no data: quiet blank canvas.
    final cell = math.min(size.width / _cols, size.height / _gridRows);
    if (cell <= 0) return;
    final originX = (size.width - cell * _cols) / 2;
    final originY = (size.height - cell * _gridRows) / 2;
    // The palette instances are the two static const themes, so identity tells
    // the two washes apart without threading a brightness through the painter.
    final dot = identical(palette, V3Palette.dark)
        ? Colors.white.withValues(alpha: 0.10)
        : palette.ink.withValues(alpha: 0.13);
    final dpr = devicePixelRatio > 0 ? devicePixelRatio : 1.0;
    final radius = math.max(
      0.5,
      ((cell * 0.52 / 2) * dpr).roundToDouble() / dpr,
    );
    final dots = Path();
    for (var row = 0; row < _gridRows && row < rows.length; row++) {
      final line = rows[row];
      for (var col = 0; col < _cols && col < line.length; col++) {
        if (line.codeUnitAt(col) != 0x31) continue; // '1'
        final cx = ((originX + (col + 0.5) * cell) * dpr).roundToDouble() / dpr;
        final cy = ((originY + (row + 0.5) * cell) * dpr).roundToDouble() / dpr;
        dots.addOval(Rect.fromCircle(center: Offset(cx, cy), radius: radius));
      }
    }
    canvas.drawPath(dots, Paint()..color = dot);
  }

  @override
  bool shouldRepaint(V3WorldMapPainter oldDelegate) =>
      !identical(oldDelegate.palette, palette) ||
      oldDelegate.devicePixelRatio != devicePixelRatio;
}

/// The map as a drop-in layer: fills its parent (place it under a
/// [Positioned.fill] or a sized box), ignores pointers and repaints on its
/// own layer so the content above never waits on the map.
class V3WorldMap extends StatelessWidget {
  const V3WorldMap({super.key});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: IgnorePointer(
        child: CustomPaint(
          painter: V3WorldMapPainter(
            palette: V3Palette.of(context),
            devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

/// Country/region marker for the selected node. Coordinates are approximate
/// geographic centroids, not the server's physical position: NodeModel has
/// a country code but no latitude or longitude. Unsupported codes show no pin.
class V3WorldMapNodePin extends StatelessWidget {
  const V3WorldMapNodePin({
    super.key,
    required this.countryCode,
    required this.connected,
  });

  final String countryCode;
  final bool connected;

  // Offset(dx: longitude, dy: latitude).
  static const _centers = <String, Offset>{
    'JP': Offset(139.7, 35.7),
    'HK': Offset(114.2, 22.3),
    'SG': Offset(103.8, 1.3),
    'US': Offset(-98.6, 39.8),
    'CA': Offset(-106.3, 56.1),
    'GB': Offset(-1.5, 52.3),
    'DE': Offset(10.5, 51.2),
    'FR': Offset(2.2, 46.6),
    'NL': Offset(5.3, 52.1),
    'CH': Offset(8.2, 46.8),
    'IT': Offset(12.6, 42.5),
    'SE': Offset(15.0, 62.0),
    'FI': Offset(25.7, 64.0),
    'TR': Offset(35.2, 39.0),
    'AE': Offset(54.3, 24.5),
    'IN': Offset(78.9, 22.8),
    'KR': Offset(127.8, 36.4),
    'TW': Offset(121.0, 23.7),
    'MY': Offset(101.7, 3.1),
    'TH': Offset(100.9, 15.9),
    'VN': Offset(106.3, 16.0),
    'ID': Offset(117.2, -2.5),
    'PH': Offset(122.8, 12.9),
    'AU': Offset(134.5, -25.3),
    'NZ': Offset(172.0, -41.0),
    'BR': Offset(-51.9, -14.2),
    'MX': Offset(-102.5, 23.6),
    'RU': Offset(95.0, 61.5),
    'ZA': Offset(24.0, -29.0),
  };

  @override
  Widget build(BuildContext context) {
    final location = _centers[countryCode.trim().toUpperCase()];
    if (location == null) return const SizedBox.shrink();
    final p = V3Palette.of(context);
    final ink = connected ? p.success : p.lychee;
    return IgnorePointer(
      child: LayoutBuilder(builder: (context, constraints) {
        // Match the dot painter's 96 x 48 contain-fit geometry exactly.
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        final cell = math.min(width / 96, height / 48);
        final originX = (width - cell * 96) / 2;
        final originY = (height - cell * 48) / 2;
        final x = originX + (location.dx + 180) / 360 * cell * 96;
        final y = originY + (90 - location.dy) / 180 * cell * 48;
        return Stack(children: [
          Positioned(left: x - 12, top: y - 12,
            child: Container(
              key: const ValueKey('v3-map-country-marker'),
              width: 24, height: 24,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ink.withValues(alpha: .15),
                border: Border.all(color: ink.withValues(alpha: .35)),
              ),
              child: Container(
                width: 9, height: 9,
                decoration: BoxDecoration(
                  color: ink, shape: BoxShape.circle,
                  border: Border.all(color: p.surface, width: 1.5),
                ),
              ),
            ),
          ),
        ]);
      }),
    );
  }
}
