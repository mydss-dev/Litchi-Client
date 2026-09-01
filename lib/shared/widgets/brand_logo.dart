import 'package:flutter/material.dart';

/// Renders the build-time bundled brand mark.
///
/// The icon is the bundled `assets/images/app_icon.png`, generated from the
/// signed config's `logo_url` at build time — the same source as the desktop
/// icon. It is always present in the bundle (either the real logo or the
/// built-in fallback), so there is no runtime letter fallback.
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.size = 30, this.radius});

  final double size;
  final double? radius;

  @override
  Widget build(BuildContext context) {
    final r = radius ?? size / 2;
    return ClipRRect(
      borderRadius: BorderRadius.circular(r),
      child: SizedBox.square(
        dimension: size,
        child: Image.asset(
          'assets/images/app_icon.png',
          fit: BoxFit.contain,
          gaplessPlayback: true,
        ),
      ),
    );
  }
}
