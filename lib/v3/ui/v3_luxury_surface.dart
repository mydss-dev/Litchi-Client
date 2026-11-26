import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/v3_luxury_tokens.dart';

/// Design-system glass surface. The only "border" is a translucent inner
/// highlight; no opaque stroke or bezel should frame a card.
class V3LuxuryGlassCard extends StatelessWidget {
  const V3LuxuryGlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.hero = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool hero;

  @override
  Widget build(BuildContext context) {
    final c = V3LuxuryTokens.of(context);
    final radius = BorderRadius.circular(
      hero ? V3LuxuryRadius.hero : V3LuxuryRadius.card,
    );
    return RepaintBoundary(
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: hero ? .20 : .16),
              offset: Offset(0, hero ? 14 : 8),
              blurRadius: hero ? 36 : 24,
              spreadRadius: hero ? -10 : -8,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 28, sigmaY: 28),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: radius,
                border: Border.all(color: c.glassBorder, width: 1),
              ),
              child: Padding(padding: padding, child: child),
            ),
          ),
        ),
      ),
    );
  }
}

/// Page wash, deterministic film grain, and the content in exactly that paint
/// order. Noise is non-interactive and separated by a repaint boundary.
class V3LuxuryBackdrop extends StatelessWidget {
  const V3LuxuryBackdrop({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = V3LuxuryTokens.of(context);
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [c.canvas, c.canvasDeep],
            ),
          ),
        ),
        IgnorePointer(
          child: RepaintBoundary(
            child: CustomPaint(
              painter: _FilmGrainPainter(
                color: c.ink.withValues(alpha: .12),
              ),
              size: Size.infinite,
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class _FilmGrainPainter extends CustomPainter {
  const _FilmGrainPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final paint = Paint()
      ..color = color
      ..strokeWidth = .45
      ..strokeCap = StrokeCap.round;
    var hash = 0x5A17C321;
    final total = (size.width * size.height / 110).ceil().clamp(0, 7500);
    final dots = <Offset>[];
    for (var i = 0; i < total; i++) {
      hash = (1664525 * hash + 1013904223) & 0xFFFFFFFF;
      final x = ((hash & 0xFFFF) / 65535) * size.width;
      hash = (1664525 * hash + 1013904223) & 0xFFFFFFFF;
      final y = ((hash & 0xFFFF) / 65535) * size.height;
      dots.add(Offset(x, y));
    }
    canvas.drawPoints(ui.PointMode.points, dots, paint);
  }

  @override
  bool shouldRepaint(covariant _FilmGrainPainter oldDelegate) =>
      oldDelegate.color != color;
}
