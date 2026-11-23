import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../../app/app_controller.dart';
import '../../l10n/app_locale_preference.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../l10n/generated/app_localizations_zh.dart';
import '../auth/v3_auth_view.dart';
import '../pages/v3_account_page.dart';
import '../pages/v3_dashboard_page.dart';
import '../pages/v3_gift_card_page.dart';
import '../pages/v3_invite_page.dart';
import '../pages/v3_more_page.dart';
import '../pages/v3_nodes_page.dart';
import '../pages/v3_orders_page.dart';
import '../pages/v3_settings_page.dart';
import '../pages/v3_shop_page.dart';
import '../pages/v3_tickets_page.dart';
import '../pages/v3_traffic_page.dart';
import '../theme/v3_palette.dart';
import '../theme/v3_motion.dart';
import '../ui/v3_dropdown.dart';
import '../ui/v3_notice_bar.dart';
import '../ui/v3_components.dart';
import '../ui/v3_layout.dart';
import '../ui/v3_locale_copy.dart';
import '../ui/v3_nav_island.dart';
import '../ui/v3_sheet.dart';
import 'v3_nav.dart';

bool get _isDesktopTarget =>
    !kIsWeb &&
    switch (defaultTargetPlatform) {
      TargetPlatform.windows ||
      TargetPlatform.macOS ||
      TargetPlatform.linux => true,
      _ => false,
    };

/// Pull-to-refresh belongs to the four data-centric mobile pages, not nodes.
bool v3SupportsMobileRefresh(AppPage page) => switch (page) {
  AppPage.dashboard ||
  AppPage.account ||
  AppPage.invite ||
  AppPage.traffic => true,
  _ => false,
};

/// The shell's three top surfaces. The key drives the stage cross-fade: boot
/// and login hand over to the workspace with a fade instead of a hard cut.
/// Height of the floating title strip. The workspace runs edge to edge under
/// it; page content insets below the strip so page-header actions never
/// share the strip with the window controls.
const double _kTitleOverlayHeight = 44;

/// macOS keeps the native traffic lights: the overlay hides its own window
/// buttons there and the rail drops below the lights instead of touching
/// the window top edge.
bool get _usesNativeWindowControls =>
    defaultTargetPlatform == TargetPlatform.macOS;

/// The shell's three top surfaces. The key drives the stage cross-fade: boot
/// and login hand over to the workspace with a fade instead of a hard cut.
enum _ShellStage { boot, auth, workspace }

class V3Shell extends StatelessWidget {
  const V3Shell({super.key, this.launchSilently = false});
  final bool launchSilently;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final stage = controller.isInitializing
        ? _ShellStage.boot
        : !controller.isAuthenticated
        ? _ShellStage.auth
        : _ShellStage.workspace;
    final body = AnimatedSwitcher(
      duration: V3Motion.medium,
      switchInCurve: V3Motion.ease,
      switchOutCurve: V3Motion.ease.flipped,
      // Expand, not the default loose stack: the workspace fills the pane and
      // short surfaces (boot view) must not center-shrink it during a fade.
      layoutBuilder: (currentChild, previousChildren) => Stack(
        fit: StackFit.expand,
        alignment: Alignment.center,
        children: [...previousChildren, ?currentChild],
      ),
      transitionBuilder: (child, animation) =>
          FadeTransition(opacity: animation, child: child),
      child: KeyedSubtree(
        key: ValueKey(stage),
        child: switch (stage) {
          _ShellStage.boot => const _V3BootView(),
          _ShellStage.auth => const V3AuthView(),
          _ShellStage.workspace => const V3NoticeHost(child: _V3Workspace()),
        },
      ),
    );
    if (!_isDesktopTarget) {
      return Material(
        color: V3Palette.of(context).canvas,
        child: SafeArea(bottom: false, child: body),
      );
    }
    return Material(
      color: V3Palette.of(context).canvas,
      // Chromeless top: the workspace runs edge to edge under a floating
      // title strip, and the rail's brand mark stays the app's single brand
      // surface.
      child: Stack(
        fit: StackFit.expand,
        children: [
          body,
          const Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: _kTitleOverlayHeight,
            child: _DesktopTitleOverlay(),
          ),
        ],
      ),
    );
  }
}

class _V3Workspace extends StatefulWidget {
  const _V3Workspace();
  @override
  State<_V3Workspace> createState() => _V3WorkspaceState();
}

class _V3WorkspaceState extends State<_V3Workspace> {
  // Pages stay mounted once visited, so scroll positions, form drafts and
  // per-tab state survive tab switches. Appending keeps element order stable.
  final List<AppPage> _visited = [];

  /// Reaches the first-run rail label peek from the rail's hover hook: a mouse
  /// move that reaches the rail is intent, and that dismisses the peek (the
  /// approved mockup's rail-mousemove rule; the panel's own Listener covers
  /// pointer-down, keyboard and wheel at the document level).
  final GlobalKey<V3RailPeekState> _peekKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final p = V3Palette.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
        final current = controller.page;
        if (!_visited.contains(current)) _visited.add(current);
        // StackFit.expand keeps every page's scroll view filling the pane: a
        // loose stack shrinks short pages (empty states, error states) to their
        // content height and the Offstage stack then centers them vertically —
        // tall pages top-align while short ones float mid-pane.
        final stack = Stack(
          fit: StackFit.expand,
          children: [
            for (final page in _visited)
              Offstage(
                offstage: page != current,
                // TickerMode mutes every AnimationController on mounted-but-
                // hidden pages: a backgrounded dashboard stops pulsing its orb
                // and ticking its notice lane instead of burning frames. The
                // page's own entrance re-forwards when it goes active again.
                child: TickerMode(
                  enabled: page == current,
                  child: _PageEntrance(
                    active: page == current,
                    child: _pageFor(page, context),
                  ),
                ),
              ),
          ],
        );
        if (compact) {
          final mobilePage =
              !_isDesktopTarget && v3SupportsMobileRefresh(current)
              ? RefreshIndicator(
                  key: const Key('v3-mobile-refresh'),
                  color: p.lychee,
                  onRefresh: controller.refreshData,
                  child: stack,
                )
              : stack;
          return Scaffold(
            backgroundColor: p.canvas,
            // The island floats: the body extends behind the bottom bar so
            // page content scrolls under it (§12.1#11). Pages keep their own
            // bottom insets; the injected MediaQuery bottom padding still
            // lets overlays (toasts) clear the island.
            extendBody: true,
            body: mobilePage,
            bottomNavigationBar: V3NavIsland(controller: controller),
          );
        }
        // 12 + 68 + 12 = 92dp for the entire desktop rail, not 92dp
        // plus margins. Keep the content's canvas black in dark mode.
        return ColoredBox(
          color: p.canvas,
          child: V3RailPeek(
            // The panel anchors to the rail's nav items: rail top margin
            // (macOS drops under the traffic lights) + padding 10 + brand 36
            // + gap 14 = 60 into the rail, and 12 + 68 + 8 = 88 across.
            top: (_usesNativeWindowControls ? 40 : 12) + 60,
            left: 12 + 68 + 8,
            child: Row(
              children: [
                MouseRegion(
                  // Moving toward the nav is intent: rail hover dismisses a
                  // pending or shown peek (the mockup's rail-mousemove rule).
                  onHover: (_) => _peekKey.currentState?.onInteraction(),
                  child: _DesktopRail(controller: controller),
                ),
                Expanded(
                  child: Padding(
                    // Content starts below the floating title strip, so page
                    // header actions never share a line with the window
                    // controls — the strip itself stays transparent canvas.
                    padding: const EdgeInsets.fromLTRB(
                      0,
                      _kTitleOverlayHeight,
                      12,
                      12,
                    ),
                    child: stack,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// One-shot entrance for a workspace page: each time a page surfaces from the
/// Offstage stack it rises ~18px and fades in over the first 420ms of the
/// window on the spring curve (DLSS5's `t2-page`: `.42s var(--spring)` from
/// `translateY(18px)`), and the same controller clocks the page's card
/// cascade through V3PageEntrance -- one timeline, staggered intervals, no
/// per-card clocks. The child subtree is untouched, so per-tab state (scroll
/// positions, form drafts) survives exactly as before.
class _PageEntrance extends StatefulWidget {
  const _PageEntrance({required this.active, required this.child});

  final bool active;
  final Widget child;

  @override
  State<_PageEntrance> createState() => _PageEntranceState();
}

class _PageEntranceState extends State<_PageEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    // The whole entrance window: 420ms of rise plus the 60ms-per-card
    // stagger, capped at eight steps (480ms), so even the longest page lands
    // inside a second.
    duration: const Duration(milliseconds: 900),
  );

  /// The page's own rise: the first 420ms of the window on the spring. The
  /// raw [_controller] is what the card cascade reads (via V3PageEntrance) --
  /// cards pick their own sub-intervals out of the full window.
  late final CurvedAnimation _rise = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0, 420 / 900, curve: V3Motion.spring),
  );

  @override
  void initState() {
    super.initState();
    // Pages join _visited the moment they become current, so creation and
    // first activation are the same event: play the entrance then, too.
    _controller.forward(from: 0);
  }

  @override
  void didUpdateWidget(_PageEntrance oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _rise.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Reduced motion: land on the final state directly, no clock at all.
    if (v3ReducedMotion(context)) return widget.child;
    return V3PageEntrance(
      animation: _controller,
      child: FadeTransition(
        opacity: _rise,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.026),
            end: Offset.zero,
          ).animate(_rise),
          child: widget.child,
        ),
      ),
    );
  }
}

Widget _pageFor(AppPage page, BuildContext context) {
  final l =
      Localizations.of<AppLocalizations>(context, AppLocalizations) ??
      AppLocalizationsZh();
  return switch (page) {
    AppPage.nodes => const V3NodesPage(),
    AppPage.shop => const V3ShopPage(),
    AppPage.account => const V3AccountPage(),
    AppPage.invite => const V3InvitePage(),
    AppPage.traffic => const V3TrafficPage(),
    AppPage.orders => V3SheetPageFallback(
      title: l.orders,
      child: const V3OrdersPage(),
    ),
    AppPage.tickets => const V3TicketsPage(),
    AppPage.settings => const V3SettingsPage(),
    AppPage.dashboard => const V3DashboardPage(),
    AppPage.more => const V3MorePage(),
    AppPage.giftCard => V3SheetPageFallback(
      title: v3Copy(context, zh: '礼品卡兑换', en: 'Gift card', tw: '禮品卡兌換'),
      child: const V3GiftCardPage(),
    ),
  };
}

class _DesktopRail extends StatelessWidget {
  const _DesktopRail({required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);

    // Desktop IA is one flat list. Eight destinations read as equals at a
    // glance — captioned groups earn their keep only in 15+-item enterprise
    // menus (Ant Pro), and at this size the 10px captions read as noise the
    // selection pill already answers (M3 navigation drawer, Linear).
    final items = enabledNavItems(kDesktopRail);
    // 44px item + 8px gap, matching _RailItem's bottom padding.
    const itemPitch = 52.0;
    final railChildren = <Widget>[];
    double? selectedTop;
    for (final (index, item) in items.indexed) {
      if (controller.page == item.page) selectedTop = index * itemPitch;
      railChildren.add(
        _RailItem(
          key: railItemKey(item.page),
          item: item,
          selected: controller.page == item.page,
          onTap: () => openV3Page(context, item.page),
        ),
      );
    }
    final user = controller.user;
    return Container(
      width: 68,
      // macOS traffic lights float over the top-left corner; the rail drops
      // under them. Windows draws nothing native, so the rail rides high —
      // its brand mark becomes the window's top-left anchor.
      margin: EdgeInsets.fromLTRB(
        12,
        _usesNativeWindowControls ? 40 : 12,
        12,
        12,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(V3Radius.panel),
        child: BackdropFilter(
          // §1.4's light glass: one static blur behind the glass fill — no
          // animation, so there is no per-frame re-blur to pay for.
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            // (68 - 44) / 2 = 12 on each side keeps every 44dp tile dead
            // centre; 10 top/bottom matches the mockup's rail padding, and
            // 10 + 36 + 14 = 60 puts the first tile exactly where V3RailPeek
            // anchors its rows.
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(
              color: p.glass,
              borderRadius: BorderRadius.circular(V3Radius.panel),
              border: Border.all(color: p.glassBorder),
              boxShadow: p.shadows,
            ),
            child: Column(
              children: [
                const _RailBrandMark(),
                const SizedBox(height: 14),
                // The items sit in a Stack so the shared selection pill can
                // slide underneath them (see _RailPill) -- one indicator for
                // the whole rail, DLSS5's dock-glow. The rail's build loop
                // above owns the item order and the pill's offsets.
                Stack(
                  children: [
                    _RailPill(selectedTop: selectedTop),
                    Column(children: railChildren),
                  ],
                ),
                const Spacer(),
                // The account avatar is the rail's only bottom-anchored
                // element; Settings is a peer destination and lives in the
                // flat list above.
                Container(
                  key: kAccountCardKey,
                  child: Semantics(
                    container: true,
                    button: true,
                    selected: controller.page == AppPage.account,
                    label: user.name.isEmpty
                        ? v3Copy(context, zh: '访客', en: 'Guest', tw: '訪客')
                        : user.name,
                    child: V3Pressable(
                      borderRadius: BorderRadius.circular(V3Radius.field),
                      hoverTint: p.ink.withValues(alpha: 0.08),
                      onTap: () => controller.goToPage(AppPage.account),
                      child: Tooltip(
                        message: user.name.isEmpty
                            ? v3Copy(context, zh: '访客', en: 'Guest', tw: '訪客')
                            : user.name,
                        child: CircleAvatar(
                          radius: 18,
                          backgroundColor: p.lychee,
                          child: Text(
                            user.avatarLetter.isEmpty ? '?' : user.avatarLetter,
                            style: TextStyle(
                              color: p.onLychee,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // Rail footer: the core's liveness as a quiet dot. The 68dp
                // rail has no room for the status text or the version number —
                // both yield to a tooltip; the version already shows on the
                // settings page (§2.1).
                Tooltip(
                  message: v3Copy(
                    context,
                    zh: controller.coreProcessRunning ? '核心运行中' : '核心已停止',
                    en: controller.coreProcessRunning
                        ? 'Core running'
                        : 'Core stopped',
                    tw: controller.coreProcessRunning ? '核心運行中' : '核心已停止',
                  ),
                  child: _CoreDot(
                    running: controller.coreProcessRunning,
                    color: p.successInk,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The rail's 36dp brand mark: icon only at 68dp — the wordmark needs a wider
/// rail than the glass strip offers, so V3BrandMark's caption stays on the
/// auth view and the boot screen.
class _RailBrandMark extends StatelessWidget {
  const _RailBrandMark();

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return SizedBox(
      width: 36,
      height: 36,
      child: Image.asset(
        'assets/images/app_icon.png',
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => Container(
          decoration: BoxDecoration(
            color: p.citrus,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.blur_on_rounded, color: p.night, size: 24),
        ),
      ),
    );
  }
}

/// The rail footer's core-liveness dot. When the core comes alive it throws
/// two soft rings out once, then sits still — a steady state does not need an
/// ongoing advertisement, and a finite animation keeps test `pumpAndSettle`s
/// settling (a DLSS5-style infinite pulse would hang them).
class _CoreDot extends StatefulWidget {
  const _CoreDot({required this.running, required this.color});
  final bool running;
  final Color color;
  @override
  State<_CoreDot> createState() => _CoreDotState();
}

class _CoreDotState extends State<_CoreDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rings = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );
  bool _wasRunning = false;

  @override
  void didUpdateWidget(_CoreDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reduced motion: no ring burst -- the dot stays the static 6px mark.
    if (widget.running && !_wasRunning && !v3ReducedMotion(context)) {
      _rings.forward(from: 0);
    }
    _wasRunning = widget.running;
  }

  @override
  void dispose() {
    _rings.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    // Reduced motion: no ring branch at all, just the static 6px dot.
    final reduced = v3ReducedMotion(context);
    return SizedBox(
      width: 6,
      height: 6,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (widget.running && !reduced)
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _rings,
                builder: (context, _) {
                  final t = _rings.value;
                  final phase = (t * 2) % 1; // two rings across the run
                  return Transform.scale(
                    scale: 1 + phase * 2.2,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: widget.color.withValues(
                            alpha: 0.5 * (1 - phase),
                          ),
                          width: 1,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          Center(
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.running ? widget.color : p.inkMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RailItem extends StatefulWidget {
  const _RailItem({
    super.key,
    required this.item,
    required this.selected,
    required this.onTap,
  });
  final V3NavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_RailItem> createState() => _RailItemState();
}

class _RailItemState extends State<_RailItem> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(end: widget.selected ? 1 : 0),
        duration: v3ReducedMotion(context) ? Duration.zero : V3Motion.fast,
        curve: V3Motion.ease,
        builder: (context, t, _) {
          // Unselected rides inkMuted and lifts to ink on hover; selected
          // lands on the palette-safe coral ink the shared lycheeSoft pill
          // sits under.
          final atRest = _hovering ? p.ink : p.inkMuted;
          final iconColor = Color.lerp(atRest, p.lycheeInk, t)!;
          // V3Pressable keeps the press ink above the shared selection pill
          // instead of losing it under the rail's glass.
          // Round-3 audit F10: the selected flag is what announces the
          // current page to assistive tech — color alone carries nothing.
          // The wrapper is a semantics boundary; the tap action still comes
          // from the inner InkWell's merged node, so it does not repeat
          // onTap — duplicated handlers fire twice per assistive-tech
          // activation. The 68dp rail has no captions, so the label rides on
          // the semantics node itself; the tooltip shows it to sighted users.
          return Semantics(
            container: true,
            button: true,
            selected: widget.selected,
            label: widget.item.localizedLabel(context),
            child: Tooltip(
              message: widget.item.localizedLabel(context),
              child: MouseRegion(
                onEnter: (_) => setState(() => _hovering = true),
                onExit: (_) => setState(() => _hovering = false),
                child: V3Pressable(
                  borderRadius: BorderRadius.circular(V3Radius.field),
                  hoverTint: p.ink.withValues(alpha: 0.08),
                  onTap: widget.onTap,
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: Center(
                      child: Icon(widget.item.icon, color: iconColor, size: 20),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// The floating title strip: an invisible drag surface across the top of the
/// window with gift, theme and language controls plus the window buttons
/// floating at the right edge. There is no bar behind them — the workspace
/// shows through, and the rail's brand mark above it is the only brand.
class _DesktopTitleOverlay extends StatefulWidget {
  const _DesktopTitleOverlay();
  @override
  State<_DesktopTitleOverlay> createState() => _DesktopTitleOverlayState();
}

class _DesktopTitleOverlayState extends State<_DesktopTitleOverlay>
    with WindowListener {
  bool _maximized = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    // Route every close path (title-bar button, Alt+F4, taskbar) through the
    // same quit choreography — an unguarded native close destroys the
    // process without restoring the system proxy.
    try {
      windowManager.setPreventClose(true).ignore();
    } catch (_) {
      // Native window APIs are unavailable in widget tests.
    }
    _syncWindowState();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  Future<void> _syncWindowState() async {
    try {
      final maximized = await windowManager.isMaximized();
      if (mounted && maximized != _maximized) {
        setState(() => _maximized = maximized);
      }
    } catch (_) {
      // Native window APIs are unavailable in widget tests.
    }
  }

  Future<void> _toggleMaximize() async {
    try {
      if (await windowManager.isMaximized()) {
        await windowManager.unmaximize();
      } else {
        await windowManager.maximize();
      }
    } catch (_) {
      // Native window APIs are unavailable in widget tests.
    }
  }

  bool _quitting = false;

  /// Remove the visible UI first so a quit feels immediate, then run the
  /// cleanup behind the hidden window, then destroy. The bounded timeout
  /// keeps the exit unconditional.
  Future<void> _quitApp() async {
    if (_quitting) return;
    _quitting = true;
    // Capture before the hide: no BuildContext reads across async gaps.
    final controller = AppScope.of(context);
    try {
      await windowManager.hide();
    } catch (_) {
      // Native window APIs are unavailable in widget tests.
    }
    try {
      await controller.shutdown().timeout(
        const Duration(seconds: 4),
        onTimeout: () {},
      );
    } catch (_) {
      // Shutdown must never block the exit; the OS reaps the core process
      // when this process dies.
    }
    try {
      await windowManager.destroy();
    } catch (_) {
      // Native window APIs are unavailable in widget tests.
    }
  }

  Future<void> _closeWindow() => _quitApp();

  @override
  void onWindowClose() {
    // setPreventClose routes the native close paths here.
    _quitApp();
  }

  @override
  void onWindowMaximize() {
    if (mounted && !_maximized) setState(() => _maximized = true);
  }

  @override
  void onWindowUnmaximize() {
    if (mounted && _maximized) setState(() => _maximized = false);
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    // Redemption stays a window-level shortcut; the key keeps the reachability
    // contract able to hold it from the strip.
    final giftEntry =
        isPageEnabled(AppPage.giftCard) && controller.isAuthenticated;
    // The gift button sits OUTSIDE the drag surface: a double-tap recognizer
    // on its ancestor enters the gesture arena and delays or swallows the
    // button's single tap.
    final dragSurface = GestureDetector(
      behavior: HitTestBehavior.translucent,
      onPanStart: (_) => windowManager.startDragging(),
      onDoubleTap: _toggleMaximize,
      child: const SizedBox.expand(),
    );
    return Row(
      children: [
        Expanded(child: dragSurface),
        if (giftEntry) ...[
          _OverlayIconButton(
            key: kWindowGiftCardKey,
            tooltip: v3Copy(context, zh: '兑换中心', en: 'Redemption', tw: '兌換中心'),
            icon: Icons.redeem_rounded,
            iconColor: V3Palette.of(context).inkMuted,
            onPressed: () => openV3Page(context, AppPage.giftCard),
          ),
          const SizedBox(width: 4),
        ],
        const _ThemeOverlayButton(),
        const _LanguageOverlayButton(),
        if (!_usesNativeWindowControls) ...[
          const SizedBox(width: 4),
          _V3WindowButton(
            tooltip: v3Copy(context, zh: '最小化', en: 'Minimize', tw: '最小化'),
            icon: Icons.remove_rounded,
            onPressed: windowManager.minimize,
          ),
          _V3WindowButton(
            tooltip: _maximized
                ? v3Copy(context, zh: '还原', en: 'Restore', tw: '還原')
                : v3Copy(context, zh: '最大化', en: 'Maximize', tw: '最大化'),
            icon: _maximized
                ? Icons.filter_none_rounded
                : Icons.crop_square_rounded,
            onPressed: _toggleMaximize,
          ),
          _V3WindowButton(
            tooltip: v3Copy(context, zh: '关闭', en: 'Close', tw: '關閉'),
            icon: Icons.close_rounded,
            close: true,
            onPressed: _closeWindow,
          ),
        ],
      ],
    );
  }
}

/// Ghost icon button for the title strip: no chrome at rest, the theme's
/// hover/press ink alone marks it. Shared by the gift and theme controls so
/// the strip keeps one control spec.
class _OverlayIconButton extends StatelessWidget {
  const _OverlayIconButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.iconColor,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return Tooltip(
      message: tooltip,
      child: V3Pressable(
        borderRadius: BorderRadius.circular(V3Radius.control),
        onTap: onPressed,
        child: SizedBox(
          width: 34,
          height: 34,
          child: Icon(icon, size: 18, color: iconColor ?? p.inkMuted),
        ),
      ),
    );
  }
}

/// The sun/moon quick toggle. Theme.of reports the resolved brightness (a
/// system preference included), so the tap flips from what the user actually
/// sees and settles on an explicit light or dark choice.
class _ThemeOverlayButton extends StatelessWidget {
  const _ThemeOverlayButton();

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return _OverlayIconButton(
      tooltip: v3Copy(
        context,
        zh: dark ? '切换为浅色模式' : '切换为深色模式',
        en: dark ? 'Switch to light mode' : 'Switch to dark mode',
        tw: dark ? '切換為淺色模式' : '切換為深色模式',
      ),
      icon: dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
      onPressed: () =>
          controller.setThemeMode(dark ? ThemeMode.light : ThemeMode.dark),
    );
  }
}

/// The language quick switch: a two-letter code for the tongue the UI is
/// drawing in (CN/TW/EN -- the resolved locale, so a system preference shows
/// through), opening a menu that lists every preference in its own tongue.
class _LanguageOverlayButton extends StatelessWidget {
  const _LanguageOverlayButton();

  String _menuLabel(AppLocalePreference pref, BuildContext context) =>
      switch (pref) {
        AppLocalePreference.system => v3Copy(
          context,
          zh: '跟随系统',
          en: 'System default',
          tw: '跟隨系統',
        ),
        // Each language names itself; no localization applies.
        AppLocalePreference.simplifiedChinese => '简体中文',
        AppLocalePreference.traditionalChinese => '繁體中文',
        AppLocalePreference.english => 'English',
      };

  String _resolveCode(BuildContext context) {
    final locale = Localizations.localeOf(context);
    if (locale.languageCode != 'zh') return 'EN';
    final script = locale.scriptCode;
    final country = locale.countryCode;
    return script == 'Hant' ||
            country == 'TW' ||
            country == 'HK' ||
            country == 'MO'
        ? 'TW'
        : 'CN';
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final resolved = _resolveCode(context);
    return V3Dropdown<AppLocalePreference>(
      value: controller.language,
      items: AppLocalePreference.values,
      face: (pref) => switch (pref) {
        AppLocalePreference.system => resolved,
        AppLocalePreference.simplifiedChinese => 'CN',
        AppLocalePreference.traditionalChinese => 'TW',
        AppLocalePreference.english => 'EN',
      },
      label: (pref) => _menuLabel(pref, context),
      onChanged: controller.setLanguage,
      dense: true,
      menuWidth: 168,
      tooltip: v3Copy(context, zh: '语言', en: 'Language', tw: '語言'),
    );
  }
}

class _V3WindowButton extends StatelessWidget {
  const _V3WindowButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.close = false,
  });
  final String tooltip;
  final IconData icon;
  final Future<void> Function() onPressed;
  final bool close;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return SizedBox(
      width: 46,
      height: _kTitleOverlayHeight,
      child: IconButton(
        tooltip: tooltip,
        padding: EdgeInsets.zero,
        // The close button follows the Windows convention (Win11's danger
        // red on hover): at rest it reads as chrome like its siblings — the
        // resting brand-pink glyph borrowed a CTA slot the palette reserves
        // for selection and actions. onDanger keeps the glyph legible over
        // the danger fill in both themes.
        style: ButtonStyle(
          shape: const WidgetStatePropertyAll(RoundedRectangleBorder()),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (close) {
              return states.contains(WidgetState.hovered) ||
                      states.contains(WidgetState.pressed)
                  ? p.onDanger
                  : p.inkMuted;
            }
            return p.inkMuted;
          }),
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (close) {
              return states.contains(WidgetState.hovered) ||
                      states.contains(WidgetState.pressed)
                  ? p.danger
                  : null;
            }
            return states.contains(WidgetState.hovered)
                ? p.surfaceRaised
                : states.contains(WidgetState.pressed)
                ? p.line
                : null;
          }),
        ),
        onPressed: () => unawaited(onPressed()),
        icon: Icon(icon, size: 17),
      ),
    );
  }
}

class _V3BootView extends StatelessWidget {
  const _V3BootView();

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return ColoredBox(
      color: p.hero,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: p.citrus,
                borderRadius: BorderRadius.circular(V3Radius.card),
              ),
              child: Icon(Icons.blur_on_rounded, color: p.night, size: 34),
            ),
            const SizedBox(height: 18),
            Text(
              'LITCHI',
              style: TextStyle(
                color: p.ink,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: 3,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: 90,
              child: LinearProgressIndicator(
                minHeight: 3,
                color: p.lycheeInk,
                backgroundColor: p.ink.withValues(alpha: 0.15),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The rail's one selection indicator: a single pill that slides from the
/// item you left to the one you pressed instead of blinking between them --
/// DLSS5's dock-glow, the same mechanics as Ant's ink-bar and M3's sliding
/// tabs indicator. The pill remembers its last valid position while hidden
/// (sub-pages have no rail item), so coming back it slides from where it left.
class _RailPill extends StatefulWidget {
  const _RailPill({required this.selectedTop});

  /// The selected item's top offset inside the rail's item stack, or null
  /// when nothing is selected (sub-pages have no rail item). The rail's
  /// build loop computes it from the flat item pitch, so the pill and the
  /// items share one source of truth.
  final double? selectedTop;

  @override
  State<_RailPill> createState() => _RailPillState();
}

class _RailPillState extends State<_RailPill> {
  double _top = 0;
  bool _visible = false;

  void _sync() {
    final top = widget.selectedTop;
    if (top != null) {
      _top = top;
      _visible = true;
    } else {
      _visible = false;
    }
  }

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(_RailPill oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return AnimatedPositioned(
      duration: V3Motion.medium,
      curve: V3Motion.spring,
      top: _top,
      left: 0,
      right: 0,
      height: 44,
      child: AnimatedOpacity(
        duration: V3Motion.fast,
        curve: V3Motion.ease,
        opacity: _visible ? 1 : 0,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: p.lycheeSoft,
            borderRadius: BorderRadius.circular(V3Radius.field),
          ),
        ),
      ),
    );
  }
}
