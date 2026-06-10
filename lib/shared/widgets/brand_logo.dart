import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_palette.dart';

/// Renders the Litchi brand mark.
///
/// Uses the bundled SVG when available and falls back to a gradient circle
/// with an "L" glyph (§8.3) if the asset fails to load.
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.size = 30, this.radius});

  final double size;

  /// Corner radius of the rounded container. Defaults to a circle.
  final double? radius;

  static const String _asset = 'assets/images/litchi_logo.svg';

  @override
  Widget build(BuildContext context) {
    final r = radius ?? size / 2;
    return ClipRRect(
      borderRadius: BorderRadius.circular(r),
      child: SvgPicture.asset(
        _asset,
        width: size,
        height: size,
        placeholderBuilder: (_) => _fallback(r),
      ),
    );
  }

  Widget _fallback(double r) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: AppPalette.brandGradient,
        borderRadius: BorderRadius.circular(r),
      ),
      alignment: Alignment.center,
      child: Text(
        'L',
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.47,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
