import 'package:flutter/material.dart';

import '../theme/v3_palette.dart';

/// Compact, read-only server labels shared by the dashboard and both node views.
/// No synthetic Premium/streaming claims are introduced by the client.
class V3NodeTags extends StatelessWidget {
  const V3NodeTags({
    super.key,
    required this.tags,
    this.maxVisible = 3,
    this.accent = true,
    this.chipMaxWidth = 104,
    this.showOverflow = true,
  });

  final List<String> tags;
  final int maxVisible;

  /// Brand-soft chip that lifts the tag off plain surfaces. Muted flips the
  /// fill to the opaque card colour — for selected node rows, whose
  /// lycheeSoft tint would dissolve a pink chip — while the text stays
  /// lychee-inked either way, so a tag reads as brand on both fills.
  final bool accent;

  /// Single-chip width cap. The dashboard cards' stacked Wrap can afford the
  /// wide default; an inline chip beside a node name shares that line with
  /// the title, so it passes a tighter cap and lets the name's ellipsis
  /// absorb the rest.
  final double chipMaxWidth;

  /// Whether hidden tags surface as a trailing "+N". Node rows turn this off:
  /// a pink "+N" floating between the chip and the latency badge reads as
  /// clutter at the row's tail — extra tags stay searchable instead.
  final bool showOverflow;

  @override
  Widget build(BuildContext context) {
    if (tags.isEmpty || maxVisible <= 0) return const SizedBox.shrink();
    final p = V3Palette.of(context);
    return Wrap(
      spacing: 6,
      runSpacing: 5,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final tag in tags.take(maxVisible))
          Tooltip(
            message: tag,
            child: Container(
              // Slim 2px vertical padding: the pill stays ~18px tall so it
              // floats centred beside a 14px row title instead of filling the
              // whole 22px name line and sagging into the subtitle.
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: accent ? p.lycheeSoft : p.surface,
                borderRadius: BorderRadius.circular(99),
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: chipMaxWidth),
                child: Text(
                  tag,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: p.lycheeInk,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        if (showOverflow && tags.length > maxVisible)
          Text(
            '+${tags.length - maxVisible}',
            style: TextStyle(color: p.inkMuted, fontSize: 10),
          ),
      ],
    );
  }
}
