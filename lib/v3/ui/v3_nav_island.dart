import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:ios26_bottom_navigationbar/ios26_bottom_navigationbar.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/app_controller.dart';
import '../../config/app_identity.dart';
import '../app/v3_nav.dart';
import '../theme/v3_motion.dart';
import '../theme/v3_palette.dart';

/// Mobile floating dock: use the iOS26 navigation component directly.
/// The desktop navigation rail below is intentionally unchanged.
class V3NavIsland extends StatelessWidget {
  const V3NavIsland({super.key, required this.controller});

  final AppController controller;

  int get selectedIndex => selectedPrimaryIndex(controller.page) ?? 0;

  static IconData _iconFor(AppPage page) => switch (page) {
    AppPage.dashboard => LucideIcons.house,
    AppPage.nodes => LucideIcons.server,
    AppPage.shop => LucideIcons.crown,
    AppPage.account => LucideIcons.userRound,
    _ => LucideIcons.house,
  };

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    final items = enabledNavItems(kMobilePrimary);
    if (items.isEmpty) return const SizedBox.shrink();

    final style = IOS26NavThemeData.light(
      activeColor: p.lycheeInk,
      inactiveColor: p.inkMuted,
      backgroundColor: p.glass,
      indicatorColor: p.lychee.withValues(alpha: 0.16),
      borderColor: p.glassBorder,
      borderWidth: 1,
      height: 62,
      borderRadius: BorderRadius.circular(30),
      labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
      selectedLabelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
    ).copyWith(
      margin: const EdgeInsets.symmetric(horizontal: 14),
      padding: const EdgeInsets.all(5),
      iconSize: 22,
      selectedIconScale: 1.08,
      labelSpacing: 3,
      showLabels: true,
      showSelectedLabels: true,
      showUnselectedLabels: true,
      indicatorBorderRadius: BorderRadius.circular(25),
      indicatorPadding: const EdgeInsets.symmetric(vertical: 2, horizontal: 1),
      blurSigmaX: 18,
      blurSigmaY: 18,
      boxShadow: p.shadows,
      indicatorAnimationDuration: const Duration(milliseconds: 280),
      enableAmbientFade: false,
    );

    // The Scaffold owns the bottom-navigation slot. SafeArea consumes the
    // Android gesture/navigation inset once; do not stack another inset.
    return SafeArea(
      top: false,
      left: false,
      right: false,
      child: Padding(
        padding: const EdgeInsets.only(top: 6, bottom: 6),
        child: IOS26BottomNavigationBar(
          currentIndex: selectedIndex.clamp(0, items.length - 1),
          onTap: (index) => controller.goToPage(items[index].page),
          items: [
            for (final item in items)
              IOS26NavItem.icon(
                icon: _iconFor(item.page),
                label: item.localizedLabel(context),
              ),
          ],
          style: style,
        ),
      ),
    );
  }
}

/// The first-run rail label peek (§11.5): on a fresh install the desktop rail
/// is icon-only, so ~700ms after the workspace first paints a floating glass
/// card beside the rail fades in, listing every rail label at the rail's item
/// pitch. It fades out after a 1.5s hold, on any pointer/keyboard interaction,
/// or at the 2.5s cap — whichever comes first — and the `railPeekSeen` flag is
/// written only once the fade-out has completed, so a crash mid-peek still
/// shows the labels on the next launch. Reduced motion hard-cuts the
/// appear/disappear instead of skipping it (§11.5 rule 5).
///
/// The panel rides above the whole desktop workspace: [child] is the
/// workspace itself, wrapped in the interaction listeners that dismiss the
/// peek. Rail geometry (where the panel anchors) is computed by the shell,
/// which owns the rail's numbers.
class V3RailPeek extends StatefulWidget {
  const V3RailPeek({
    super.key,
    required this.top,
    required this.left,
    required this.child,
  });

  /// The panel's top offset from the window top — the rail's top margin plus
  /// the rail-internal offset of the first nav item, so the rows line up with
  /// the rail's 52dp item pitch.
  final double top;

  /// The panel's left offset — the rail's 12 margin + 68 width + an 8dp gap.
  final double left;

  /// The whole desktop workspace. The wrapper listens for the interactions
  /// that dismiss the peek without ever blocking the workspace's own events.
  final Widget child;

  @override
  State<V3RailPeek> createState() => V3RailPeekState();
}

class V3RailPeekState extends State<V3RailPeek> {
  static const _prefKey = 'rail_peek_seen';

  /// Mockup `.js-peek`: 300ms fade, ~700ms to first paint, 1.5s hold. The cap
  /// lands where the natural timeline ends: 700 + 300 + 1500 = 2.5s.
  static const _showDelay = Duration(milliseconds: 700);
  static const _fade = Duration(milliseconds: 300);
  static const _hold = Duration(milliseconds: 1500);
  static const _panelWidth = 150.0;

  /// The panel is in the tree: armed, fading in, shown, or fading out.
  bool _inTree = false;

  /// The fade-in has been triggered; opacity reads [true] from here on.
  bool _visible = false;

  /// The peek decided its fate — no more timers, no more state changes.
  bool _done = false;

  Timer? _showTimer;
  Timer? _capTimer;
  Timer? _writeTimer;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKeyEvent);
    _arm();
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKeyEvent);
    _cancelTimers();
    super.dispose();
  }

  Future<void> _arm() async {
    bool seen;
    try {
      final prefs = await SharedPreferences.getInstance();
      seen = prefs.getBool(AppIdentity.preferenceKey(_prefKey)) ?? false;
    } catch (_) {
      // Persistence unavailable (an environment without the plugin, such as a
      // widget test): the peek no-ops, exactly like the mockup's guarded
      // localStorage read. Goldens and shell tests stay untouched.
      return;
    }
    if (!mounted || seen || _done) return;
    setState(() => _inTree = true);
    _showTimer = Timer(_showDelay, () {
      if (mounted && !_done) setState(() => _visible = true);
    });
    _capTimer = Timer(_showDelay + _fade + _hold, _dismiss);
  }

  /// Any pointer or keyboard interaction, plus a mouse move that reaches the
  /// rail (the shell wires that one in — moving toward the nav is intent).
  /// Before the fade-in it cancels the peek entirely: nothing shown, nothing
  /// written. After it, the panel fades out and the flag is written late.
  void onInteraction() {
    if (!mounted || _done || !_inTree) return;
    if (!_visible) {
      _done = true;
      _cancelTimers();
      setState(() => _inTree = false);
      return;
    }
    _dismiss();
  }

  bool _onKeyEvent(KeyEvent event) {
    onInteraction();
    // Never consume: the peek is a passive observer.
    return false;
  }

  void _dismiss() {
    if (!mounted || _done || !_visible) return;
    _done = true;
    _cancelTimers();
    setState(() => _visible = false);
    // The flag is written only after the fade-out completes (§11.5 rule 3) --
    // a crash before this point leaves the peek armed for the next launch.
    _writeTimer = Timer(fadeDuration, _persist);
  }

  void _cancelTimers() {
    _showTimer?.cancel();
    _showTimer = null;
    _capTimer?.cancel();
    _capTimer = null;
    _writeTimer?.cancel();
    _writeTimer = null;
  }

  Future<void> _persist() async {
    if (mounted) setState(() => _inTree = false);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(AppIdentity.preferenceKey(_prefKey), true);
    } catch (_) {
      // Same contract as the read: an environment without persistence simply
      // never suppresses the peek.
    }
  }

  Duration get fadeDuration => v3ReducedMotion(context) ? Duration.zero : _fade;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    final items = enabledNavItems(kDesktopRail);
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => onInteraction(),
      // Wheel/trackpad scrolling is interaction; plain mouse moves over
      // content are not (the mockup only dismisses on rail mousemove).
      onPointerSignal: (_) => onInteraction(),
      child: Stack(
        fit: StackFit.expand,
        children: [
          widget.child,
          if (_inTree)
            Positioned(
              left: widget.left,
              top: widget.top,
              width: _panelWidth,
              child: IgnorePointer(child: _panel(p, items)),
            ),
        ],
      ),
    );
  }

  Widget _panel(V3Palette p, List<V3NavItem> items) {
    return AnimatedOpacity(
      duration: fadeDuration,
      curve: V3Motion.ease,
      opacity: _visible ? 1 : 0,
      child: AnimatedSlide(
        duration: fadeDuration,
        curve: V3Motion.ease,
        // -6px of the 150dp panel, the mockup's approach slide.
        offset: _visible ? Offset.zero : const Offset(-0.04, 0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(V3Radius.field),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: p.glass,
                borderRadius: BorderRadius.circular(V3Radius.field),
                border: Border.all(color: p.glassBorder),
                boxShadow: p.shadows,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // One row per rail item, at the rail's 52dp pitch, so the
                  // labels read as captions of the glyphs beside them.
                  for (final (index, item) in items.indexed)
                    Container(
                      height: 44,
                      margin: index == items.length - 1
                          ? null
                          : const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.only(left: 14),
                      alignment: Alignment.centerLeft,
                      child: Text(
                        item.localizedLabel(context),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: p.ink,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
