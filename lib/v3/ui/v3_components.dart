import 'package:flutter/material.dart';
import 'package:country_flags/country_flags.dart';

import '../theme/v3_palette.dart';

class V3NodeFlag extends StatelessWidget {
  const V3NodeFlag({super.key, required this.code, this.large = false});
  final String code;

  /// The dashboard's identity tile scale-up: 33x22 keeps the exact 3:2 flag
  /// ratio while filling the 48px tile, where the default 28x20 read as a
  /// stamp floating in a box. List rows keep the compact default.
  final bool large;

  @override
  Widget build(BuildContext context) {
    final width = large ? 33.0 : 28.0;
    final height = large ? 22.0 : 20.0;
    if (!RegExp(r'^[A-Za-z]{2}$').hasMatch(code.trim())) {
      return SizedBox(
        width: width,
        height: height,
        child: Icon(Icons.public_rounded, size: height),
      );
    }
    // Hairline in the shared line colour: white-field flags (US, JP) sit on
    // light raised tiles in light mode and dissolve without an edge.
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: V3Palette.of(context).line, width: 0.5),
      ),
      child: CountryFlag.fromCountryCode(
        code.trim(),
        theme: ImageTheme(
          width: width,
          height: height,
          shape: const RoundedRectangle(3),
        ),
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
    this.radius = V3Radius.card,
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
    // Busy keeps the label and swaps it into the icon slot, so the button
    // width does not jump when the spinner replaces the leading glyph.
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (busy)
          SizedBox(
            width: 16,
            height: 16,
            // An uncolored spinner resolves to ColorScheme.primary, which is
            // the same lychee as the primary button's own fill — invisible.
            // The secondary button sits on the canvas, where lychee reads.
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: secondary ? p.lychee : p.onLychee,
            ),
          )
        else if (icon != null) ...[
          Icon(icon, size: 16),
          const SizedBox(width: 8),
        ],
        Text(label),
      ],
    );
    return SizedBox(
      height: 44,
      child: secondary
          ? OutlinedButton(
              onPressed: busy ? null : onPressed,
              style: OutlinedButton.styleFrom(
                foregroundColor: p.ink,
                side: BorderSide(color: p.line),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(V3Radius.field),
                ),
              ),
              child: child,
            )
          : FilledButton(
              onPressed: busy ? null : onPressed,
              style: FilledButton.styleFrom(
                backgroundColor: p.lychee,
                foregroundColor: p.onLychee,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(V3Radius.field),
                ),
              ),
              child: child,
            ),
    );
  }
}

/// A tappable surface whose ink paints on its own local Material instead of
/// the root one, so the press/hover highlight stays visible inside V3's
/// opaque panels and cards — a bare InkWell paints on the nearest ancestor
/// Material, which sits below the card fill. Nest [V3Pressable] inside the
/// existing decorated Container: decoration and animation stay where they
/// are, the ink lands above them.
class V3Pressable extends StatelessWidget {
  const V3Pressable({
    super.key,
    required this.onTap,
    required this.child,
    this.borderRadius,
  });

  final VoidCallback? onTap;
  final Widget child;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      borderRadius: borderRadius,
      child: InkWell(borderRadius: borderRadius, onTap: onTap, child: child),
    );
  }
}

/// A money readout that rolls to its value — from zero on first build, then
/// from the previous value on every refresh — so money arriving reads as
/// motion instead of a hard text swap. The settled string is identical to the
/// plain formatted value it replaces.
class V3RollingMoney extends StatelessWidget {
  const V3RollingMoney({
    super.key,
    required this.value,
    required this.symbol,
    this.style,
  });

  final double value;
  final String symbol;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      // A begin of 0 only drives the first sweep; retargets animate from the
      // current value, never from zero again.
      tween: Tween(begin: 0, end: value),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      // scaleDown, not the ellipsis the old stat text used: a truncated
      // amount is a wrong amount. Where the string fits it renders 1:1; in a
      // narrow tile the whole value shrinks a touch instead of wrapping.
      builder: (context, amount, _) => FittedBox(
        fit: BoxFit.scaleDown,
        child: Text('$symbol${amount.toStringAsFixed(2)}', style: style),
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
    this.icon,
  });

  final String label;
  final Color color;
  final bool compact;

  /// Optional leading glyph replacing the plain status dot (a shield for
  /// protection states). Painted in [color]; null keeps the 6px dot.
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    // The label carries the status, so it gets the text-safe ink for the
    // fill colour instead of the ambient ink that hides the semantics.
    final ink = switch (color) {
      _ when color == p.lychee => p.lycheeInk,
      _ when color == p.success => p.successInk,
      _ when color == p.warning => p.warningInk,
      _ when color == p.danger => p.dangerInk,
      // Untested latency badges pass inkMuted; grey-on-grey keeps them as
      // quiet as the card's grey 未测速 text instead of near-black.
      _ when color == p.inkMuted => p.inkMuted,
      _ => p.ink,
    };
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
          icon != null
              ? Icon(icon, size: 13, color: color)
              : Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
          const SizedBox(width: 7),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: ink,
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

/// The one V3 toggle switch: lychee track when on, a raised grey track and
/// knob when off. Settings and the account preferences previously drew two
/// different switches; both now draw this one. A null [onChanged] disables
/// the toggle while work is in flight.
class V3Switch extends StatelessWidget {
  const V3Switch({super.key, required this.value, this.onChanged});

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return Semantics(
      button: true,
      toggled: value,
      // V3Pressable rides inside the track so the press ink lands on the
      // track itself instead of on a Material beneath its opaque fill.
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 52,
        height: 30,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: value ? p.lychee : p.surfaceRaised,
          borderRadius: BorderRadius.circular(99),
        ),
        child: V3Pressable(
          onTap: onChanged == null ? null : () => onChanged!(!value),
          borderRadius: BorderRadius.circular(99),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 160),
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: value ? p.onLychee : p.inkMuted,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
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
/// The compact "更多" tab renders its destinations this way — a list to scan.
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
        borderRadius: BorderRadius.circular(V3Radius.panel),
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

/// One row of a [V3NavPanel]: icon, label, and a chevron. The selected row
/// gets the same lychee tint as a selected rail item — a chevron colour alone
/// did not read as "you are here". An optional [subtitle] sits under the label
/// for rows that carry state worth surfacing at a glance (a binding status).
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
    // V3Pressable, not a bare InkWell: the panel below is opaque surface, so
    // a bare InkWell's hover/press ink lands on the root Material underneath
    // it and never shows. The pressable paints its own transparent Material
    // above the fill, keeping both washes visible.
    return V3Pressable(
      borderRadius: BorderRadius.circular(V3Radius.card),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: selected ? p.lycheeSoft : Colors.transparent,
          borderRadius: BorderRadius.circular(V3Radius.card),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: selected ? p.surface : p.surfaceRaised,
                borderRadius: BorderRadius.circular(V3Radius.control),
              ),
              child: Icon(
                icon,
                size: 18,
                color: selected ? p.lycheeInk : p.inkMuted,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: selected ? p.lycheeInk : p.ink,
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
        Text(
          'LITCHI',
          style: TextStyle(
            color: labelColor ?? p.ink,
            fontSize: labelSize,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.8,
          ),
        ),
      ],
    );
  }
}
