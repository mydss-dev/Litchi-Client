import 'package:flutter/material.dart';
import 'package:country_flags/country_flags.dart';

import '../theme/v3_palette.dart';

class V3NodeFlag extends StatelessWidget {
  const V3NodeFlag({super.key, required this.code});
  final String code;

  @override
  Widget build(BuildContext context) {
    if (!RegExp(r'^[A-Za-z]{2}$').hasMatch(code.trim())) {
      return const SizedBox(
        width: 28,
        height: 20,
        child: Icon(Icons.public_rounded, size: 20),
      );
    }
    return CountryFlag.fromCountryCode(
      code.trim(),
      theme: const ImageTheme(
        width: 28,
        height: 20,
        shape: RoundedRectangle(3),
      ),
    );
  }
}

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
      V3PanelTone.hero => p.hero,
      V3PanelTone.signal => p.lychee,
    };
    // The hero panel used to be `p.night`, which is near-black in both modes —
    // so it needed no border to separate itself. Now that it is a light block
    // in light mode, it reads as a panel only if it is drawn like one.
    final border = tone == V3PanelTone.signal ? Colors.transparent : p.line;
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

/// Which palette colour a [V3Panel] is painted with.
///
/// `hero` was called `ink` until the light theme stopped painting its large
/// panels black — the name described the old colour, not the role.
enum V3PanelTone { surface, raised, hero, signal }

/// The border for a chip that has a chosen state.
///
/// [ChoiceChip.side] is a plain [BorderSide] rather than a state-resolved
/// property, so it cannot come from `ChipThemeData` with two values and every
/// selectable chip has to ask for its own. All of them want the same answer:
/// the brand colour when chosen, a hairline otherwise.
BorderSide v3ChipSide(V3Palette p, {required bool selected}) => selected
    ? BorderSide(color: p.lychee, width: 1.5)
    : BorderSide(color: p.line);

/// A grey block standing in for a value that has not loaded yet.
///
/// Loading lists render these in place of their text and icon blocks, so the
/// first frame already occupies the layout the loaded list will. A centred
/// spinner instead sits alone and then the list snaps in from the left — which
/// reads as a flash and a misalignment on every open.
class V3SkeletonBlock extends StatelessWidget {
  const V3SkeletonBlock({
    super.key,
    this.width,
    required this.height,
    this.radius = 6,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: p.ink.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

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
                  color: p.lycheeInk,
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
                  borderRadius: BorderRadius.circular(14),
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
                  borderRadius: BorderRadius.circular(14),
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

/// A titled panel of navigation rows.
///
/// The account hub ("我的服务") and the compact "更多" tab are the same control
/// with different contents, so they are the same widget. Presentational: the
/// caller supplies the rows and the callback.
class V3NavPanel extends StatelessWidget {
  const V3NavPanel({super.key, required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 6),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: p.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 10, bottom: 6),
            child: Text(
              title,
              style: TextStyle(
                color: p.inkMuted,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
              ),
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}

/// One row of a [V3NavPanel]: icon, label, and a chevron in brand colour when
/// it is the page you are on. An optional [subtitle] sits under the label for
/// rows that carry state worth surfacing at a glance (a binding status).
class V3NavRow extends StatelessWidget {
  const V3NavRow({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: p.surfaceRaised,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, size: 18, color: p.inkMuted),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: p.ink,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      subtitle!,
                      style: TextStyle(
                        color: p.inkMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 19,
              color: selected ? p.lychee : p.inkMuted,
            ),
          ],
        ),
      ),
    );
  }
}

/// The Litchi mark.
///
/// The login screen and the desktop rail each drew their own: a pink square
/// holding a letter "L" on one, a citrus square holding a glyph on the other.
/// The pink was a hard-coded literal rather than a palette colour, so it stayed
/// pink through a theme change while everything around it did not — and two
/// marks for one product is not a mark.
class V3BrandMark extends StatelessWidget {
  const V3BrandMark({
    super.key,
    this.boxSize = 30,
    this.labelColor,
    this.labelSize = 15,
  });

  final double boxSize;
  final Color? labelColor;
  final double labelSize;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: boxSize,
          height: boxSize,
          decoration: BoxDecoration(
            color: p.citrus,
            // Kept proportional so the 30dp rail mark and the 34dp login mark
            // stay the same shape rather than two rounded squares by accident.
            borderRadius: BorderRadius.circular(boxSize / 3),
          ),
          child: Icon(
            Icons.blur_on_rounded,
            color: p.night,
            size: boxSize * 2 / 3,
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            'LITCHI',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
            style: TextStyle(
              color: labelColor ?? p.ink,
              fontSize: labelSize,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.8,
            ),
          ),
        ),
      ],
    );
  }
}
