import 'package:flutter/material.dart';

import '../../../shared/theme/app_palette.dart';
import '../../../shared/theme/app_text_styles.dart';
import '../../../shared/widgets/brand_logo.dart';

/// Left gradient panel of the full-bleed auth layout. Fills its column; the
/// window's rounded corners are handled by the root clip. Purely decorative:
/// logo + brand + a large title/subtitle. No feature list.
class AuthVisualArea extends StatelessWidget {
  const AuthVisualArea({
    super.key,
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(gradient: AppPalette.brandGradient),
        child: Stack(
          children: [
            // ---- Decorative blobs / orbits (§16.8) ----
            Positioned(
              top: -50,
              right: -40,
              child: _circle(150, Colors.white.withValues(alpha: 0.12)),
            ),
            Positioned(
              bottom: -30,
              left: -50,
              child: _circle(140, Colors.white.withValues(alpha: 0.10)),
            ),
            Positioned(
              bottom: 90,
              right: 30,
              child: _ringCircle(70),
            ),
            Positioned(
              top: 120,
              left: 40,
              child: _circle(10, Colors.white.withValues(alpha: 0.5)),
            ),
            Positioned(
              top: 200,
              right: 60,
              child: _circle(6, Colors.white.withValues(alpha: 0.45)),
            ),
            // ---- Content ----
            Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const BrandLogo(size: 40, radius: 12),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Litchi',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                fontFamilyFallback: AppTextStyles.fontFamilyFallback,
                              )),
                          Text('Network Client',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 11,
                                fontFamilyFallback: AppTextStyles.fontFamilyFallback,
                              )),
                        ],
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    title,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      height: 1.25,
                      fontFamilyFallback: AppTextStyles.fontFamilyFallback,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 14,
                      height: 1.5,
                      fontWeight: FontWeight.w500,
                      fontFamilyFallback: AppTextStyles.fontFamilyFallback,
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _circle(double size, Color color) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );

  Widget _ringCircle(double size) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 1.5),
        ),
      );
}
