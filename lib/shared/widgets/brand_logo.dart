import 'package:flutter/material.dart';

import '../../config/app_config.dart';
import '../services/brand_asset_cache.dart';

/// Renders the session-stable cloud brand mark.
///
/// A bundled tenant logo is intentionally never used as a fallback: white-label
/// builds must not expose one customer's branding while another customer's
/// cloud asset is loading.
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
            ? _letterFallback(r)
            : Image.file(file, fit: BoxFit.contain, gaplessPlayback: true),
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
