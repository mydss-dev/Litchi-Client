import 'package:flutter/material.dart';

import '../config/app_config.dart';

/// Renders the brand mark. Priority order:
/// 1. Remote image URL in AppConfig.logoLetter (http/https)
/// 2. Local PNG at assets/images/logo.png
/// 3. Gradient square with AppConfig.logoLetter as a letter
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.size = 30, this.radius});

  final double size;
  final double? radius;

  static const String _pngAsset = 'assets/images/logo.png';

  bool get _isUrl {
    final v = AppConfig.logoLetter;
    return v.startsWith('http://') || v.startsWith('https://');
  }

  @override
  Widget build(BuildContext context) {
    final r = radius ?? size / 2;

    // Priority 1: remote URL in config
    if (_isUrl) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(r),
        child: Image.network(
          AppConfig.logoLetter,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _localPng(r),
          loadingBuilder: (_, child, progress) =>
              progress == null ? child : _localPng(r),
        ),
      );
    }

    // Priority 2: local PNG (logo.png)
    return _localPng(r);
  }

  Widget _localPng(double r) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(r),
      child: Image.asset(
        _pngAsset,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _letterFallback(r),
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
