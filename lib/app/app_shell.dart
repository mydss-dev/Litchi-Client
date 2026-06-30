import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import '../config/app_config.dart';
import '../features/account/account_page.dart';
import '../features/account/wallet_page.dart';
import '../features/auth/auth_flow.dart';
import '../features/dashboard/dashboard_page.dart';
import '../features/invite/invite_page.dart';
import '../features/nodes/nodes_page.dart';
import '../features/orders/orders_page.dart';
import '../features/settings/settings_page.dart';
import '../features/shop/shop_page.dart';
import '../features/tickets/tickets_page.dart';
import '../features/traffic/traffic_page.dart';
import 'nav_destinations.dart';
import '../shared/models/app_models.dart';
import '../shared/responsive/layout_scope.dart';
import '../shared/theme/app_colors.dart';
import '../shared/theme/app_radius.dart';
import '../shared/theme/app_shadows.dart';
import '../shared/theme/app_text_styles.dart';
import 'app_controller.dart';
import 'app_window_bar.dart';

bool get _isDesktop =>
    Platform.isWindows || Platform.isMacOS || Platform.isLinux;

/// Windows/Linux draw a custom frameless window (rounded clip, custom controls).
/// macOS uses its native window (traffic lights + native corners/shadow), so it
/// gets neither the custom controls nor the rounded clip.
bool get _usesCustomChrome => Platform.isWindows || Platform.isLinux;

/// All pages are now responsive — each handles its own compact / wide layout
/// internally, so the shell just picks the widget directly.
Widget _pageFor(AppPage page) {
  return switch (page) {
    AppPage.dashboard => const DashboardPage(),
    AppPage.nodes => const NodesPage(),
    AppPage.shop => const ShopPage(),
    AppPage.traffic => const TrafficPage(),
    AppPage.invite => const InvitePage(),
    AppPage.settings => const SettingsPage(),
    AppPage.account => const AccountPage(),
    AppPage.wallet => const WalletPage(),
    AppPage.orders => const OrdersPage(),
    AppPage.tickets => const TicketsPage(),
  };
}

/// Root window shell. The whole app is clipped to an 18px rounded rectangle on
/// a transparent window background, with a 1px border and outer shadow. Corners
/// go square while maximized. The body inside is responsive: a sidebar layout
/// on wide screens, a bottom-nav layout on narrow ones.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WindowListener, TrayListener {
  static const double _radius = 18;
  // Compact card-sized window for the logged-out (auth) screens; the full app
  // window once authenticated. Each auth screen gets a fixed height that hugs
  // its content, applied in didChangeDependencies the moment the screen changes
  // so the window and the new content land together (no measure-then-resize
  // stutter, no wasted whitespace).
  static const double _authWindowWidth = 400;
  static const Size _appWindowSize = Size(420, 760);
  bool _maximized = false;
  bool _trayActive = false;
  bool? _compactWindow;
  double? _authHeight;
  AuthScreen? _visibleAuthScreen;
  AuthScreen? _pendingAuthScreen;
  bool _authTransitioning = false;
  double _authOpacity = 1;

  static const Duration _authFadeOutDuration = Duration(milliseconds: 110);
  static const Duration _authFadeInDuration = Duration(milliseconds: 150);

  static double _authHeightFor(AuthScreen screen) => switch (screen) {
    AuthScreen.login => 560,
    AuthScreen.register => 720,
    AuthScreen.changePassword => 620,
    AuthScreen.forgotPassword => 700,
  };

  // Cached so onWindowClose / tray callbacks can act without a context lookup.
  AppController? _ctrl;

  @override
  void initState() {
    super.initState();
    if (_isDesktop) {
      windowManager.addListener(this);
      unawaited(windowManager.setPreventClose(true));
      _sync();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ctrl = AppScope.of(context);
    _ctrl = ctrl;
    _visibleAuthScreen ??= ctrl.authScreen;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!ctrl.isAuthenticated && _visibleAuthScreen != ctrl.authScreen) {
        _queueAuthTransition(ctrl.authScreen);
      } else {
        unawaited(_syncWindowSize(ctrl));
      }
    });

    final shouldHaveTray = _isDesktop && ctrl.isAuthenticated;
    if (shouldHaveTray && !_trayActive) {
      _trayActive = true;
      unawaited(_initTray());
    } else if (!shouldHaveTray && _trayActive) {
      _trayActive = false;
      unawaited(_destroyTray());
    } else if (_trayActive) {
      unawaited(_syncTrayState());
    }
  }

  @override
  void dispose() {
    if (_isDesktop) {
      windowManager.removeListener(this);
    }
    if (_trayActive) {
      trayManager.removeListener(this);
      unawaited(trayManager.destroy());
    }
    super.dispose();
  }

  Future<void> _sync() async {
    if (!_isDesktop) return;
    final m = await windowManager.isMaximized();
    if (mounted) setState(() => _maximized = m);
  }

  /// Sizes the window to hug the current auth screen while logged out, and
  /// restores the full app window once authenticated. No-op while maximized.
  Future<void> _syncWindowSize(AppController ctrl) async {
    if (!_isDesktop) return;
    if (await windowManager.isMaximized()) return;

    if (ctrl.isAuthenticated) {
      if (_compactWindow == false) return;
      _compactWindow = false;
      _authHeight = null;
      await _applyWindowSize(_appWindowSize, center: true);
      return;
    }

    final height = _authHeightFor(_visibleAuthScreen ?? ctrl.authScreen);
    if (_compactWindow == true && _authHeight == height) return;
    // Centre only when first entering the auth flow; switching between auth
    // screens just changes the height in place so a window the user has moved
    // stays where they put it.
    final firstCompact = _compactWindow != true;
    _compactWindow = true;
    _authHeight = height;
    await _applyWindowSize(
      Size(_authWindowWidth, height),
      center: firstCompact,
    );
  }

  void _queueAuthTransition(AuthScreen target) {
    _pendingAuthScreen = target;
    if (_authTransitioning) return;
    unawaited(_runAuthTransitions());
  }

  Future<void> _runAuthTransitions() async {
    _authTransitioning = true;
    try {
      while (mounted && _pendingAuthScreen != null) {
        var target = _pendingAuthScreen!;
        _pendingAuthScreen = null;
        if (target == _visibleAuthScreen) continue;

        setState(() => _authOpacity = 0);
        await Future<void>.delayed(_authFadeOutDuration);
        if (!mounted || _ctrl?.isAuthenticated == true) return;

        target = _pendingAuthScreen ?? _ctrl?.authScreen ?? target;
        _pendingAuthScreen = null;
        await _resizeForAuthScreen(target);
        if (!mounted || _ctrl?.isAuthenticated == true) return;

        final latestTarget = _pendingAuthScreen ?? _ctrl?.authScreen;
        if (latestTarget != null && latestTarget != target) {
          target = latestTarget;
          _pendingAuthScreen = null;
          await _resizeForAuthScreen(target);
          if (!mounted || _ctrl?.isAuthenticated == true) return;
        }

        setState(() => _visibleAuthScreen = target);
        await WidgetsBinding.instance.endOfFrame;
        if (!mounted) return;
        setState(() => _authOpacity = 1);
        await Future<void>.delayed(_authFadeInDuration);

        final latest = _ctrl?.authScreen;
        if (latest != null && latest != _visibleAuthScreen) {
          _pendingAuthScreen = latest;
        }
      }
    } finally {
      _authTransitioning = false;
      if (mounted && _authOpacity != 1) {
        setState(() => _authOpacity = 1);
      }
      if (mounted &&
          _pendingAuthScreen != null &&
          _ctrl?.isAuthenticated != true) {
        _queueAuthTransition(_pendingAuthScreen!);
      }
    }
  }

  Future<void> _resizeForAuthScreen(AuthScreen screen) async {
    if (!_isDesktop || await windowManager.isMaximized()) return;
    final height = _authHeightFor(screen);
    if (_compactWindow == true && _authHeight == height) return;
    _compactWindow = true;
    _authHeight = height;
    await _applyWindowSize(Size(_authWindowWidth, height), center: false);
  }

  /// Applies a programmatic window size. macOS ignores a plain setSize while the
  /// window is non-resizable and won't shrink below the currently laid-out
  /// content, so we re-enable resizing and pin min == max == target to force it,
  /// then relax the constraints again.
  Future<void> _applyWindowSize(Size size, {required bool center}) async {
    await windowManager.setResizable(true);
    if (Platform.isMacOS) {
      await windowManager.setMinimumSize(size);
      await windowManager.setMaximumSize(size);
      await windowManager.setSize(size);
      if (center) await windowManager.center();
      await windowManager.setMinimumSize(const Size(380, 480));
      await windowManager.setMaximumSize(const Size(10000, 10000));
    } else {
      await windowManager.setSize(size);
      if (center) await windowManager.center();
    }
    await windowManager.setResizable(false);
  }

  // ── Tray ─────────────────────────────────────────────────────────────────

  Future<void> _initTray() async {
    if (!_isDesktop) return;
    await _updateTrayIcon();
    await _syncTrayState();
    trayManager.addListener(this);
  }

  Future<void> _syncTrayState() async {
    await _updateTrayIcon();
    await _updateTrayTooltip();
    await _updateTrayMenu();
  }

  Future<void> _updateTrayIcon() async {
    if (!_isDesktop) return;
    final connected = _ctrl?.coreRunning ?? false;
    await trayManager.setIcon(
      Platform.isWindows
          ? connected
                ? 'assets/images/tray_icon.ico'
                : 'assets/images/tray_icon_gray.ico'
          : connected
          ? 'assets/images/tray_icon.png'
          : 'assets/images/tray_icon_gray.png',
    );
  }

  Future<void> _updateTrayTooltip() async {
    if (!_isDesktop) return;
    final ctrl = _ctrl;
    if (ctrl == null) return;
    final status = ctrl.coreRunning ? '已连接' : '未连接';
    await trayManager.setToolTip('${AppConfig.appName}  $status');
  }

  Future<void> _updateTrayMenu() async {
    if (!_isDesktop) return;
    final ctrl = _ctrl;
    if (ctrl == null) return;

    final nodeName = ctrl.currentNode.name.isEmpty
        ? '暂无节点'
        : ctrl.currentNode.name;
    final canToggle = ctrl.nodes.isNotEmpty && !ctrl.coreConnecting;
    final isTun = ctrl.networkMode == NetworkMode.tun;

    final statusLabel = switch ((ctrl.coreRunning, ctrl.coreConnecting)) {
      (_, true) => '连接中...',
      (true, _) => isTun ? '已连接 · 虚拟网卡' : '已连接 · 系统代理',
      _ => '未连接',
    };

    await trayManager.setContextMenu(
      Menu(
        items: [
          MenuItem(key: 'show', label: '打开 ${AppConfig.appName}'),
          MenuItem.separator(),
          MenuItem(key: '_status', label: statusLabel, disabled: true),
          MenuItem(key: '_node', label: '节点：$nodeName', disabled: true),
          MenuItem.separator(),
          MenuItem(
            key: 'toggle_connection',
            label: ctrl.coreRunning ? '断开连接' : '立即连接',
            disabled: !canToggle,
          ),
          if (!isTun) MenuItem(key: 'fix_proxy', label: '修复系统代理'),
          MenuItem.separator(),
          MenuItem(key: 'quit', label: '退出'),
        ],
      ),
    );
  }

  Future<void> _destroyTray() async {
    if (!_isDesktop) return;
    trayManager.removeListener(this);
    await trayManager.destroy();
  }

  Future<void> _toggleWindow() async {
    if (!_isDesktop) return;
    if (await windowManager.isVisible()) {
      await windowManager.hide();
    } else {
      await windowManager.show();
      await windowManager.focus();
    }
  }

  Future<void> _quit() async {
    if (_trayActive) {
      trayManager.removeListener(this);
      await trayManager.destroy();
      _trayActive = false;
    }
    // Clean up core + system proxy, but never let a slow cleanup hang the
    // exit — cap it and then terminate the process hard.
    try {
      await _ctrl?.shutdown().timeout(const Duration(seconds: 5));
    } catch (_) {
      // intentional: best-effort cleanup, failure is safe to ignore
    }
    exit(0);
  }

  Future<void> _toggleConnectionFromTray() async {
    final ctrl = _ctrl;
    if (ctrl == null || ctrl.coreConnecting) return;
    await ctrl.toggleConnection();
    await _syncTrayState();
  }

  Future<void> _fixProxyFromTray() async {
    await _ctrl?.fixProxy();
    await _syncTrayState();
  }

  // ── TrayListener ──────────────────────────────────────────────────────────

  @override
  void onTrayIconMouseDown() => unawaited(_toggleWindow());

  @override
  void onTrayIconRightMouseDown() {
    if (_isDesktop) unawaited(trayManager.popUpContextMenu());
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'show':
        if (_isDesktop) {
          unawaited(windowManager.show());
          unawaited(windowManager.focus());
        }
      case 'toggle_connection':
        unawaited(_toggleConnectionFromTray());
      case 'fix_proxy':
        unawaited(_fixProxyFromTray());
      case 'quit':
        unawaited(_quit());
    }
  }

  // ── WindowListener ────────────────────────────────────────────────────────

  @override
  void onWindowMaximize() => setState(() => _maximized = true);

  @override
  void onWindowUnmaximize() => setState(() => _maximized = false);

  /// Close button / Alt+F4 behavior:
  /// - Logged in  → hide to tray (connection stays alive)
  /// - Logged out → full exit
  @override
  Future<void> onWindowClose() async {
    if (!_isDesktop) return;
    if (_ctrl?.isAuthenticated == true) {
      await windowManager.hide();
    } else {
      await _quit();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final controller = AppScope.of(context);
    // Only the custom (Windows/Linux) chrome draws the rounded clip, border and
    // window shadow — macOS gets those from its native window.
    final radius = _usesCustomChrome && !_maximized ? _radius : 0.0;
    // On the custom chrome the compact logged-out window IS the login card:
    // give it the card surface + border so there's a single frame.
    final asCard =
        _usesCustomChrome && !controller.isAuthenticated && !_maximized;

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          color: asCard ? c.cardBg : c.appBg,
          borderRadius: BorderRadius.circular(radius),
          border: asCard ? Border.all(color: c.softBorder) : null,
          boxShadow: _usesCustomChrome && !_maximized
              ? AppShadows.window
              : null,
        ),
        child: controller.isAuthenticated
            ? const _MainShell()
            : _AuthShell(
                screen: _visibleAuthScreen ?? controller.authScreen,
                opacity: _authOpacity,
              ),
      ),
    );
  }
}

/// Single fixed-size layout — bottom nav only.  No sidebar, no responsive
/// switching.  The app always renders the compact body regardless of width.
class _MainShell extends StatelessWidget {
  const _MainShell();

  @override
  Widget build(BuildContext context) {
    return const LayoutScope(
      isCompact: true,
      contentWidth: 420,
      child: _CompactBody(),
    );
  }
}

/// Compact (bottom-nav) layout.
/// On desktop it keeps the window chrome (custom controls / macOS drag strip)
/// so the window is still movable and closable.
class _CompactBody extends StatefulWidget {
  const _CompactBody();

  @override
  State<_CompactBody> createState() => _CompactBodyState();
}

class _CompactBodyState extends State<_CompactBody> {
  late final List<AppPage> _primaryPages = compactPrimaryDestinations
      .map((item) => item.page)
      .toList(growable: false);

  late final List<Widget> _primaryWidgets = _primaryPages
      .map(
        (page) => KeyedSubtree(
          key: PageStorageKey<AppPage>(page),
          child: _pageFor(page),
        ),
      )
      .toList(growable: false);

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final ctrl = AppScope.of(context);
    final bottom = MediaQuery.paddingOf(context).bottom;

    final primaryIndex = _primaryPages.indexOf(ctrl.page);
    final page = primaryIndex >= 0
        ? IndexedStack(index: primaryIndex, children: _primaryWidgets)
        : _pageFor(ctrl.page);

    final content = Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(
                context,
              ).copyWith(scrollbars: false),
              child: page,
            ),
          ),
        ),
        _MobileBottomNav(bottomPadding: bottom),
      ],
    );

    return Container(
      color: c.appBg,
      child: Column(
        children: [
          if (_usesCustomChrome) const WindowControlsBar(),
          if (Platform.isMacOS) const MacTitleBar(),
          if (!_isDesktop)
            const SafeArea(bottom: false, child: MobileTitleBar()),
          Expanded(child: SafeArea(top: false, bottom: false, child: content)),
        ],
      ),
    );
  }
}

/// Logged-out layout: full-width controls strip + centered auth panel.
class _AuthShell extends StatelessWidget {
  const _AuthShell({required this.screen, required this.opacity});

  final AuthScreen screen;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (_usesCustomChrome) const WindowControlsBar(),
        if (Platform.isMacOS) const MacTitleBar(),
        if (!_isDesktop) const SafeArea(bottom: false, child: MobileTitleBar()),
        Expanded(
          child: AnimatedOpacity(
            opacity: opacity,
            duration: opacity == 0
                ? _AppShellState._authFadeOutDuration
                : _AppShellState._authFadeInDuration,
            curve: Curves.easeOutCubic,
            child: AuthFlow(screen: screen),
          ),
        ),
      ],
    );
  }
}

// ── Compact bottom navigation (shared) ───────────────────────────────────────

class _MobileBottomNav extends StatelessWidget {
  const _MobileBottomNav({required this.bottomPadding});

  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final ctrl = AppScope.of(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(18, 4, 18, bottomPadding + 10),
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          gradient: c.cardGradient,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: c.softBorder),
          boxShadow: AppShadows.soft(c),
        ),
        child: Row(
          children: [
            for (final item in compactPrimaryDestinations)
              Expanded(
                child: _MobileNavButton(
                  item: item,
                  selected:
                      compactSelectedPrimary(
                        ctrl.page,
                        ctrl.mobileProfileChildPage,
                      ) ==
                      item.page,
                  onTap: () => ctrl.goToPage(item.page),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MobileNavButton extends StatelessWidget {
  const _MobileNavButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final NavDestination item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final color = selected ? c.primary : c.textMuted;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Ink(
            height: 46,
            decoration: BoxDecoration(
              color: selected ? c.primarySoft : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(item.icon, size: 18, color: color),
                const SizedBox(height: 3),
                Text(
                  item.labelFor(context),
                  style: AppTextStyles.caption.copyWith(
                    color: color,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
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
