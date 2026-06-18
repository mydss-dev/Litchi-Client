import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../config/app_config.dart';

/// Renders the brand mark. Priority order:
/// 1. Remote image URL in AppConfig.logoLetter (http/https)
/// 2. Local SVG at assets/images/brand_logo.svg
/// 3. Gradient square with AppConfig.logoLetter as a letter
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.size = 30, this.radius});

  final double size;
  final double? radius;

  static const String _svgAsset = 'assets/images/brand_logo.svg';

  bool get _isUrl {
    final v = AppConfig.logoLetter;
    return v.startsWith('http://') || v.startsWith('https://');
  }

  @override
  Widget build(BuildContext context) {
    final r = radius ?? size / 2;

    if (_isUrl) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(r),
        child: Image.network(
          AppConfig.logoLetter,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _letterFallback(r),
          loadingBuilder: (_, child, progress) =>
              progress == null ? child : _letterFallback(r),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(r),
      child: SvgPicture.asset(
        _svgAsset,
        width: size,
        height: size,
        placeholderBuilder: (_) => _letterFallback(r),
      ),
    );
  }

  Widget _letterFallback(double r) {
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
