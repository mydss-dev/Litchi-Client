import 'package:flutter/widgets.dart';

/// The app's three motion tokens. Durations follow the same three tiers the
/// big design systems converge on (Material 3 motion tokens: short <=200 /
/// medium 250-400 / long 400-600ms; Ant motionDurationFast/Mid/Slow) and the
/// values are DLSS5 Swapper's own (`--fast: .18s; --med: .32s; --slow: .6s`),
/// so interface feedback, page changes and overlays all land at the same
/// tempo instead of the ad-hoc 160/180/240ms that preceded this class.
abstract final class V3Motion {
  /// Hover, color and selection tints -- fast enough to feel attached to the
  /// pointer.
  static const Duration fast = Duration(milliseconds: 180);

  /// Element-level travel: rail indicator slide, popover and dialog
  /// entrances.
  static const Duration medium = Duration(milliseconds: 320);

  /// Page-level entrances, where a longer run reads as weight, not lag.
  static const Duration slow = Duration(milliseconds: 600);

  /// DLSS5's general-purpose ease (`--ease: cubic-bezier(.2,.8,.2,1)`), a
  /// swift-out curve for color and opacity work.
  static const Curve ease = Cubic(0.2, 0.8, 0.2, 1);

  /// DLSS5's spring, ported stop for stop -- a deceleration with a
  /// barely-there 1.7% overshoot around 55-64% of the run. The overshoot is
  /// what makes a 420ms page entrance feel alive where easeOutCubic at the
  /// same duration feels like syrup; keeping it under 2% is what keeps it
  /// from feeling like a toy.
  static const Curve spring = V3SpringCurve();
}

/// Piecewise-linear port of DLSS5 Swapper's `--spring`:
/// `linear(0, .006, .025 2.8%, .101 6.1%, .539 18.9%, .721 25.3%,
/// .849 31.5%, .937 38.1%, .968 41.8%, .991 45.7%, 1.006 50.1%, 1.015 55%,
/// 1.017 63.9%, then normalized to land exactly on 1.0 -- the reference's
/// 1.001 tail is an imperceptible 0.1% sampling artifact that would leave
/// sub-pixel rest offsets. The first two values share the gap between their
/// neighbours evenly, per the CSS spec, so `.006` sits at 1.4%. Sampled
/// interpolation is deterministic -- no physics simulation, no clock -- so
/// pumpAndSettle-based tests stay exact.
class V3SpringCurve extends Curve {
  const V3SpringCurve();

  static const List<double> _t = [
    0.0, 0.014, 0.028, 0.061, 0.189, 0.253, 0.315, 0.381, //
    0.418, 0.457, 0.501, 0.55, 0.639, 1.0,
  ];
  static const List<double> _v = [
    0.0, 0.006, 0.025, 0.101, 0.539, 0.721, 0.849, 0.937, //
    0.968, 0.991, 1.006, 1.015, 1.017, 1.0,
  ];

  @override
  double transformInternal(double t) {
    assert(t >= 0 && t <= 1);
    if (t <= 0) return 0;
    if (t >= 1) return _v.last;
    int lo = 0;
    int hi = _t.length - 1;
    while (hi - lo > 1) {
      final mid = (lo + hi) >> 1;
      if (_t[mid] <= t) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    final span = _t[hi] - _t[lo];
    final k = 0.0 + ((t - _t[lo]) / span);
    return _v[lo] + (_v[hi] - _v[lo]) * k;
  }
}

/// True when the platform asks for reduced motion (macOS/Windows
/// accessibility settings, Android "remove animations"). Every entrance in
/// the app gates on this and lands on its final state directly -- the Apple
/// HIG "Reduce Motion" and WCAG 2.3.3 expectation, and the same promise
/// DLSS5 makes with its four prefers-reduced-motion blocks.
bool v3ReducedMotion(BuildContext context) =>
    MediaQuery.maybeDisableAnimationsOf(context) ?? false;
