import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_shadows.dart';
import '../theme/app_spacing.dart';

enum AppCardShadow { none, soft, card }

/// Standard surface card.
///
/// Interactive cards share one desktop behavior: pointer cursor, subtle hover
/// border, keyboard focus ring and restrained ripple/pressed feedback.
class AppCard extends StatefulWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.radius = AppRadius.card,
    this.width,
    this.height,
    this.color,
    this.shadow = AppCardShadow.card,
    this.border = true,
    this.borderColor,
    this.borderWidth = 1,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final double? width;
  final double? height;
  final Color? color;
  final AppCardShadow shadow;
  final bool border;
  final Color? borderColor;
  final double borderWidth;
  final VoidCallback? onTap;

  @override
  State<AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<AppCard> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final interactive = widget.onTap != null;
    final emphasized = interactive && (_hovered || _focused);
    final effectiveBorderColor = widget.borderColor ??
        (emphasized ? c.primary.withValues(alpha: 0.38) : c.softBorder);

    final decoration = BoxDecoration(
      color: widget.color,
      gradient: widget.color == null ? c.cardGradient : null,
      borderRadius: BorderRadius.circular(widget.radius),
      border: widget.border
          ? Border.all(
              color: effectiveBorderColor,
              width: _focused ? 1.5 : widget.borderWidth,
            )
          : null,
      boxShadow: switch (widget.shadow) {
        AppCardShadow.none => null,
        AppCardShadow.soft => AppShadows.soft(c),
        AppCardShadow.card => AppShadows.card(c),
      },
    );

    if (!interactive) {
      return Container(
        width: widget.width,
        height: widget.height,
        padding: widget.padding,
        decoration: decoration,
        child: widget.child,
      );
    }

    return Semantics(
      button: true,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          width: widget.width,
          height: widget.height,
          decoration: decoration,
          child: InkWell(
            onTap: widget.onTap,
            onHover: (value) {
              if (_hovered == value) return;
              setState(() => _hovered = value);
            },
            onFocusChange: (value) {
              if (_focused == value) return;
              setState(() => _focused = value);
            },
            mouseCursor: SystemMouseCursors.click,
            borderRadius: BorderRadius.circular(widget.radius),
            hoverColor: c.primary.withValues(alpha: 0.045),
            focusColor: c.primary.withValues(alpha: 0.07),
            splashColor: c.primary.withValues(alpha: 0.10),
            highlightColor: c.primary.withValues(alpha: 0.06),
            child: Padding(padding: widget.padding, child: widget.child),
          ),
        ),
      ),
    );
  }
}
