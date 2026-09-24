import 'package:flutter/material.dart';

import '../../shared/models/app_models.dart';
import '../theme/v3_palette.dart';

/// The one latency colour scale.
///
/// Regions clear different bars — a 200ms Los Angeles is a better result than
/// a 150ms Hong Kong — so every surface that paints a node latency (the
/// picker's corner badge, node rows, the dashboard's current-node cards, the
/// coverage map) resolves its colour here rather than keeping a private
/// threshold. Green clears the region's fast bar, amber clears the okay bar,
/// red is slower or timed out, grey is untested.
///
/// Fast/okay bars, measured from mainland China departure points:
/// asia ≤100/200, america ≤200/350, europe ≤220/380, oceania ≤180/320.

int _tierIndex(NodeRegion region, int latency) => switch (region) {
  NodeRegion.asia => latency <= 100 ? 0 : latency <= 200 ? 1 : 2,
  NodeRegion.america => latency <= 200 ? 0 : latency <= 350 ? 1 : 2,
  NodeRegion.europe => latency <= 220 ? 0 : latency <= 380 ? 1 : 2,
  NodeRegion.oceania => latency <= 180 ? 0 : latency <= 320 ? 1 : 2,
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

/// Fill variant for a node latency (badge backgrounds, dots).
Color v3LatencyFill(V3Palette p, NodeRegion region, int latency) {
  if (latency >= 9999) return p.danger;
  if (latency <= 0) return p.inkMuted;
  return switch (_tierIndex(region, latency)) {
    0 => p.success,
    1 => p.warning,
    _ => p.danger,
  };
}
