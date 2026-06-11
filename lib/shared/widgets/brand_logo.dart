import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../config/app_config.dart';

/// Renders the brand mark.
///
/// Loads `assets/images/brand_logo.svg` when present; falls back to a
/// gradient rounded square with [AppConfig.logoLetter].
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.size = 30, this.radius});

  final double size;
  final double? radius;

  static const String _asset = 'assets/images/brand_logo.svg';

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
        gradient: AppConfig.brandGradient,
        borderRadius: BorderRadius.circular(r),
      ),
      alignment: Alignment.center,
      child: Text(
        AppConfig.logoLetter,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.47,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
