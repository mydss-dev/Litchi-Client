import 'package:flutter/material.dart';

import '../../config/app_config.dart';

/// Renders the build-time bundled brand mark.
///
/// The icon is the bundled `assets/images/app_icon.png`, generated from the
/// signed config's `logo_url` at build time — the same source as the desktop
/// icon. It degrades to a gradient letter only if that asset is somehow
/// missing from the bundle.
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
        child: _bundledIcon(r),
      ),
    );
  }

  Widget _bundledIcon(double r) {
    return Image.asset(
      'assets/images/app_icon.png',
      fit: BoxFit.contain,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => _letterFallback(r),
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
        AppConfig.appName.isEmpty ? 'L' : AppConfig.appName[0].toUpperCase(),
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.47,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
