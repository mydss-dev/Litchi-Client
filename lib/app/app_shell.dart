import 'dart:async';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../features/account/account_page.dart';
import '../features/auth/auth_flow.dart';
import '../features/dashboard/dashboard_page.dart';
import '../features/invite/invite_page.dart';
import '../features/nodes/nodes_page.dart';
import '../features/orders/orders_page.dart';
import '../features/settings/settings_page.dart';
import '../features/shop/shop_page.dart';
import '../features/traffic/traffic_page.dart';
import '../shared/theme/app_colors.dart';
import '../shared/theme/app_shadows.dart';
import '../shared/theme/app_text_styles.dart';
import '../shared/widgets/brand_logo.dart';
import '../shared/widgets/app_sidebar.dart';
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

class _AppShellState extends State<AppShell> with WindowListener {
  static const double _radius = 18;
  bool _maximized = false;

  // Cached so onWindowClose can call shutdown without a context lookup.
  AppController? _ctrl;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    // Intercept the close button so we can clean up before the OS exits.
    unawaited(windowManager.setPreventClose(true));
    _sync();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ctrl = AppScope.of(context);
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  Future<void> _sync() async {
    final m = await windowManager.isMaximized();
    if (mounted) setState(() => _maximized = m);
  }

  @override
  void onWindowMaximize() => setState(() => _maximized = true);

  @override
  void onWindowUnmaximize() => setState(() => _maximized = false);

  /// Stop sing-box + disable system proxy before the window actually closes.
  @override
  Future<void> onWindowClose() async {
    await _ctrl?.shutdown();
    await windowManager.destroy();
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
                  'Litchi Client',
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
                  child: _pageFor(controller.page),
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
    }
  }
}

/// Logged-out layout: full-width controls strip + centered auth panel. No
/// sidebar; the brand lives inside the auth panel's visual area.
class _AuthShell extends StatelessWidget {
  const _AuthShell();

  @override
  Widget build(BuildContext context) {
    // Full-bleed auth fills the window; the controls float on top so the left
    // gradient reaches the rounded top-left corner.
    return const Stack(
      children: [
        Positioned.fill(child: AuthFlow()),
        Positioned(top: 0, left: 0, right: 0, child: WindowControlsBar()),
      ],
    );
  }
}
