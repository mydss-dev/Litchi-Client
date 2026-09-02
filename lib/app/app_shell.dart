import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
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
import '../shared/services/brand_asset_cache.dart';
import '../shared/services/secure_logger.dart';
import '../shared/theme/app_colors.dart';
import '../shared/theme/app_radius.dart';
import '../shared/theme/app_shadows.dart';
import '../shared/theme/app_text_styles.dart';
import '../shared/widgets/app_toast.dart';
import 'app_controller.dart';
import 'core_platform_support.dart';
import 'core_controller.dart';
import 'app_window_bar.dart';

bool get _isDesktop =>
    Platform.isWindows || Platform.isMacOS || Platform.isLinux;

/// Windows/Linux draw custom controls. The Windows runner owns the final window
/// shape; Linux clips the Navigator against its transparent host window.
/// macOS uses its native traffic lights, corners and shadow.
bool get _usesCustomChrome => Platform.isWindows || Platform.isLinux;

/// Each page renders its own compact layout; the shell just picks the widget
/// directly.
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

/// Renders the body for [destinations] as an [IndexedStack] (preserving each
/// tab's scroll state), falling back to a single page for hub/hidden pages.
Widget _indexedBody(AppController ctrl, List<NavDestination> destinations) {
  final pages = destinations.map((d) => d.page).toList(growable: false);
  final index = pages.indexOf(ctrl.page);
  if (index >= 0) {
    return IndexedStack(
      index: index,
      children: [
        for (final p in pages)
          KeyedSubtree(key: PageStorageKey<AppPage>(p), child: _pageFor(p)),
      ],
    );
  }
  return _pageFor(ctrl.page);
}

/// Root window shell. The whole app is clipped to an 18px rounded rectangle on
/// a transparent window background, with a 1px border and outer shadow. Corners
/// go square while maximized. The body inside is a single bottom-nav layout.
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
  // Auth screens stay compact and non-resizable; once authenticated the app
  // switches once to a stable, user-resizable desktop window. Page navigation
  // never changes the outer window size.
  static const double _authWindowWidth = 400;
  static const Size _authMinimumSize = Size(380, 480);
  static const Size _desktopWindowSize = Size(900, 680);
  static const Size _desktopMinimumSize = Size(800, 600);
  // A practical unbounded ceiling that also clears the fixed macOS auth max.
  static const Size _desktopMaximumSize = Size(10000, 10000);
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

  /// Keeps logged-out auth screens compact, then initializes the authenticated
  /// desktop window exactly once. Subsequent controller rebuilds and page
  /// navigation preserve the size chosen by the user.
  Future<void> _syncWindowSize(AppController ctrl) async {
    if (!_isDesktop) return;
    final maximized = await windowManager.isMaximized();

    if (ctrl.isAuthenticated) {
      if (_compactWindow == false) return;
      if (maximized) {
        // Logging in while the compact auth window is maximized used to leave
        // the authenticated app with auth-size constraints and resize disabled.
        // Update the constraints immediately, then finish the default desktop
        // restore size from onWindowUnmaximize().
        await windowManager.setResizable(true);
        await windowManager.setMinimumSize(_desktopMinimumSize);
        await windowManager.setMaximumSize(_desktopMaximumSize);
        return;
      }
      _compactWindow = false;
      _authHeight = null;
      await _applyDesktopWindow();
      return;
    }

    if (maximized) return;
    final height = _authHeightFor(_visibleAuthScreen ?? ctrl.authScreen);
    if (_compactWindow == true && _authHeight == height) return;
    // Centre only when first entering the auth flow; switching between auth
    // screens just changes the height in place so a window the user has moved
    // stays where they put it.
    final firstCompact = _compactWindow != true;
    _compactWindow = true;
    _authHeight = height;
    await _applyAuthWindowSize(
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
    await _applyAuthWindowSize(Size(_authWindowWidth, height), center: false);
  }

  /// Applies the fixed compact auth size. Windows/Linux only need their desktop
  /// minimum reset before shrinking; macOS additionally pins min == max to force
  /// the resize while the auth window is non-resizable.
  Future<void> _applyAuthWindowSize(Size size, {required bool center}) async {
    await windowManager.setResizable(true);
    if (Platform.isMacOS) {
      await windowManager.setMinimumSize(size);
      await windowManager.setMaximumSize(size);
      await windowManager.setSize(size);
    } else {
      await windowManager.setMinimumSize(_authMinimumSize);
      await windowManager.setMaximumSize(_desktopMaximumSize);
      await windowManager.setSize(size);
    }
    if (center) await windowManager.center();
    await windowManager.setResizable(false);
  }

  /// Initializes the authenticated desktop surface once. After this transition
  /// the outer window belongs to the user: it can be resized/maximized and page
  /// navigation no longer changes its dimensions.
  Future<void> _applyDesktopWindow() async {
    await windowManager.setResizable(true);
    await windowManager.setMinimumSize(_desktopMinimumSize);
    await windowManager.setMaximumSize(_desktopMaximumSize);
    await windowManager.setSize(_desktopWindowSize);
    await windowManager.center();
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
    _trayIconsPresent ??= await _trayIconsAvailable();
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
  void onWindowMaximize() {
    if (!mounted) return;
    setState(() => _maximized = true);
  }

  @override
  void onWindowUnmaximize() {
    if (!mounted) return;
    setState(() => _maximized = false);
    final ctrl = _ctrl;
    if (ctrl != null) unawaited(_syncWindowSize(ctrl));
  }

  /// Close button / Alt+F4 behavior:
  /// - Connected with a usable tray icon → hide to tray (connection stays alive)
  /// - Otherwise → full exit (no hidden window left behind an invisible icon)
  @override
  Future<void> onWindowClose() async {
    if (!_isDesktop) return;
    final connected = _ctrl?.connectionStatus == ConnectionStatus.connected;
    if (_ctrl?.isAuthenticated == true && connected && _trayReady) {
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

/// Desktop uses a persistent left sidebar; compact platforms keep bottom nav.
class _MainShell extends StatelessWidget {
  const _MainShell();

  @override
  Widget build(BuildContext context) {
    if (CorePlatformSupport.isDesktop) {
      return const _DesktopBody();
    }
    return const _CompactBody();
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
    final page = _indexedBody(ctrl, compactPrimaryDestinations);

    final content = Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(context)
                  .copyWith(scrollbars: false),
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

/// Stable desktop layout with a persistent 196px navigation sidebar.
/// Most pages use the shell's vertical scroll; long virtualized surfaces (such
/// as the desktop node table) own a bounded inner viewport.
class _DesktopBody extends StatelessWidget {
  const _DesktopBody();

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final ctrl = AppScope.of(context);
    final page = _pageFor(ctrl.page);

    return Container(
      color: c.appBg,
      child: Column(
        children: [
          if (_usesCustomChrome) const WindowControlsBar(),
          if (Platform.isMacOS) const MacTitleBar(),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _DesktopSidebar(ctrl: ctrl),
                Expanded(
                  child: SafeArea(
                    top: false,
                    bottom: false,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
                      child: KeyedSubtree(
                        key: PageStorageKey<AppPage>(ctrl.page),
                        child: page,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DesktopSidebar extends StatelessWidget {
  const _DesktopSidebar({required this.ctrl});

  static const double _width = 196;
  static const List<AppPage> _mainPages = [
    AppPage.dashboard,
    AppPage.nodes,
    AppPage.shop,
    AppPage.traffic,
    AppPage.invite,
  ];
  static const List<AppPage> _accountPages = [
    AppPage.account,
    AppPage.wallet,
    AppPage.orders,
    AppPage.tickets,
  ];

  final AppController ctrl;

  NavDestination _destination(AppPage page) =>
      kNavDestinations.firstWhere((item) => item.page == page);

  List<NavDestination> _orderedEnabled(List<AppPage> pages) => [
    for (final page in pages)
      for (final destination in kNavDestinations)
        if (destination.page == page && destination.isEnabled) destination,
  ];

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final mainItems = _orderedEnabled(_mainPages);
    final accountItems = _orderedEnabled(_accountPages);
    final accountActive = _accountPages.contains(ctrl.page);
    final settings = _destination(AppPage.settings);

    return Container(
      width: _width,
      decoration: BoxDecoration(
        color: c.cardBg,
        border: Border(right: BorderSide(color: c.softBorder)),
      ),
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
              children: [
                for (final item in mainItems)
                  _SidebarItem(
                    item: item,
                    label: _desktopNavLabel(context, item.page),
                    selected: ctrl.page == item.page,
                    onTap: () => ctrl.goToPage(item.page),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 10, 8, 6),
                  child: Divider(height: 1, color: c.softBorder),
                ),
                _SidebarGroupHeader(
                  icon: LucideIcons.userRound,
                  label: _desktopAccountCenterLabel(context),
                  active: accountActive,
                ),
                const SizedBox(height: 2),
                for (final item in accountItems)
                  _SidebarItem(
                    item: item,
                    label: _desktopNavLabel(context, item.page),
                    selected: ctrl.page == item.page,
                    nested: true,
                    onTap: () => ctrl.goToPage(item.page),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
                  child: Divider(height: 1, color: c.softBorder),
                ),
                if (settings.isEnabled)
                  _SidebarItem(
                    item: settings,
                    label: _desktopNavLabel(context, settings.page),
                    selected: ctrl.page == settings.page,
                    onTap: () => ctrl.goToPage(settings.page),
                  ),
              ],
            ),
          ),
          Divider(height: 1, color: c.softBorder),
          _SidebarAccountCard(ctrl: ctrl),
        ],
      ),
    );
  }
}

String _desktopNavLabel(BuildContext context, AppPage page) {
  final locale = Localizations.localeOf(context);
  final isChinese = locale.languageCode == 'zh';
  final isTraditional =
      isChinese &&
      (locale.scriptCode == 'Hant' ||
          locale.countryCode == 'TW' ||
          locale.countryCode == 'HK' ||
          locale.countryCode == 'MO');

  if (isChinese) {
    if (isTraditional) {
      return switch (page) {
        AppPage.dashboard => '首頁概覽',
        AppPage.nodes => '節點列表',
        AppPage.shop => '套餐購買',
        AppPage.traffic => '用量統計',
        AppPage.invite => '邀請好友',
        AppPage.account => '帳戶概覽',
        AppPage.wallet => '我的錢包',
        AppPage.orders => '訂單記錄',
        AppPage.tickets => '工單支援',
        AppPage.settings => '系統設定',
      };
    }
    return switch (page) {
      AppPage.dashboard => '首页概览',
      AppPage.nodes => '节点列表',
      AppPage.shop => '套餐购买',
      AppPage.traffic => '用量统计',
      AppPage.invite => '邀请好友',
      AppPage.account => '账户概览',
      AppPage.wallet => '我的钱包',
      AppPage.orders => '订单记录',
      AppPage.tickets => '工单支持',
      AppPage.settings => '系统设置',
    };
  }

  return switch (page) {
    AppPage.dashboard => 'Home Overview',
    AppPage.nodes => 'Node List',
    AppPage.shop => 'Plans',
    AppPage.traffic => 'Usage',
    AppPage.invite => 'Invite Friends',
    AppPage.account => 'Account Overview',
    AppPage.wallet => 'Wallet',
    AppPage.orders => 'Orders',
    AppPage.tickets => 'Support',
    AppPage.settings => 'Settings',
  };
}

String _desktopAccountCenterLabel(BuildContext context) {
  final locale = Localizations.localeOf(context);
  if (locale.languageCode != 'zh') return 'Account Center';
  final traditional =
      locale.scriptCode == 'Hant' ||
      locale.countryCode == 'TW' ||
      locale.countryCode == 'HK' ||
      locale.countryCode == 'MO';
  return traditional ? '帳戶中心' : '账户中心';
}

class _SidebarGroupHeader extends StatelessWidget {
  const _SidebarGroupHeader({
    required this.icon,
    required this.label,
    required this.active,
  });

  final IconData icon;
  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final color = active ? c.primary : c.textMuted;
    return SizedBox(
      height: 36,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 13),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodyStrong.copyWith(
                  color: color,
                  fontSize: 13.5,
                ),
              ),
            ),
            Icon(
              LucideIcons.chevronDown,
              size: 14,
              color: active ? c.primary : c.iconMuted,
            ),
          ],
        ),
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.item,
    required this.label,
    required this.selected,
    required this.onTap,
    this.nested = false,
  });

  final NavDestination item;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool nested;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final foreground = selected ? c.primary : c.textMuted;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          mouseCursor: SystemMouseCursors.click,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Ink(
            height: nested ? 36 : 42,
            decoration: BoxDecoration(
              color: selected ? c.primarySoft : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 4,
                  child: Center(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 140),
                      width: 3,
                      height: selected ? (nested ? 16 : 20) : 0,
                      decoration: BoxDecoration(
                        color: c.primary,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: nested ? 25 : 9),
                Icon(item.icon, size: nested ? 15 : 18, color: foreground),
                SizedBox(width: nested ? 8 : 10),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        (selected
                                ? AppTextStyles.bodyStrong
                                : AppTextStyles.body)
                            .copyWith(
                              color: foreground,
                              fontSize: nested ? 12.5 : 13.5,
                            ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _SidebarAccountAction {
  expiryReminder,
  trafficReminder,
  autoRenewal,
  changePassword,
  logout,
}

/// Identity strip + account quick actions. It deliberately does not navigate to
/// Account Overview: the sidebar already owns that navigation entry.
class _SidebarAccountCard extends StatelessWidget {
  const _SidebarAccountCard({required this.ctrl});

  final AppController ctrl;

  Future<void> _handleAction(
    BuildContext context,
    _SidebarAccountAction action,
  ) async {
    switch (action) {
      case _SidebarAccountAction.expiryReminder:
        await _updatePreference(context, remindExpire: !ctrl.user.remindExpire);
      case _SidebarAccountAction.trafficReminder:
        await _updatePreference(
          context,
          remindTraffic: !ctrl.user.remindTraffic,
        );
      case _SidebarAccountAction.autoRenewal:
        await _updatePreference(context, autoRenewal: !ctrl.user.autoRenewal);
      case _SidebarAccountAction.changePassword:
        await showAccountChangePasswordModal(context);
      case _SidebarAccountAction.logout:
        final confirmed = await showAccountLogoutConfirmation(context);
        if (confirmed && context.mounted) await ctrl.logout();
    }
  }

  Future<void> _updatePreference(
    BuildContext context, {
    bool? remindExpire,
    bool? remindTraffic,
    bool? autoRenewal,
  }) async {
    final error = await ctrl.updateUserSettings(
      remindExpire: remindExpire ?? ctrl.user.remindExpire,
      remindTraffic: remindTraffic ?? ctrl.user.remindTraffic,
      autoRenewal: autoRenewal ?? ctrl.user.autoRenewal,
    );
    if (error != null && context.mounted) {
      AppToast.show(context, error, type: AppToastType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final user = ctrl.user;
    final file = BrandAssetCache.avatarFile;
    final letter = user.avatarLetter.isEmpty ? 'L' : user.avatarLetter;

    final Widget avatar;
    if (BrandAssetCache.avatarUrl.isEmpty || file == null) {
      avatar = CircleAvatar(
        radius: 16,
        backgroundColor: c.primarySoft,
        child: Text(
          letter,
          style: AppTextStyles.bodyStrong.copyWith(
            color: c.primary,
            fontSize: 12,
          ),
        ),
      );
    } else {
      avatar = ClipOval(
        child: Image.file(
          file,
          width: 32,
          height: 32,
          fit: BoxFit.cover,
          gaplessPlayback: true,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(10),
      child: PopupMenuButton<_SidebarAccountAction>(
        tooltip: context.l10n.accountManagement,
        position: PopupMenuPosition.over,
        constraints: const BoxConstraints.tightFor(width: 220),
        onSelected: (action) => unawaited(_handleAction(context, action)),
        itemBuilder: (context) => [
          if (ctrl.hasPlan) ...[
            _preferenceMenuItem(
              context,
              value: _SidebarAccountAction.expiryReminder,
              icon: LucideIcons.calendarClock,
              label: context.l10n.expiryReminder,
              enabled: user.remindExpire,
            ),
            _preferenceMenuItem(
              context,
              value: _SidebarAccountAction.trafficReminder,
              icon: LucideIcons.gauge,
              label: context.l10n.trafficReminder,
              enabled: user.remindTraffic,
            ),
            _preferenceMenuItem(
              context,
              value: _SidebarAccountAction.autoRenewal,
              icon: LucideIcons.refreshCw,
              label: context.l10n.autoRenewal,
              enabled: user.autoRenewal,
            ),
            const PopupMenuDivider(height: 8),
          ],
          PopupMenuItem<_SidebarAccountAction>(
            value: _SidebarAccountAction.changePassword,
            height: 40,
            child: Row(
              children: [
                Icon(LucideIcons.lockKeyhole, size: 17, color: c.iconDefault),
                const SizedBox(width: 10),
                Text(context.l10n.changePasswordTitle),
              ],
            ),
          ),
          const PopupMenuDivider(height: 8),
          PopupMenuItem<_SidebarAccountAction>(
            value: _SidebarAccountAction.logout,
            height: 40,
            child: Row(
              children: [
                Icon(LucideIcons.logOut, size: 17, color: c.danger),
                const SizedBox(width: 10),
                Text(context.l10n.logout, style: TextStyle(color: c.danger)),
              ],
            ),
          ),
        ],
        child: Material(
          color: Colors.transparent,
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 9),
            decoration: BoxDecoration(
              color: c.surfaceMuted,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Row(
              children: [
                avatar,
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.name.isEmpty ? '--' : user.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodyStrong.copyWith(
                          color: c.textPrimary,
                          fontSize: 12.5,
                        ),
                      ),
                      if (user.plan.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          user.plan,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.caption.copyWith(
                            color: c.textMuted,
                            fontSize: 10.5,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  LucideIcons.ellipsisVertical,
                  size: 15,
                  color: c.iconMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  PopupMenuItem<_SidebarAccountAction> _preferenceMenuItem(
    BuildContext context, {
    required _SidebarAccountAction value,
    required IconData icon,
    required String label,
    required bool enabled,
  }) {
    final c = AppColors.of(context);
    return PopupMenuItem<_SidebarAccountAction>(
      value: value,
      height: 40,
      child: Row(
        children: [
          Icon(icon, size: 17, color: c.iconDefault),
          const SizedBox(width: 10),
          Expanded(child: Text(label)),
          Transform.scale(
            scale: 0.72,
            child: IgnorePointer(
              child: Switch(value: enabled, onChanged: (_) {}),
            ),
          ),
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
