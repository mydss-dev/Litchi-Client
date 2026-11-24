import 'package:flutter/material.dart';

import '../theme/v3_palette.dart';

/// The phone-only implementation of the Elegant reference geometry.
/// Shared between the account hub and the full-screen account subpages.
abstract final class V3MobileDesign {
  static const double pageInset = 16;
  static const double cardRadius = 22;
  static const double cellRadius = 14;
  static const double cardGap = 12;
  static const double sectionGap = 22;
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
    final p = V3Palette.of(context);
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(V3MobileDesign.cardRadius),
        border: Border.all(color: p.hairline),
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
                  Icon(Icons.chevron_right_rounded, size: 17,
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
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return Container(
      height: 46,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: p.surfaceRaised,
        borderRadius: BorderRadius.circular(15),
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
                borderRadius: BorderRadius.circular(11),
                child: InkWell(
                  borderRadius: BorderRadius.circular(11),
                  onTap: () => onChanged(i),
                  child: Center(child: Text(labels[i],
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selectedIndex == i ? p.ink : p.inkMuted,
                      fontSize: 12,
                      fontWeight: selectedIndex == i
                          ? FontWeight.w700 : FontWeight.w500,
                    ))),
                ),
              ),
            ),
          ),
      ]),
    );
  }
}
