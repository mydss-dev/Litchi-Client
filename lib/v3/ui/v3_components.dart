import 'package:flutter/material.dart';

import '../theme/v3_palette.dart';

class V3Panel extends StatelessWidget {
  const V3Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.tone = V3PanelTone.surface,
    this.radius = 18,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final V3PanelTone tone;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    final color = switch (tone) {
      V3PanelTone.surface => p.surface,
      V3PanelTone.raised => p.surfaceRaised,
      V3PanelTone.ink => p.night,
      V3PanelTone.signal => p.lychee,
    };
    final border = tone == V3PanelTone.ink || tone == V3PanelTone.signal
        ? Colors.transparent
        : p.line;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: border),
      ),
      child: child,
    );
  }
}

enum V3PanelTone { surface, raised, ink, signal }

class V3PageHeader extends StatelessWidget {
  const V3PageHeader({
    super.key,
    required this.kicker,
    required this.title,
    this.description,
    this.trailing,
  });

  final String kicker;
  final String title;
  final String? description;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                kicker.toUpperCase(),
                style: TextStyle(
                  color: p.lychee,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.8,
                ),
              ),
              const SizedBox(height: 8),
              Text(title, style: Theme.of(context).textTheme.displayMedium),
              if (description != null) ...[
                const SizedBox(height: 7),
                Text(
                  description!,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}

class V3ActionButton extends StatelessWidget {
  const V3ActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.secondary = false,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool secondary;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    final child = busy
        ? const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) Icon(icon, size: 16),
              if (icon != null) const SizedBox(width: 8),
              Text(label),
            ],
          );
    return SizedBox(
      height: 44,
      child: secondary
          ? OutlinedButton(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(
                foregroundColor: p.ink,
                side: BorderSide(color: p.line),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: child,
            )
          : FilledButton(
              onPressed: onPressed,
              style: FilledButton.styleFrom(
                backgroundColor: p.lychee,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: child,
            ),
    );
  }
}

class V3StatusBadge extends StatelessWidget {
  const V3StatusBadge({
    super.key,
    required this.label,
    required this.color,
    this.compact = false,
  });

  final String label;
  final Color color;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 5 : 7,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 7),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: p.ink,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

class V3SectionLabel extends StatelessWidget {
  const V3SectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text.toUpperCase(), style: Theme.of(context).textTheme.labelSmall);
}

class V3Rule extends StatelessWidget {
  const V3Rule({super.key});

  @override
  Widget build(BuildContext context) =>
      Divider(height: 1, color: V3Palette.of(context).line);
}
