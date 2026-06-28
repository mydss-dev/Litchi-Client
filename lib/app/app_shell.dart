import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import '../config/app_config.dart';
import '../config/mobile_layout.dart';
import '../features/account/account_page.dart';
import '../features/account/wallet_page.dart';
import '../features/auth/auth_flow.dart';
import '../features/dashboard/dashboard_page.dart';
import '../features/invite/invite_page.dart';
import '../features/mobile/mobile_home_page.dart';
import '../features/mobile/mobile_invite_page.dart';
import '../features/mobile/mobile_nodes_page.dart';
import '../features/mobile/mobile_profile_page.dart';
import '../features/mobile/mobile_settings_page.dart';
import '../features/mobile/mobile_shop_page.dart';
import '../features/mobile/mobile_tickets_page.dart';
import '../features/mobile/mobile_traffic_page.dart';
import '../features/mobile/mobile_wallet_page.dart';
import '../features/nodes/nodes_page.dart';
import '../features/orders/orders_page.dart';
import '../features/settings/settings_page.dart';
import '../features/shop/shop_page.dart';
import '../features/tickets/tickets_page.dart';
import '../features/traffic/traffic_page.dart';
import '../shared/models/app_models.dart';
import '../shared/responsive/breakpoints.dart';
import '../shared/theme/app_colors.dart';
import '../shared/theme/app_radius.dart';
import '../shared/theme/app_shadows.dart';
import '../shared/theme/app_text_styles.dart';
import '../shared/widgets/app_sidebar.dart';
import '../shared/widgets/notice_banner.dart';
import '../shared/widgets/update_banner.dart';
import 'app_controller.dart';
import 'app_window_bar.dart';

bool get _isDesktop =>
    Platform.isWindows || Platform.isMacOS || Platform.isLinux;

/// Windows/Linux draw a custom frameless window (rounded clip, custom controls).
/// macOS uses its native window (traffic lights + native corners/shadow), so it
/// gets neither the custom controls nor the rounded clip.
bool get _usesCustomChrome => Platform.isWindows || Platform.isLinux;

/// Picks the page widget for [page]. While the per-page migration is in
/// progress this still chooses the compact (mobile) or wide (desktop) widget by
/// width; once a page is unified into a single responsive widget, both branches
/// return the same widget and the mobile_* twin can be deleted.
Widget _pageFor(AppPage page, {required bool compact}) {
  switch (page) {
    case AppPage.dashboard:
      return compact ? const MobileHomePage() : const DashboardPage();
    case AppPage.nodes:
      return compact ? const MobileNodesPage() : const NodesPage();
    case AppPage.shop:
      return compact ? const MobileShopPage() : const ShopPage();
    case AppPage.traffic:
      return compact ? const MobileTrafficPage() : const TrafficPage();
    case AppPage.invite:
      return compact ? const MobileInvitePage() : const InvitePage();
    case AppPage.settings:
      return compact ? const MobileSettingsPage() : const SettingsPage();
    case AppPage.account:
      return compact ? const MobileProfilePage() : const AccountPage();
    case AppPage.wallet:
      return compact ? const MobileWalletPage() : const WalletPage();
    case AppPage.orders:
      return const OrdersPage();
    case AppPage.tickets:
      return compact ? const MobileTicketsPage() : const TicketsPage();
  }
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
  static const Size _appWindowSize = Size(900, 700);
  bool _maximized = false;
  bool _trayActive = false;
  bool? _compactWindow;
  double? _authHeight;

  static double _authHeightFor(AuthScreen screen) => switch (screen) {
    AuthScreen.login => 540,
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

    // Run after the frame so the new shell (narrow auth vs wide main) is laid
    // out before we resize — otherwise macOS won't shrink past the old layout.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_syncWindowSize(ctrl));
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

    final height = _authHeightFor(ctrl.authScreen);
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
      connected
          ? 'assets/images/tray_icon.ico'
          : 'assets/images/tray_icon_gray.ico',
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
            : const _AuthShell(),
      ),
    );
  }
}

/// Logged-in layout: responsive. A full-height sidebar + main column on wide
/// screens; a bottom-nav layout on narrow screens. The choice is by available
/// width, not platform, so a narrow desktop window also gets the compact UI.
class _MainShell extends StatelessWidget {
  const _MainShell();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (Breakpoints.isCompactWidth(constraints.maxWidth)) {
          return const _CompactBody();
        }
        return const _WideBody();
      },
    );
  }
}

/// Wide (sidebar) layout — used on desktop windows and wide tablets.
class _WideBody extends StatelessWidget {
  const _WideBody();

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final controller = AppScope.of(context);

    final body = Row(
      children: [
        const AppSidebar(),
        Expanded(
          child: Column(
            children: [
              if (_usesCustomChrome) const WindowControlsBar(),
              Expanded(
                child: Container(
                  color: c.appBg,
                  padding: EdgeInsets.fromLTRB(
                    _isDesktop ? 28 : 24,
                    _isDesktop ? 14 : 24,
                    _isDesktop ? 28 : 24,
                    24,
                  ),
                  child: _DesktopPageFrame(
                    page: controller.page,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (controller.updateInfo != null)
                          UpdateBanner(
                            info: controller.updateInfo!,
                            onDismiss: controller.dismissUpdate,
                          ),
                        if (controller.hasUnreadNotice)
                          NoticeBanner(
                            notice: controller.notices.first,
                            onDismiss: controller.markNoticeRead,
                          ),
                        Expanded(
                          child: _pageFor(controller.page, compact: false),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );

    if (!Platform.isMacOS) return body;
    // Reserve a full-width top strip on macOS so the native traffic lights and
    // window dragging have room above the sidebar and content.
    return Column(
      children: [
        const _MacTitleBarSpacer(),
        Expanded(child: body),
      ],
    );
  }
}

/// Compact (bottom-nav) layout — used on phones and narrow desktop windows.
/// On desktop it keeps the window chrome (custom controls / macOS drag strip)
/// so the window is still movable and closable.
class _CompactBody extends StatelessWidget {
  const _CompactBody();

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final ctrl = AppScope.of(context);
    final bottom = MediaQuery.paddingOf(context).bottom;

    final content = Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: _pageFor(ctrl.page, compact: true),
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
          if (Platform.isMacOS) const _MacTitleBarSpacer(),
          Expanded(
            // Phones need the top safe-area inset; on desktop the chrome above
            // already accounts for it, so no extra top inset there.
            child: SafeArea(
              top: !_isDesktop,
              bottom: false,
              child: content,
            ),
          ),
        ],
      ),
    );
  }
}

class _DesktopPageFrame extends StatelessWidget {
  const _DesktopPageFrame({required this.page, required this.child});

  final AppPage page;
  final Widget child;

  double get _maxWidth {
    return switch (page) {
      AppPage.dashboard => 1080,
      AppPage.nodes => 1080,
      AppPage.traffic => 1080,
      AppPage.shop => 1080,
      AppPage.invite => 980,
      AppPage.settings => 980,
      AppPage.account => 960,
      AppPage.wallet => 960,
      AppPage.orders => 980,
      AppPage.tickets => 980,
    };
  }

  @override
  Widget build(BuildContext context) {
    if (!_isDesktop) return child;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: _maxWidth),
        child: child,
      ),
    );
  }
}

/// Logged-out layout: full-width controls strip + centered auth panel.
class _AuthShell extends StatelessWidget {
  const _AuthShell();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(child: AuthFlow()),
        if (_usesCustomChrome)
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: WindowControlsBar(),
          ),
        // macOS: a small draggable strip up top; the native traffic lights sit
        // in its left corner.
        if (Platform.isMacOS)
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _MacTitleBarSpacer(),
          ),
      ],
    );
  }
}

/// A slim, transparent, draggable strip used on macOS in place of the custom
/// window controls — it reserves room for the native traffic lights and lets
/// the user drag the window from the top.
class _MacTitleBarSpacer extends StatelessWidget {
  const _MacTitleBarSpacer();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 30,
      width: double.infinity,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onPanStart: (_) => windowManager.startDragging(),
        child: const SizedBox.expand(),
      ),
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
    final items = _mobileNavItems();

    return Padding(
      padding: EdgeInsets.fromLTRB(18, 2, 18, bottomPadding + 8),
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: c.cardBg,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: c.softBorder),
          boxShadow: AppShadows.soft(c),
        ),
        child: Row(
          children: [
            for (final item in items)
              Expanded(
                child: _MobileNavButton(
                  item: item,
                  selected: _isSelected(
                    ctrl.page,
                    item.page,
                    ctrl.mobileProfileChildPage,
                  ),
                  onTap: () => ctrl.goToPage(item.page),
                ),
              ),
          ],
        ),
      ),
    );
  }

  bool _isSelected(AppPage current, AppPage tab, bool profileChild) {
    if (profileChild) {
      return tab == AppPage.account;
    }
    if (tab == AppPage.dashboard) {
      return current == AppPage.dashboard;
    }
    if (tab == AppPage.shop) {
      return current == AppPage.shop;
    }
    if (tab == AppPage.account) {
      return current == AppPage.account ||
          current == AppPage.orders ||
          current == AppPage.settings ||
          current == AppPage.tickets ||
          current == AppPage.wallet;
    }
    return current == tab;
  }
}

List<_MobileNavItem> _mobileNavItems() {
  return [
    const _MobileNavItem(AppPage.dashboard, LucideIcons.home, '首页'),
    for (final tab in MobileLayout.tabs.take(3)) _mobileNavItemFor(tab),
    const _MobileNavItem(AppPage.account, LucideIcons.user, '我的'),
  ];
}

_MobileNavItem _mobileNavItemFor(MobileTabConfig tab) {
  final page = switch (tab.type) {
    'shop' => AppPage.shop,
    'invite' => AppPage.invite,
    'tickets' => AppPage.tickets,
    'wallet' => AppPage.wallet,
    'orders' => AppPage.orders,
    'traffic' => AppPage.traffic,
    _ => AppPage.shop,
  };
  return _MobileNavItem(
    page,
    _mobileNavIcon(tab.icon, tab.type),
    tab.label.isEmpty ? _mobileNavLabel(tab.type) : tab.label,
  );
}

String _mobileNavLabel(String type) {
  return switch (type) {
    'shop' => '套餐',
    'invite' => '邀请',
    'tickets' => '工单',
    'wallet' => '钱包',
    'orders' => '订单',
    'traffic' => '用量',
    _ => '套餐',
  };
}

IconData _mobileNavIcon(String icon, String type) {
  final name = icon.isEmpty ? type : icon;
  return switch (name) {
    'shoppingBag' || 'shop' => LucideIcons.shoppingBag,
    'gift' || 'invite' => LucideIcons.gift,
    'messageSquare' || 'tickets' => LucideIcons.messageSquare,
    'wallet' => LucideIcons.wallet,
    'clipboardList' || 'orders' => LucideIcons.clipboardList,
    'gauge' || 'traffic' => LucideIcons.gauge,
    _ => LucideIcons.circle,
  };
}

class _MobileNavButton extends StatelessWidget {
  const _MobileNavButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _MobileNavItem item;
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
            height: 44,
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
                  item.label,
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

class _MobileNavItem {
  const _MobileNavItem(this.page, this.icon, this.label);

  final AppPage page;
  final IconData icon;
  final String label;
}
