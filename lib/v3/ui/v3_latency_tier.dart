import 'package:flutter/material.dart';

import '../../shared/models/app_models.dart';
import '../theme/v3_palette.dart';
import 'v3_locale_copy.dart';

/// The one latency colour scale.
///
/// Regions clear different bars — a 200ms Los Angeles is a better result than
/// a 150ms Hong Kong — so every surface that paints a node latency (node
/// rows, the dashboard's current-node cards, the coverage map) resolves its
/// colour here rather than keeping a private threshold. Green clears the
/// region's fast bar, amber clears the okay bar, red is slower or timed out,
/// grey is untested.
///
/// Fast/okay bars, measured from mainland China departure points:
/// asia ≤100/200, america ≤200/350, europe ≤220/380, oceania ≤180/320.

int _tierIndex(NodeRegion region, int latency) => switch (region) {
  NodeRegion.asia =>
    latency <= 100
        ? 0
        : latency <= 200
        ? 1
        : 2,
  NodeRegion.america =>
    latency <= 200
        ? 0
        : latency <= 350
        ? 1
        : 2,
  NodeRegion.europe =>
    latency <= 220
        ? 0
        : latency <= 380
        ? 1
        : 2,
  NodeRegion.oceania =>
    latency <= 180
        ? 0
        : latency <= 320
        ? 1
        : 2,
};

/// Text-safe colour for a node latency (labels, values).
Color v3LatencyInk(V3Palette p, NodeRegion region, int latency) {
  if (latency >= 9999) return p.dangerInk;
  if (latency <= 0) return p.inkMuted;
  return switch (_tierIndex(region, latency)) {
    0 => p.successInk,
    1 => p.warningInk,
    _ => p.dangerInk,
  };
}

/// Fill/border-safe tier colour — the counterpart of [v3LatencyInk] for
/// surfaces instead of text.
Color v3LatencyBase(V3Palette p, NodeRegion region, int latency) {
  if (latency >= 9999) return p.danger;
  if (latency <= 0) return p.inkMuted;
  return switch (_tierIndex(region, latency)) {
    0 => p.success,
    1 => p.warning,
    _ => p.danger,
  };
}

/// Shared label for every latency readout (badge, rows, cards).
String v3LatencyLabel(BuildContext context, int value) {
  if (value == -1) {
    return v3Copy(context, zh: '测速中', en: 'Testing', tw: '測速中');
  }
  if (value <= 0) {
    return v3Copy(context, zh: '未测速', en: 'Not tested', tw: '未測速');
  }
  if (value >= 9999) {
    return v3Copy(context, zh: '超时', en: 'Timeout', tw: '逾時');
  }
  return '${value}ms';
}

/// The latency readout as one atomic capsule: the tier colour fills the chip
/// and inks the label, so a row's trailing edge is a single element that
/// trailing state icons can never split or shift. Short numeric values read
/// near-circular; text states (测速中/未测速/超时) widen the same capsule
/// instead of switching shapes.
class V3LatencyBadge extends StatelessWidget {
  const V3LatencyBadge({
    super.key,
    required this.region,
    required this.latency,
    this.signal = false,
    this.statusSized = false,
  });

  final NodeRegion region;
  final int latency;

  /// Prepends tier-aware signal bars (3 filled = fast … 0 = untested/timeout)
  /// inside the capsule. Off by default — the plain numeric capsule stays the
  /// shared grammar for lists; the dashboard's current-node card opts in.
  final bool signal;

  /// Header sizing: same paddings and letter-spacing as [V3StatusBadge], so a
  /// card header can carry the latency pill as an exact visual twin of the
  /// status pill beside it. Lists keep the tighter default.
  final bool statusSized;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    // Wrapped in a min-size Row: a Container with `alignment` expands to fill
    // any bounded-width context (the dashboard card's Column), while flex
    // children always hug their content — the badge must stay capsule-sized
    // everywhere.
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // A measurement landing (测速中 → 45ms, a tier recolour, a timeout)
        // cross-fades the whole capsule instead of hard-swapping fill, glyph
        // and text in one frame. The first build plays no transition — the
        // page entrance owns that moment.
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 160),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeOutCubic.flipped,
          layoutBuilder: (currentChild, previousChildren) => Stack(
            alignment: Alignment.center,
            children: [...previousChildren, ?currentChild],
          ),
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween(
                begin: const Offset(0, 0.3),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          ),
          child: Container(
            key: ValueKey((region, latency, signal, statusSized)),
            height: statusSized ? null : 22,
            constraints: statusSized
                ? null
                : const BoxConstraints(minWidth: 22),
            padding: statusSized
                ? const EdgeInsets.symmetric(horizontal: 10, vertical: 7)
                : const EdgeInsets.symmetric(horizontal: 7),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              // Same soft-fill grammar as V3StatusBadge: tier colour at 12%
              // keeps the chip quiet in both themes and never fights the row
              // highlight.
              color: v3LatencyBase(p, region, latency).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (signal) ...[
                  _V3SignalBars(region: region, latency: latency),
                  const SizedBox(width: 5),
                ],
                Text(
                  v3LatencyLabel(context, latency),
                  style: TextStyle(
                    color: v3LatencyInk(p, region, latency),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: statusSized ? 0.8 : 0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Three ascending bars whose filled count encodes the latency tier — 3 for
/// fast, 2 okay, 1 slow, 0 for untested and timeout — so the glyph reads as
/// signal strength before the number beside it is parsed. Unfilled bars keep
/// the tier colour at low alpha, so an untested badge greys out and a timeout
/// reads dim red without a second palette.
class _V3SignalBars extends StatelessWidget {
  const _V3SignalBars({required this.region, required this.latency});

  final NodeRegion region;
  final int latency;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    final base = v3LatencyBase(p, region, latency);
    final filled = latency > 0 && latency < 9999
        ? 3 - _tierIndex(region, latency)
        : 0;
    // Nudged up 1px: crossAxisAlignment.end lands the bars on the text box's
    // descender line, a hair below the digits' baseline.
    return Padding(
      padding: const EdgeInsets.only(bottom: 1),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final (index, height) in const [4.0, 7.0, 10.0].indexed)
            Container(
              width: 3,
              height: height,
              margin: EdgeInsets.only(right: index == 2 ? 0 : 2),
              decoration: BoxDecoration(
                color: index < filled ? base : base.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
        ],
      ),
    );
  }
}
