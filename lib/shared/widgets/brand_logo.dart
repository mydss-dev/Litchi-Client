import 'package:flutter/material.dart';

import '../../config/app_config.dart';
import '../services/brand_asset_cache.dart';

/// Renders the session-stable cloud brand mark.
///
/// Resolution order: the runtime cloud logo, then the build-time bundled brand
/// icon (`assets/images/app_icon.png`), then a gradient letter. The bundled
/// icon is generated from the same signed config at build time, so it is the
/// same customer's branding — not a different customer's.
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.size = 30, this.radius});

  final double size;
  final double? radius;

  @override
  Widget build(BuildContext context) {
    final r = radius ?? size / 2;
    final file = BrandAssetCache.logoFile;
    return ClipRRect(
      borderRadius: BorderRadius.circular(r),
      child: SizedBox.square(
        dimension: size,
        child: file == null
            ? _bundledFallback(r)
            : Image.file(file, fit: BoxFit.contain, gaplessPlayback: true),
      ),
    );
  }

  /// Uses the build-time bundled brand icon, degrading to a gradient letter
  /// only if that asset is somehow missing from the bundle.
  Widget _bundledFallback(double r) {
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
