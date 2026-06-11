import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import '../shared/config/app_config.dart';
import '../features/account/account_page.dart';
import '../features/auth/auth_flow.dart';
import '../features/dashboard/dashboard_page.dart';
import '../features/invite/invite_page.dart';
import '../features/nodes/nodes_page.dart';
import '../features/orders/orders_page.dart';
import '../features/settings/settings_page.dart';
import '../features/shop/shop_page.dart';
import '../features/tickets/tickets_page.dart';
import '../features/traffic/traffic_page.dart';
import '../shared/theme/app_colors.dart';
import '../shared/theme/app_shadows.dart';
import '../shared/theme/app_text_styles.dart';
import '../shared/widgets/app_sidebar.dart';
import '../shared/widgets/brand_logo.dart';
import '../shared/widgets/notice_banner.dart';
import '../shared/widgets/update_banner.dart';
import 'app_controller.dart';
import 'app_window_bar.dart';

/// Root window shell. The whole app is clipped to an 18px rounded rectangle on
/// a transparent window background, with a 1px border and outer shadow. Corners
/// go square while maximized.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell>
    with WindowListener, TrayListener {
  static const double _radius = 18;
  bool _maximized = false;
  bool _trayActive = false;
  bool _versionChecked = false;

  // Cached so onWindowClose / tray callbacks can act without a context lookup.
  AppController? _ctrl;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    unawaited(windowManager.setPreventClose(true));
    _sync();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ctrl = AppScope.of(context);
    _ctrl = ctrl;

    final shouldHaveTray = ctrl.isAuthenticated && !ctrl.isInitializing;
    if (shouldHaveTray && !_trayActive) {
      _trayActive = true;
      unawaited(_initTray());
    } else if (!shouldHaveTray && _trayActive) {
      _trayActive = false;
      unawaited(_destroyTray());
    } else if (_trayActive) {
      unawaited(_updateTrayTooltip());
    }

    // One-time version check after the user is authenticated and UI is ready.
    if (ctrl.isAuthenticated && !ctrl.isInitializing && !_versionChecked) {
      _versionChecked = true;
      if (AppConfig.isVersionOutdated) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _showOutdatedDialog());
      }
    }
  }

  void _showOutdatedDialog() {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('需要更新'),
        content: Text(
          '当前版本 ${AppConfig.currentVersion} 已过期，'
          '请更新到 ${AppConfig.minVersion} 或更高版本后继续使用。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    if (_trayActive) {
      trayManager.removeListener(this);
      unawaited(trayManager.destroy());
    }
    super.dispose();
  }

  Future<void> _sync() async {
    final m = await windowManager.isMaximized();
    if (mounted) setState(() => _maximized = m);
  }

  // ── Tray ─────────────────────────────────────────────────────────────────

  Future<void> _initTray() async {
    await trayManager.setIcon('assets/images/tray_icon.ico');
    await _updateTrayTooltip();
    await trayManager.setContextMenu(Menu(
      items: [
        MenuItem(key: 'show',  label: '打开 ${AppConfig.appName}'),
        MenuItem.separator(),
        MenuItem(key: 'quit',  label: '退出 ${AppConfig.appName}'),
      ],
    ));
    trayManager.addListener(this);
  }

  Future<void> _updateTrayTooltip() async {
    final ctrl = _ctrl;
    if (ctrl == null) return;
    final status = ctrl.coreRunning ? '已连接' : '未连接';
    await trayManager.setToolTip('${AppConfig.appName}  $status');
  }

  Future<void> _destroyTray() async {
    trayManager.removeListener(this);
    await trayManager.destroy();
  }

  Future<void> _toggleWindow() async {
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
      await _ctrl?.shutdown().timeout(const Duration(seconds: 2));
    } catch (_) {}
    exit(0);
  }

  // ── TrayListener ──────────────────────────────────────────────────────────

  @override
  void onTrayIconMouseDown() => unawaited(_toggleWindow());

  @override
  void onTrayIconRightMouseDown() => unawaited(trayManager.popUpContextMenu());

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'show':
        unawaited(windowManager.show());
        unawaited(windowManager.focus());
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
    if (_ctrl?.isAuthenticated == true) {
      await windowManager.hide();
    } else {
      // Logged out: no core or system proxy to clean up. Exit hard so a
      // pending login / remote-config request can't stall the close (which
      // made windowManager.destroy() hang until the request timed out).
      exit(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final controller = AppScope.of(context);
    final radius = _maximized ? 0.0 : _radius;

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          color: c.appBg,
          borderRadius: BorderRadius.circular(radius),
          boxShadow: _maximized ? null : AppShadows.window,
        ),
        child: controller.isInitializing
            ? const _InitializingShell()
            : (controller.isAuthenticated
                  ? const _MainShell()
                  : const _AuthShell()),
      ),
    );
  }
}

class _InitializingShell extends StatelessWidget {
  const _InitializingShell();

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Stack(
      children: [
        Center(
          child: Container(
            width: 220,
            padding: const EdgeInsets.fromLTRB(24, 26, 24, 22),
            decoration: BoxDecoration(
              color: c.cardBg,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: c.softBorder),
              boxShadow: AppShadows.card(c),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const BrandLogo(size: 44, radius: 14),
                const SizedBox(height: 14),
                Text(
                  '${AppConfig.appName} Client',
                  style: AppTextStyles.bodyStrong.copyWith(
                    color: c.textPrimary,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '正在登录...',
                  style: AppTextStyles.caption.copyWith(color: c.textMuted),
                ),
                const SizedBox(height: 18),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    minHeight: 3,
                    color: c.primary,
                    backgroundColor: c.surfaceMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
        const Positioned(top: 0, left: 0, right: 0, child: WindowControlsBar()),
      ],
    );
  }
}

/// Logged-in layout: full-height sidebar + main column (controls strip + page).
class _MainShell extends StatelessWidget {
  const _MainShell();

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final controller = AppScope.of(context);

    return Row(
      children: [
        const AppSidebar(),
        Expanded(
          child: Column(
            children: [
              const WindowControlsBar(),
              Expanded(
                child: Container(
                  color: c.appBg,
                  padding: const EdgeInsets.fromLTRB(24, 2, 24, 24),
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
                      Expanded(child: _pageFor(controller.page)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _pageFor(AppPage page) {
    switch (page) {
      case AppPage.dashboard:
        return const DashboardPage();
      case AppPage.nodes:
        return const NodesPage();
      case AppPage.shop:
        return const ShopPage();
      case AppPage.traffic:
        return const TrafficPage();
      case AppPage.invite:
        return const InvitePage();
      case AppPage.settings:
        return const SettingsPage();
      case AppPage.account:
        return const AccountPage();
      case AppPage.orders:
        return const OrdersPage();
      case AppPage.tickets:
        return const TicketsPage();
    }
  }
}

/// Logged-out layout: full-width controls strip + centered auth panel.
class _AuthShell extends StatelessWidget {
  const _AuthShell();

  @override
  Widget build(BuildContext context) {
    return const Stack(
      children: [
        Positioned.fill(child: AuthFlow()),
        Positioned(top: 0, left: 0, right: 0, child: WindowControlsBar()),
      ],
    );
  }
}
