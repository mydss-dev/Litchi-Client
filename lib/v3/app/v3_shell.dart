import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../../app/app_controller.dart';
import '../../app/plan_presentation.dart';
import '../../config/app_config.dart';
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
import '../ui/v3_notice_bar.dart';
import '../ui/v3_components.dart';
import '../ui/v3_locale_copy.dart';
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
      duration: const Duration(milliseconds: 240),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeOutCubic.flipped,
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
      // Chromeless top, DLSS5-style: the workspace runs edge to edge under a
      // floating title strip — the shell no longer owns a full-width bar,
      // and the rail's brand mark stays the app's single brand surface.
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
                child: _PageEntrance(
                  active: page == current,
                  child: _pageFor(page, context),
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
            body: mobilePage,
            bottomNavigationBar: _MobileNavigation(controller: controller),
          );
        }
        // 12 + 176 + 12 = 200dp for the entire desktop rail, not 200dp
        // plus margins. Keep the content's canvas black in dark mode.
        return ColoredBox(
          color: p.canvas,
          child: Row(
            children: [
              _DesktopRail(controller: controller),
              Expanded(
                child: Padding(
                  // Content starts below the floating title strip, so page
                  // header actions never share a line with the window
                  // controls — the strip itself stays transparent canvas.
                  padding: const EdgeInsets.fromLTRB(0, _kTitleOverlayHeight, 12, 12),
                  child: stack,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// One-shot entrance for a workspace page: each time a page surfaces from the
/// Offstage stack it fades in and rises a step instead of hard-cutting. The
/// child subtree is untouched, so per-tab state (scroll positions, form
/// drafts) survives exactly as before.
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
    duration: const Duration(milliseconds: 180),
  );
  late final Animation<double> _ease = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
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
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _ease,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.015),
          end: Offset.zero,
        ).animate(_ease),
        child: widget.child,
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
      kicker: v3Copy(context, zh: '订单中心', en: 'ORDER CENTER', tw: '訂單中心'),
      title: l.orders,
      description: v3Copy(
        context,
        zh: '所有购买记录和支付状态都集中在这里。',
        en: 'Every purchase and its payment status in one place.',
        tw: '所有購買紀錄與付款狀態集中在這裡。',
      ),
      child: const V3OrdersPage(),
    ),
    AppPage.tickets => const V3TicketsPage(),
    AppPage.settings => const V3SettingsPage(),
    AppPage.dashboard => const V3DashboardPage(),
    AppPage.more => const V3MorePage(),
    AppPage.giftCard => V3SheetPageFallback(
      kicker: v3Copy(context, zh: '兑换中心', en: 'REDEMPTION', tw: '兌換中心'),
      title: v3Copy(context, zh: '礼品卡兑换', en: 'Gift card', tw: '禮品卡兌換'),
      description: v3Copy(
        context,
        zh: '输入兑换码，权益到账后自动同步到账户。',
        en: 'Enter a code; benefits sync to your account automatically.',
        tw: '輸入兌換碼，權益到賬後自動同步到帳戶。',
      ),
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
    final user = controller.user;
    final plan = PlanPresentation.fromController(controller);
    return Container(
      width: 176,
      // macOS traffic lights float over the top-left corner; the rail drops
      // under them. Windows draws nothing native, so the rail rides high —
      // its brand mark becomes the window's top-left anchor.
      margin: EdgeInsets.fromLTRB(
        12,
        _usesNativeWindowControls ? 40 : 12,
        12,
        12,
      ),
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
      decoration: BoxDecoration(
        color: p.hero,
        borderRadius: BorderRadius.circular(V3Radius.card),
        border: Border.all(color: p.hairline),
        boxShadow: p.shadows,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(2, 0, 2, 26),
            child: V3BrandMark(boxSize: 34),
          ),
          ...[
            // Dashboard and connection are the same AppPage.dashboard route.
            // Never introduce a second Home item alongside Connect.
            ...enabledNavItems(kDesktopRail),
            if (kRailSettings.isEnabled) kRailSettings,
          ].map(
            (item) => _RailItem(
              key: railItemKey(item.page),
              item: item,
              selected: controller.page == item.page,
              onTap: () => openV3Page(context, item.page),
            ),
          ),
          const Spacer(),
          const SizedBox(height: 12),
          Container(
            key: kAccountCardKey,
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(V3Radius.card),
            ),
            child: V3Pressable(
              borderRadius: BorderRadius.circular(V3Radius.card),
              onTap: () => controller.goToPage(AppPage.account),
              child: Padding(
                padding: const EdgeInsets.all(9),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 17,
                      backgroundColor: p.lychee,
                      child: Text(
                        user.avatarLetter.isEmpty ? '?' : user.avatarLetter,
                        style: TextStyle(
                          color: p.onLychee,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.name.isEmpty
                                ? v3Copy(
                                    context,
                                    zh: '访客',
                                    en: 'Guest',
                                    tw: '訪客',
                                  )
                                : user.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: p.ink,
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Tooltip(
                            message: '${plan.shortLabel} · ${plan.expiry}',
                            child: Text(
                              plan.shortLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: plan.usable ? p.successInk : p.inkMuted,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: p.ink.withValues(alpha: 0.45),
                      size: 16,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Rail footer, DLSS5-style: the core's liveness as a quiet dot +
          // label, with the app version as the last word. Shares the account
          // card's muted voice so it reads as chrome, not content; the dot
          // follows the same liveness signal the connection card reports.
          Row(children: [
            _CoreDot(
              running: controller.coreProcessRunning,
              color: p.successInk),
            const SizedBox(width: 6),
            Expanded(child: Text(
              v3Copy(context,
                zh: controller.coreProcessRunning ? '核心运行中' : '核心已停止',
                en: controller.coreProcessRunning ? 'Core running' : 'Core stopped',
                tw: controller.coreProcessRunning ? '核心運行中' : '核心已停止'),
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(color: p.inkMuted, fontSize: 10))),
            if (AppConfig.currentVersion.trim().isNotEmpty)
              Text(AppConfig.currentVersion.trim(),
                style: TextStyle(
                  color: p.inkMuted.withValues(alpha: 0.72),
                  fontSize: 10)),
          ]),
        ],
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
    if (widget.running && !_wasRunning) _rings.forward(from: 0);
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
    return SizedBox(
      width: 6,
      height: 6,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (widget.running)
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
                          color: widget.color
                              .withValues(alpha: 0.5 * (1 - phase)),
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

class _RailItem extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(end: selected ? 1 : 0),
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        builder: (context, t, _) {
          final iconColor = Color.lerp(p.inkMuted, p.lycheeInk, t)!;
          final textColor = Color.lerp(p.inkMuted, p.ink, t)!;
          // V3Pressable keeps the press ink above the animated selection
          // fill instead of losing it under the rail's opaque hero.
          return Container(
            height: 44,
            decoration: BoxDecoration(
              color: p.lycheeSoft.withValues(alpha: t),
              borderRadius: BorderRadius.circular(V3Radius.field),
            ),
            // The padding rides inside the pressable so the ink covers the
            // full item rect — an outer padding inset the ink inside the
            // selection pill it should preview.
            child: V3Pressable(
              borderRadius: BorderRadius.circular(V3Radius.field),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(
                  children: [
                    Icon(item.icon, color: iconColor, size: 19),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        item.localizedLabel(context),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MobileNavigation extends StatelessWidget {
  const _MobileNavigation({required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    final pages = enabledNavItems(kMobilePrimary);
    return NavigationBar(
      height: 72,
      backgroundColor: p.surface,
      indicatorColor: p.lycheeSoft,
      selectedIndex: selectedPrimaryIndex(controller.page) ?? 0,
      onDestinationSelected: (index) => controller.goToPage(pages[index].page),
      destinations: [
        for (final item in pages)
          NavigationDestination(
            icon: Icon(item.icon),
            selectedIcon: Icon(item.icon, color: p.lycheeInk),
            label: item.localizedLabel(context),
          ),
      ],
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

  /// The legacy quit order, re-adopted: remove the visible UI first so a
  /// quit feels immediate, then run the cleanup behind the hidden window,
  /// then destroy. A slow core teardown can no longer freeze the window on
  /// screen, and the bounded timeout keeps the exit unconditional.
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
            tooltip: v3Copy(
              context,
              zh: '兑换中心',
              en: 'Redemption',
              tw: '兌換中心',
            ),
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

/// The language quick switch: the face names the language the UI is drawing
/// in right now (the resolved locale, so a system preference shows through),
/// and the menu lists every preference, each labelled in its own tongue —
/// the way platform settings do it.
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

  String _faceLabel(BuildContext context) {
    final locale = Localizations.localeOf(context);
    if (locale.languageCode != 'zh') return 'EN';
    final script = locale.scriptCode;
    final country = locale.countryCode;
    return script == 'Hant' ||
            country == 'TW' ||
            country == 'HK' ||
            country == 'MO'
        ? '繁'
        : '中';
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final p = V3Palette.of(context);
    return PopupMenuButton<AppLocalePreference>(
      tooltip: v3Copy(context, zh: '语言', en: 'Language', tw: '語言'),
      position: PopupMenuPosition.under,
      onSelected: controller.setLanguage,
      itemBuilder: (context) => [
        for (final pref in AppLocalePreference.values)
          PopupMenuItem(
            value: pref,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _menuLabel(pref, context),
                    style: TextStyle(
                      fontSize: 13,
                      color:
                          pref == controller.language ? p.lycheeInk : p.ink,
                      fontWeight: pref == controller.language
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                ),
                if (pref == controller.language)
                  Icon(Icons.check_rounded, size: 16, color: p.lycheeInk),
              ],
            ),
          ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: SizedBox(
          height: 34,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _faceLabel(context),
                style: TextStyle(
                  color: p.inkMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 16,
                color: p.inkMuted,
              ),
            ],
          ),
        ),
      ),
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
        // Hover swaps the glyph to night-on-lychee: the hovered state must
        // stay visible against its own fill, and white fails on the dark-mode
        // lychee (2.8:1) where night clears 4.5:1 in both themes.
        style: ButtonStyle(
          shape: const WidgetStatePropertyAll(RoundedRectangleBorder()),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (close) {
              return states.contains(WidgetState.hovered) ||
                      states.contains(WidgetState.pressed)
                  ? p.onLychee
                  : p.lychee;
            }
            return p.inkMuted;
          }),
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (close) {
              return states.contains(WidgetState.hovered) ||
                      states.contains(WidgetState.pressed)
                  ? p.lychee
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
