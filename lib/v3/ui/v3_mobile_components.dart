import 'package:material_ui/material_ui.dart';

import '../theme/v3_palette.dart';
import '../../shared/theme/app_icons.dart';

/// Phone geometry for the primary tabs, the account hub and its subpages.
///
/// Every colour resolves through [V3Palette]: the phone no longer carries a
/// second warm-tinted palette, so all surfaces in both brightness modes draw
/// from one source of truth.
abstract final class V3MobileDesign {
  static const double pageInset = 16;
  static const pageInsets = EdgeInsets.fromLTRB(pageInset, 12, pageInset, 28);

  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color card(BuildContext context) => V3Palette.of(context).surface;

  static Color stroke(BuildContext context) => V3Palette.of(context).line;

  static Color accentCard(BuildContext context) =>
      V3Palette.of(context).lycheeSoft;

  /// The one primary action: a flat coral slab, the app's brand signature.
  /// Green stays reserved for the confirmed/connected status, so the two
  /// never compete for the same meaning.
  static ButtonStyle primaryButton(BuildContext context) {
    final p = V3Palette.of(context);
    return FilledButton.styleFrom(
      backgroundColor: p.lychee,
      foregroundColor: p.onLychee,
      elevation: 0,
      shadowColor: Colors.transparent,
      minimumSize: const Size(64, 48),
      textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(V3Radius.field)),
    );
  }

  static const double cardRadius = V3Radius.card;
  static const double cellRadius = V3Radius.control;
  static const double cardGap = 12;
  static const double sectionGap = 22;

  /// Bottom scroll padding on primary tabs so the last card clears the
  /// floating dock (the shell uses extendBody).
  static const double dockClearance = 112;
}

/// One flat canvas behind every phone page (no per-page tinted gradients).
class V3MobileBackdrop extends StatelessWidget {
  const V3MobileBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      ColoredBox(color: V3Palette.of(context).canvas, child: child);
}

class V3MobileCard extends StatelessWidget {
  const V3MobileCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: V3MobileDesign.card(context),
        borderRadius: BorderRadius.circular(V3MobileDesign.cardRadius),
        border: Border.all(color: V3MobileDesign.stroke(context)),
      ),
      child: child,
    );
  }
}

class V3MobileSectionTitle extends StatelessWidget {
  const V3MobileSectionTitle(this.label, {super.key});
  final String label;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return Text(
      label,
      style: TextStyle(
        color: p.inkMuted,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: .8,
      ),
    );
  }
}

/// A grid tile for the five phone account services. The tile is one
/// accessible hit target and never relies on a tiny trailing chevron.
class V3MobileHubTile extends StatelessWidget {
  const V3MobileHubTile({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.onTap,
    this.footer,
  });

  final IconData icon;
  final String title;
  final String value;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return Material(
      color: p.surfaceRaised,
      borderRadius: BorderRadius.circular(V3MobileDesign.cellRadius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 103),
          child: Padding(
            padding: const EdgeInsets.all(13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(icon, size: 16, color: p.inkMuted),
                  const SizedBox(width: 6),
                  Expanded(child: Text(title,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: p.inkMuted,
                      fontSize: 11, fontWeight: FontWeight.w600))),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: Text(value,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: p.ink,
                      fontSize: 15, fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()]))),
                  Icon(AppIcons.chevronRight, size: 17,
                    color: p.inkMuted),
                ]),
                const SizedBox(height: 6),
                Text(subtitle,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: p.inkMuted, fontSize: 10)),
                if (footer != null) ...[
                  const SizedBox(height: 8),
                  footer!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Neutral, equal-width filters with a single selected surface.
/// The same typography and selection geometry is used by each mobile ledger.
class V3MobileSegmented extends StatelessWidget {
  const V3MobileSegmented({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onChanged,
    this.icons,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  /// Optional glyphs shown before each label. When set it must match
  /// [labels] in length; the icon and label share one semantics node.
  final List<IconData>? icons;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return Container(
      height: 46,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: p.surfaceRaised,
        borderRadius: BorderRadius.circular(V3Radius.field),
      ),
      child: Row(children: [
        for (var i = 0; i < labels.length; i++)
          Expanded(
            child: Semantics(
              button: true,
              selected: selectedIndex == i,
              child: Material(
                color: selectedIndex == i
                    ? p.surface : Colors.transparent,
                borderRadius: BorderRadius.circular(V3Radius.control),
                child: InkWell(
                  borderRadius: BorderRadius.circular(V3Radius.control),
                  onTap: () => onChanged(i),
                  child: Center(child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icons != null && i < icons!.length) ...[
                        Icon(icons![i], size: 14,
                          color: selectedIndex == i ? p.ink : p.inkMuted),
                        const SizedBox(width: 5),
                      ],
                      Flexible(child: Text(labels[i],
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: selectedIndex == i ? p.ink : p.inkMuted,
                          fontSize: 13,
                          fontWeight: selectedIndex == i
                              ? FontWeight.w700 : FontWeight.w500,
                        ))),
                    ],
                  )),
                ),
              ),
            ),
          ),
      ]),
    );
  }
}

/// A labelled group of rows inside one card, separated by hairlines.
///
/// This is the reference's list pattern: the card owns the radius and the
/// outline, the rows own their own press wash, and the divider insets past the
/// 40dp icon tile so the rules never cut through the circle column.
class V3MobileGroupCard extends StatelessWidget {
  const V3MobileGroupCard({
    super.key,
    required this.children,
    this.title,
    this.footer,
  });

  final List<Widget> children;
  final String? title;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        rows.add(Divider(
          height: 1,
          thickness: 1,
          indent: 68,
          color: p.line.withValues(alpha: .7),
        ));
      }
      rows.add(children[i]);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null) ...[
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: V3MobileSectionTitle(title!),
          ),
        ],
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: V3MobileDesign.card(context),
            borderRadius: BorderRadius.circular(V3MobileDesign.cardRadius),
            border: Border.all(color: V3MobileDesign.stroke(context)),
          ),
          child: Column(children: rows),
        ),
        if (footer != null) ...[const SizedBox(height: 8), footer!],
      ],
    );
  }
}

/// Soft, pill-shaped search field used by the mobile ledgers.
///
/// The reference keeps search and its filters on one 46dp line: white fill,
/// hairline outline, quiet magnifier and 13px copy. The field owns no outer
/// padding so it can sit inside a [Row] without shifting neighbouring pills.
class V3MobileSearchField extends StatelessWidget {
  const V3MobileSearchField({
    super.key,
    required this.hintText,
    this.controller,
    this.onChanged,
    this.trailing,
    this.semanticLabel,
  });

  final String hintText;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final Widget? trailing;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return Semantics(
      label: semanticLabel ?? hintText,
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(V3Radius.field),
          border: Border.all(color: p.line),
        ),
        child: Row(children: [
          const SizedBox(width: 14),
          Icon(AppIcons.search, size: 18, color: p.inkMuted),
          const SizedBox(width: 9),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: TextStyle(color: p.ink, fontSize: 13),
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: TextStyle(
                  color: p.inkMuted.withValues(alpha: .72), fontSize: 13),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 4),
            trailing!,
            const SizedBox(width: 6),
          ] else
            const SizedBox(width: 10),
        ]),
      ),
    );
  }
}

/// Outline pill that opens a filter menu. Shares the search field's height so
/// the two controls read as one row rather than two different components.
class V3MobileFilterPill extends StatelessWidget {
  const V3MobileFilterPill({
    super.key,
    required this.label,
    this.onTap,
    this.icon,
    this.selected = false,
  });

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return Material(
      color: selected ? p.surfaceRaised : p.surface,
      borderRadius: BorderRadius.circular(V3Radius.field),
      child: InkWell(
        borderRadius: BorderRadius.circular(V3Radius.field),
        onTap: onTap,
        child: Container(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(V3Radius.field),
            border: Border.all(color: p.line),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: p.ink),
              const SizedBox(width: 7),
            ],
            Text(label,
              style: TextStyle(color: p.ink, fontSize: 13,
                fontWeight: FontWeight.w600)),
            const SizedBox(width: 5),
            Icon(AppIcons.chevronDown, size: 14, color: p.inkMuted),
          ]),
        ),
      ),
    );
  }
}

/// The reference's tinted status/level chip: 11px semibold text, an optional
/// state glyph and a 10% ink fill. Used by tickets and ledgers so a status is
/// never a bare coloured word floating on a card.
enum V3ChipTone { neutral, info, success, warning, danger }

class V3MobileStatusChip extends StatelessWidget {
  const V3MobileStatusChip({
    super.key,
    required this.label,
    this.tone = V3ChipTone.neutral,
    this.icon,
  });

  final String label;
  final V3ChipTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    final ink = switch (tone) {
      V3ChipTone.info => p.aquaInk,
      V3ChipTone.success => p.successInk,
      V3ChipTone.warning => p.warningInk,
      V3ChipTone.danger => p.dangerInk,
      V3ChipTone.neutral => p.inkMuted,
    };
    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: ink.withValues(alpha: tone == V3ChipTone.neutral ? .08 : .10),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[
          Icon(icon, size: 12, color: ink),
          const SizedBox(width: 5),
        ],
        Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: TextStyle(color: ink, fontSize: 11,
            fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

/// One row of a [V3MobileGroupCard]: a 40dp tinted icon tile, the label, an
/// optional trailing value and a chevron.
class V3MobileListRow extends StatelessWidget {
  const V3MobileListRow({
    super.key,
    required this.icon,
    required this.label,
    this.value,
    this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final String? value;
  final VoidCallback? onTap;
  final Widget? trailing;

  static const double height = 60;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    final content = SizedBox(
      height: height,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: p.surfaceRaised,
                borderRadius: BorderRadius.circular(V3Radius.control),
              ),
              child: Icon(icon, size: AppIconSize.md, color: p.ink),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: p.ink,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (value != null)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(
                  value!,
                  maxLines: 1,
                  style: TextStyle(color: p.inkMuted, fontSize: 12),
                ),
              ),
            if (trailing != null) ...[const SizedBox(width: 8), trailing!],
            if (onTap != null) ...[
              const SizedBox(width: 6),
              Icon(AppIcons.chevronRight, size: AppIconSize.sm, color: p.inkMuted),
            ],
          ],
        ),
      ),
    );
    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(onTap: onTap, child: content),
    );
  }
}
