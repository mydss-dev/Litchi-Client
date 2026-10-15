import 'package:flutter/material.dart';

import '../theme/v3_motion.dart';
import '../theme/v3_palette.dart';

/// Shared dimensions for the new Dashboard and the other V3 pages.
/// LayoutBuilder widths are local pane widths, not the overall window width.
abstract final class V3Layout {
  static const double pageGutter = 18;
  static const double cardRadius = V3Radius.card;
  static const double cardGap = 12;

  /// Inner-padding tiers: workspace/card interiors, page panels, dialog and
  /// sheet bodies. One value per pattern — the round-2 audit found the same
  /// roles drifting across eight hand-written paddings (14/15/16/18/20/22/24/26).
  static const double cardPadding = 14;

  /// Matches [V3Panel]'s default padding — a token the panels drift from the
  /// moment it stops matching.
  static const double panelPadding = 20;
  static const double dialogPadding = 24;
  static const EdgeInsets pageInsets = EdgeInsets.fromLTRB(18, 18, 18, 28);

  /// Breakpoint for page content measured against the page's own width —
  /// the window minus the 200dp desktop rail, not the window. At the 900x700
  /// acceptance window the content pane is ~688dp, so pane breakpoints must
  /// stay well below that or pages render their phone layout on the desktop.
  static const double paneCompact = 560;

  static bool canSplit({
    required double paneWidth,
    required double primaryMin,
    required double secondaryMin,
    double gap = cardGap,
  }) => paneWidth - pageGutter * 2 >= primaryMin + secondaryMin + gap;
}

/// Exactly the Dashboard's visual card: dark hero, independently light surface.
class V3WorkspaceCard extends StatelessWidget {
  const V3WorkspaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        // Both modes elevate: the card sits one tonal step above the canvas,
        // and fills with the palette's two-step vertical wash ([V3Palette
        // .cardGradient]) instead of a flat color — light from above gives
        // the card quiet volume, the way DLSS5's glass cards and Apple's
        // materials shade themselves. The hairline rides on top: line and
        // light together are what keep it from reading flat.
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: p.cardGradient,
        ),
        borderRadius: BorderRadius.circular(V3Layout.cardRadius),
        border: Border.all(color: p.hairline),
        boxShadow: p.shadows,
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

/// The entrance animation a workspace page is running right now, provided by
/// the shell while the page surfaces from its Offstage stack. Cards hang
/// [V3Entrance]s off this one clock: a single timeline, staggered intervals
/// -- DLSS5's `.t2-panel > *` cascade (60ms a step) instead of every card
/// carrying its own controller.
class V3PageEntrance extends InheritedWidget {
  const V3PageEntrance({
    super.key,
    required this.animation,
    required super.child,
  });

  /// 0->1 across the page's whole entrance window (rise + full stagger).
  final Animation<double> animation;

  @override
  bool updateShouldNotify(V3PageEntrance oldWidget) => false;
}

/// One card in a page's landing wave: it fades in and rises while the page
/// entrance runs, [index] steps (60ms each) behind the first card. DLSS5's
/// signature move -- the page is not one slab that slams in, the content
/// lands in sequence, the way Fluent's entrance transitions and Apple's
/// spring-loaded views stage content. Outside a page entrance (dialogs,
/// fallback sheets, tests that mount a page bare) and under reduced motion
/// it is a passthrough.
class V3Entrance extends StatefulWidget {
  const V3Entrance({super.key, required this.index, required this.child});

  final int index;
  final Widget child;

  /// The page clock's window: 420ms of rise plus 60ms of stagger per step,
  /// capped at eight steps so very long pages still finish inside a second.
  static const int _totalMs = 900;
  static const int _riseMs = 420;
  static const int _stepMs = 60;

  /// Stages a page's top-level children into the landing wave: each child
  /// becomes a [V3Entrance] in list order. Pure spacing (a one-dimensional
  /// [SizedBox]) passes through unwrapped -- it has nothing to show and
  /// shouldn't burn a stagger step. Usage: `children: V3Entrance.wave([...])`
  /// on a page's main column.
  static List<Widget> wave(List<Widget> children) {
    var index = 0;
    return [
      for (final child in children)
        child is SizedBox && child.height != null && child.width == null
            ? child
            : V3Entrance(index: index++, child: child),
    ];
  }

  @override
  State<V3Entrance> createState() => _V3EntranceState();
}

class _V3EntranceState extends State<V3Entrance> {
  /// One curve per card, created once and disposed with the card: the parent
  /// (the page's shell-owned clock) and the stagger interval are stable for a
  /// card's lifetime, so nothing re-registers on the clock's listener list.
  /// The round-3 audit caught the previous build-time construction piling a
  /// fresh never-disposed [CurvedAnimation] onto the shell controller on
  /// every page rebuild.
  CurvedAnimation? _anim;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(V3Entrance oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The interval window follows the stagger index; the parent clock does
    // not change with the widget instance.
    if (oldWidget.index != widget.index) _sync(force: true);
  }

  void _sync({bool force = false}) {
    final scope = context.dependOnInheritedWidgetOfExactType<V3PageEntrance>();
    final parent = scope?.animation;
    if (parent == null || v3ReducedMotion(context)) {
      _disposeAnim();
      return;
    }
    final existing = _anim;
    if (!force && existing != null && identical(existing.parent, parent)) {
      return;
    }
    _disposeAnim();
    final startMs = (widget.index * V3Entrance._stepMs)
        .clamp(0, V3Entrance._totalMs - V3Entrance._riseMs);
    _anim = CurvedAnimation(
      parent: parent,
      curve: Interval(
        startMs / V3Entrance._totalMs,
        (startMs + V3Entrance._riseMs) / V3Entrance._totalMs,
        curve: V3Motion.spring,
      ),
    );
  }

  void _disposeAnim() {
    _anim?.dispose();
    _anim = null;
  }

  @override
  void dispose() {
    _disposeAnim();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final anim = _anim;
    if (anim == null) return widget.child;
    // 0.02 of the pane is DLSS5's 14px card lift, scaled; opacity rides the
    // same interval so the two stay in phase. Interval's endpoint shortcut
    // returns exactly 1.0 at rest, so settled pixels are identical.
    return FadeTransition(
      opacity: anim,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.02),
          end: Offset.zero,
        ).animate(anim),
        child: widget.child,
      ),
    );
  }
}

/// A [Column] whose children land in the page's staggered wave — drop-in for
/// a page's main column so `V3Entrance.wave` doesn't have to wrap the list
/// by hand. Behaves exactly like Column otherwise.
class V3WaveColumn extends StatelessWidget {
  const V3WaveColumn({
    super.key,
    this.mainAxisSize = MainAxisSize.max,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    required this.children,
  });

  final MainAxisSize mainAxisSize;
  final CrossAxisAlignment crossAxisAlignment;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: mainAxisSize,
      crossAxisAlignment: crossAxisAlignment,
      children: V3Entrance.wave(children),
    );
  }
}
