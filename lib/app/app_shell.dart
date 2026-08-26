import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../l10n/l10n.dart';
import 'nav_destinations.dart';
import '../shared/models/app_models.dart';
import '../shared/responsive/layout_scope.dart';
import '../shared/services/secure_logger.dart';
import '../shared/theme/app_colors.dart';
import '../shared/theme/app_radius.dart';
import '../shared/theme/app_shadows.dart';
import '../shared/theme/app_text_styles.dart';
import 'app_controller.dart';
import 'core_controller.dart';
import 'app_window_bar.dart';

bool get _isDesktop =>
    Platform.isWindows || Platform.isMacOS || Platform.isLinux;

/// Windows/Linux draw custom controls. The Windows runner owns the final window
/// shape; Linux clips the Navigator against its transparent host window.
/// macOS uses its native traffic lights, corners and shadow.
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
  const AppShell({super.key, this.launchSilently = false});

  final bool launchSilently;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WindowListener, TrayListener {
  static const MethodChannel _windowsProcessChannel = MethodChannel(
    'litchi/windows_process',
  );
  // macOS Cmd+Q / Dock > Quit is intercepted in AppDelegate.swift and routed
  // here so `_quit()` can shut the core down and restore the system proxy
  // before the process exits (see macos/Runner/AppDelegate.swift).
  static const MethodChannel _macQuitChannel = MethodChannel('litchi/quit');
  // Compact card-sized window for the logged-out (auth) screens; the full app
  // window once authenticated. Each auth screen gets a fixed height that hugs
  // its content, applied in didChangeDependencies the moment the screen changes
  // so the window and the new content land together (no measure-then-resize
  // stutter, no wasted whitespace).
  static const double _authWindowWidth = 400;
  static const Size _appWindowSize = Size(420, 760);
  bool _maximized = false;
  bool _trayActive = false;
  bool _trayReady = false;
  bool? _trayIconsPresent;
  bool _trayListenerAttached = false;
  bool _quitting = false;
  Future<void> _trayOperationTail = Future<void>.value();
  Brightness? _nativeBrightness;
  bool? _compactWindow;
  double? _authHeight;
  AuthScreen? _visibleAuthScreen;
  AuthScreen? _pendingAuthScreen;
  bool _authTransitioning = false;
  bool _silentVisibilityResolved = false;
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
    if (Platform.isMacOS) {
      // Cmd+Q / Dock > Quit arrives here via AppDelegate.swift. Run the same
      // cleanup path as the tray Quit item so the proxy is restored before exit.
      _macQuitChannel.setMethodCallHandler((call) async {
        if (call.method == 'quit') await _quit();
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ctrl = AppScope.of(context);
    _ctrl = ctrl;
    _visibleAuthScreen ??= ctrl.authScreen;

    if (_isDesktop) {
      final brightness = Theme.of(context).brightness;
      if (_nativeBrightness != brightness) {
        _nativeBrightness = brightness;
        unawaited(windowManager.setBrightness(brightness));
      }
    }

    if (widget.launchSilently &&
        !_silentVisibilityResolved &&
        !ctrl.isInitializing) {
      _silentVisibilityResolved = true;
      if (!ctrl.isAuthenticated) {
        unawaited(windowManager.show());
        unawaited(windowManager.focus());
      }
    }

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
    if (Platform.isMacOS) {
      _macQuitChannel.setMethodCallHandler(null);
    }
    if (_trayActive) {
      _trayActive = false;
      unawaited(_destroyTray());
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

  Future<void> _enqueueTrayOperation(Future<void> Function() operation) {
    final result = _trayOperationTail.then<void>((_) => operation());
    // A failed plugin call must not poison the queue and prevent a later
    // destroy from removing the icon.
    _trayOperationTail = result.catchError((Object _, StackTrace _) {});
    return result;
  }

  Future<void> _initTray() => _enqueueTrayOperation(() async {
    if (!_isDesktop || !_trayActive || _quitting) return;
    await _updateTrayIcon();
    if (!_trayReady || !_trayActive || _quitting) {
      // No usable icon → degrade to "no tray" so onWindowClose quits instead of
      // hiding the window behind a tray icon that will never appear.
      _trayActive = false;
      await trayManager.destroy();
      return;
    }
    await _updateTrayTooltip();
    if (!_trayActive || _quitting) {
      await trayManager.destroy();
      return;
    }
    await _updateTrayMenu();
    if (!_trayActive || _quitting) {
      await trayManager.destroy();
      return;
    }
    if (!_trayListenerAttached) {
      trayManager.addListener(this);
      _trayListenerAttached = true;
    }
  });

  Future<void> _syncTrayState() => _enqueueTrayOperation(() async {
    if (!_isDesktop || !_trayActive || _quitting) return;
    await _updateTrayIcon();
    if (!_trayReady || !_trayActive || _quitting) return;
    await _updateTrayTooltip();
    if (!_trayActive || _quitting) return;
    await _updateTrayMenu();
  });

  Future<void> _updateTrayIcon() async {
    if (!_isDesktop) return;
    final connected = _ctrl?.connectionStatus == ConnectionStatus.connected;
    final path = Platform.isWindows
        ? connected
              ? 'assets/images/tray_icon.ico'
              : 'assets/images/tray_icon_gray.ico'
        : connected
        ? 'assets/images/tray_icon.png'
        : 'assets/images/tray_icon_gray.png';

    // The tray plugin resolves "assets/…" against the bundle, so a missing icon
    // surfaces as an icon that never appears rather than a hard error. Verify
    // the asset is actually bundled so a stripped build degrades to "no tray"
    // (window close quits) instead of hiding the app behind an invisible icon.
    if (_trayIconsPresent == null) {
      _trayIconsPresent = await _trayIconsAvailable();
    }
    if (_trayIconsPresent != true) {
      if (_trayReady) {
        _trayReady = false;
        SecureLogger.warn('Tray disabled: bundled tray icons unavailable');
      }
      return;
    }

    try {
      await trayManager.setIcon(path);
      _trayReady = true;
    } catch (error) {
      _trayReady = false;
      SecureLogger.warn('Tray icon failed to load: $path', error);
    }
  }

  Future<bool> _trayIconsAvailable() async {
    for (final asset in const [
      'assets/images/tray_icon.ico',
      'assets/images/tray_icon_gray.ico',
      'assets/images/tray_icon.png',
      'assets/images/tray_icon_gray.png',
    ]) {
      try {
        await rootBundle.load(asset);
      } catch (_) {
        SecureLogger.warn('Missing bundled tray icon: $asset');
        return false;
      }
    }
    return true;
  }

  Future<void> _updateTrayTooltip() async {
    if (!_isDesktop) return;
    final ctrl = _ctrl;
    if (ctrl == null) return;
    final status = ctrl.connectionStatus == ConnectionStatus.connected
        ? context.l10n.connected
        : context.l10n.notConnected;
    await trayManager.setToolTip('${AppConfig.appName}  $status');
  }

  Future<void> _updateTrayMenu() async {
    if (!_isDesktop) return;
    final ctrl = _ctrl;
    if (ctrl == null) return;

    final nodeName = ctrl.currentNode.name.isEmpty
        ? context.l10n.noNodes
        : ctrl.currentNode.name;
    final canToggle = ctrl.nodes.isNotEmpty && !ctrl.coreConnecting;
    final isTun = ctrl.networkMode == NetworkMode.tun;

    final connected = ctrl.connectionStatus == ConnectionStatus.connected;
    final statusLabel = switch ((connected, ctrl.coreConnecting)) {
      (_, true) => context.l10n.connecting,
      (true, _) =>
        isTun
            ? context.l10n.trayConnectedTun
            : context.l10n.trayConnectedSystemProxy,
      _ => context.l10n.notConnected,
    };

    await trayManager.setContextMenu(
      Menu(
        items: [
          MenuItem(key: 'show', label: context.l10n.openApp(AppConfig.appName)),
          MenuItem.separator(),
          MenuItem(key: '_status', label: statusLabel, disabled: true),
          MenuItem(
            key: '_node',
            label: context.l10n.trayNode(nodeName),
            disabled: true,
          ),
          MenuItem.separator(),
          MenuItem(
            key: 'toggle_connection',
            label: connected
                ? context.l10n.disconnectConnection
                : context.l10n.connectNow,
            disabled: !canToggle,
          ),
          if (!isTun)
            MenuItem(key: 'fix_proxy', label: context.l10n.repairSystemProxy),
          MenuItem.separator(),
          MenuItem(key: 'quit', label: context.l10n.quit),
        ],
      ),
    );
  }

  Future<void> _destroyTray() => _enqueueTrayOperation(() async {
    if (!_isDesktop) return;
    if (_trayListenerAttached) {
      trayManager.removeListener(this);
      _trayListenerAttached = false;
    }
    await trayManager.destroy();
  });

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
    if (_quitting) return;
    _quitting = true;
    _trayActive = false;

    // A user-requested quit must feel immediate. Remove visible UI first, then
    // perform the bounded network cleanup with no tray icon left behind.
    try {
      await windowManager.hide().timeout(const Duration(milliseconds: 300));
    } catch (_) {
      // Best effort; process exit remains the final fallback.
    }

    try {
      if (_trayListenerAttached) {
        trayManager.removeListener(this);
        _trayListenerAttached = false;
      }
      // This is queued behind every pending icon/menu update, so destroy is
      // guaranteed to be the final tray operation.
      await _destroyTray().timeout(const Duration(seconds: 2));
    } catch (_) {
      // WM_DESTROY also asks the tray plugin to remove its icon.
    }

    try {
      await _ctrl?.shutdown().timeout(const Duration(seconds: 4));
    } catch (_) {
      // Never let network cleanup prevent an explicit Quit operation.
    }

    try {
      await windowManager.setPreventClose(false);
      if (Platform.isWindows) {
        // Ask the runner to destroy the actual HWND. This guarantees WM_DESTROY
        // runs (and gives the tray plugin a final NIM_DELETE) instead of relying
        // on window_manager's Windows implementation, which only posts WM_QUIT.
        await _windowsProcessChannel
            .invokeMethod<bool>('quit')
            .timeout(const Duration(seconds: 1));
      } else {
        await windowManager.destroy().timeout(const Duration(seconds: 1));
      }
    } catch (_) {
      // The hard-exit fallback below is intentional and unconditional.
    }

    // If a plugin swallowed the native close message, never leave a headless
    // process (and its notification icon) behind. The tray delete and network
    // cleanup above have already completed or hit their bounded timeouts.
    await Future<void>.delayed(const Duration(milliseconds: 250));
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
  /// - Logged in with a usable tray icon → hide to tray (connection stays alive)
  /// - Otherwise → full exit (no hidden window left behind an invisible icon)
  @override
  Future<void> onWindowClose() async {
    if (!_isDesktop) return;
    if (_ctrl?.isAuthenticated == true && _trayReady) {
      await windowManager.hide();
    } else {
      await _quit();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final controller = AppScope.of(context);
    // On the custom chrome the compact logged-out window IS the login card:
    // give it the card surface + border so there's a single frame.
    final asCard =
        _usesCustomChrome && !controller.isAuthenticated && !_maximized;

    return Container(
      decoration: BoxDecoration(
        color: asCard ? c.cardBg : c.appBg,
        border: asCard ? Border.all(color: c.softBorder) : null,
      ),
      child: controller.isAuthenticated
          ? const _MainShell()
          : _AuthShell(
              screen: _visibleAuthScreen ?? controller.authScreen,
              opacity: _authOpacity,
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
  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final ctrl = AppScope.of(context);
    final bottom = MediaQuery.paddingOf(context).bottom;
    final primaryPages = compactPrimaryDestinations
        .map((item) => item.page)
        .toList(growable: false);
    final primaryWidgets = primaryPages
        .map(
          (page) => KeyedSubtree(
            key: PageStorageKey<AppPage>(page),
            child: _pageFor(page),
          ),
        )
        .toList(growable: false);

    final primaryIndex = primaryPages.indexOf(ctrl.page);
    final page = primaryIndex >= 0
        ? IndexedStack(index: primaryIndex, children: primaryWidgets)
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

    final body = Container(
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

    // Android system back: a single-route app pops the root route and exits the
    // activity from any page. Instead, non-home pages step back one level and
    // only the dashboard actually exits. (iOS has no system back button — the
    // edge swipe is disabled on the root route — so this is Android-only.)
    if (!kIsWeb && Platform.isAndroid) {
      final atHome =
          ctrl.page == AppPage.dashboard && !ctrl.mobileProfileChildPage;
      return PopScope<Object?>(
        canPop: atHome,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          if (ctrl.mobileProfileChildPage) {
            // Hub child (wallet/orders/traffic/tickets/settings) → account hub.
            ctrl.goToProfileChildPage(AppPage.account);
          } else if (ctrl.page != AppPage.dashboard) {
            // Any other page (nodes/shop/invite/account) → dashboard.
            ctrl.goToPage(AppPage.dashboard);
          }
        },
        child: body,
      );
    }
    return body;
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
