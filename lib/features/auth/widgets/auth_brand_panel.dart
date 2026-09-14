import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../config/app_config.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_radius.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_text_styles.dart';
import '../../../shared/widgets/brand_logo.dart';

/// Brand-only surface used by the adaptive auth shell.
///
/// The visual stays abstract on purpose: the Litchi Core/network motif carries
/// product identity without turning authentication into a large anime poster.
class AuthBrandPanel extends StatelessWidget {
  const AuthBrandPanel({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final panel = Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            c.primarySoft.withValues(alpha: 0.82),
            c.cardBg,
            c.secondarySoft.withValues(alpha: 0.46),
          ],
          stops: const [0, 0.58, 1],
        ),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: c.softBorder),
      ),
      child: Stack(
        children: [
          Positioned(
            top: compact ? -38 : -72,
            right: compact ? -18 : -48,
            child: _GlowDisc(
              size: compact ? 112 : 190,
              color: c.primary.withValues(alpha: 0.10),
            ),
          ),
          Positioned(
            bottom: compact ? -50 : -76,
            left: compact ? -28 : -52,
            child: _GlowDisc(
              size: compact ? 126 : 210,
              color: c.secondary.withValues(alpha: 0.08),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(compact ? AppSpacing.lg : AppSpacing.xxl),
            child: compact ? _buildCompact(c) : _buildExpanded(c),
          ),
        ],
      ),
    );

    if (compact) return SizedBox(height: 154, child: panel);
    return panel;
  }

  Widget _buildExpanded(AppColors c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _BrandLockup(),
        const Spacer(),
        Center(child: _LitchiCore(size: 178, colors: c)),
        const Spacer(),
        Row(
          children: [
            Icon(LucideIcons.shieldCheck, size: 16, color: c.primary),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                AppConfig.appName,
                style: AppTextStyles.caption.copyWith(
                  color: c.textSecondary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCompact(AppColors c) {
    return Row(
      children: [
        const Expanded(child: _BrandLockup()),
        const SizedBox(width: AppSpacing.md),
        _LitchiCore(size: 94, colors: c),
      ],
    );
  }
}

class _BrandLockup extends StatelessWidget {
  const _BrandLockup();

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const BrandLogo(size: 38, radius: AppRadius.md),
        const SizedBox(width: AppSpacing.md),
        Flexible(
          child: Text(
            AppConfig.appName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.sectionTitle.copyWith(
              color: c.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
        ),
      ],
    );
  }
}

class _LitchiCore extends StatelessWidget {
  const _LitchiCore({required this.size, required this.colors});

  final double size;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: colors.primary.withValues(alpha: 0.12),
              ),
            ),
          ),
          Container(
            width: size * 0.76,
            height: size * 0.76,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: colors.primary.withValues(alpha: 0.22),
              ),
            ),
          ),
          Container(
            width: size * 0.49,
            height: size * 0.49,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: colors.brandGradient,
              boxShadow: [
                BoxShadow(
                  color: colors.primary.withValues(alpha: 0.22),
                  blurRadius: size * 0.18,
                  spreadRadius: size * 0.02,
                ),
              ],
            ),
            child: Icon(
              LucideIcons.shieldCheck,
              size: size * 0.20,
              color: Colors.white,
            ),
          ),
          _NodeDot(
            alignment: const Alignment(-0.82, -0.22),
            size: size * 0.055,
            color: colors.primary,
          ),
          _NodeDot(
            alignment: const Alignment(0.76, -0.48),
            size: size * 0.042,
            color: colors.secondary,
          ),
          _NodeDot(
            alignment: const Alignment(0.66, 0.64),
            size: size * 0.05,
            color: colors.primary,
          ),
        ],
      ),
    );
  }
}

class _NodeDot extends StatelessWidget {
  const _NodeDot({
    required this.alignment,
    required this.size,
    required this.color,
  });

  final Alignment alignment;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.32),
              blurRadius: size * 1.8,
            ),
          ],
        ),
      ),
    );
  }
}

class _GlowDisc extends StatelessWidget {
  const _GlowDisc({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      ),
    );
  }
}
