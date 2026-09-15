import 'dart:io';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../../app/app_controller.dart';
import '../auth/v3_auth_view.dart';
import '../pages/v3_account_page.dart';
import '../pages/v3_dashboard_page.dart';
import '../pages/v3_invite_page.dart';
import '../pages/v3_nodes_page.dart';
import '../pages/v3_settings_page.dart';
import '../pages/v3_shop_page.dart';
import '../pages/v3_wallet_page.dart';
import '../theme/v3_palette.dart';

class V3Shell extends StatelessWidget {
  const V3Shell({super.key, this.launchSilently = false});

  final bool launchSilently;

  bool get _desktop => Platform.isWindows || Platform.isMacOS || Platform.isLinux;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final body = controller.isInitializing
        ? const _V3BootView()
        : !controller.isAuthenticated
        ? const V3AuthView()
        : const _V3Workspace();

    if (!_desktop) return body;
    return Column(
      children: [
        const _DesktopWindowBar(),
        Expanded(child: body),
      ],
    );
  }
}

class _V3Workspace extends StatelessWidget {
  const _V3Workspace();

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final p = V3Palette.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final mobile = constraints.maxWidth < 680;
        final page = switch (controller.page) {
          AppPage.nodes => const V3NodesPage(),
          AppPage.shop => const V3ShopPage(),
          AppPage.account => const V3AccountPage(),
          AppPage.wallet => const V3WalletPage(),
          AppPage.invite => const V3InvitePage(),
          AppPage.settings => const V3SettingsPage(),
          _ => const V3DashboardPage(),
        };

        if (mobile) {
          return Scaffold(
            backgroundColor: p.canvas,
            body: page,
            floatingActionButton: controller.page == AppPage.account
                ? FloatingActionButton.small(
                    tooltip: '邀请朋友',
                    onPressed: () => controller.goToPage(AppPage.invite),
                    child: const Icon(Icons.group_add_rounded),
                  )
                : null,
            bottomNavigationBar: _MobileNav(controller: controller),
          );
        }

        return ColoredBox(
          color: p.canvas,
          child: Row(
            children: [
              _DesktopRail(controller: controller),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 0, 10, 10),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: ColoredBox(color: p.canvas, child: page),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DesktopRail extends StatelessWidget {
  const _DesktopRail({required this.controller});

  final AppController controller;

  int get _current => switch (controller.page) {
    AppPage.nodes => 1,
    AppPage.shop => 2,
    AppPage.settings => 3,
    AppPage.wallet => 4,
    AppPage.invite => 5,
    AppPage.account || AppPage.traffic || AppPage.orders || AppPage.tickets => 6,
    _ => 0,
  };

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    final current = _current;
    return Container(
      width: 86,
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
      decoration: BoxDecoration(
        color: p.rail,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        children: [
          const SizedBox(height: 18),
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: p.accent,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Text(
              'L',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 28),
          _RailButton(
            icon: Icons.blur_circular_rounded,
            label: '连接',
            selected: current == 0,
            onTap: () => controller.goToPage(AppPage.dashboard),
          ),
          const SizedBox(height: 8),
          _RailButton(
            icon: Icons.hub_rounded,
            label: '节点',
            selected: current == 1,
            onTap: () => controller.goToPage(AppPage.nodes),
          ),
          const SizedBox(height: 8),
          _RailButton(
            icon: Icons.storefront_rounded,
            label: '套餐',
            selected: current == 2,
            onTap: () => controller.goToPage(AppPage.shop),
          ),
          const SizedBox(height: 8),
          _RailButton(
            icon: Icons.tune_rounded,
            label: '设置',
            selected: current == 3,
            onTap: () => controller.goToPage(AppPage.settings),
          ),
          const Spacer(),
          _RailButton(
            icon: Icons.account_balance_wallet_rounded,
            label: '钱包',
            selected: current == 4,
            onTap: () => controller.goToPage(AppPage.wallet),
          ),
          const SizedBox(height: 8),
          _RailButton(
            icon: Icons.group_add_rounded,
            label: '邀请',
            selected: current == 5,
            onTap: () => controller.goToPage(AppPage.invite),
          ),
          const SizedBox(height: 8),
          Tooltip(
            message: controller.user.name.isEmpty ? '账户' : controller.user.name,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => controller.goToPage(AppPage.account),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: current == 6
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  controller.user.avatarLetter.isEmpty
                      ? 'U'
                      : controller.user.avatarLetter.substring(0, 1).toUpperCase(),
                  style: TextStyle(
                    color: current == 6 ? p.rail : Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          _RailButton(
            icon: Icons.logout_rounded,
            label: '退出',
            selected: false,
            onTap: controller.logout,
          ),
          const SizedBox(height: 18),
        ],
      ),
    );
  }
}

class _RailButton extends StatelessWidget {
  const _RailButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return Tooltip(
      message: label,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            icon,
            size: 21,
            color: selected ? p.rail : Colors.white.withValues(alpha: 0.56),
          ),
        ),
      ),
    );
  }
}

class _MobileNav extends StatelessWidget {
  const _MobileNav({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    final current = switch (controller.page) {
      AppPage.nodes => 1,
      AppPage.shop => 2,
      AppPage.account ||
      AppPage.wallet ||
      AppPage.invite ||
      AppPage.traffic ||
      AppPage.orders ||
      AppPage.tickets => 3,
      AppPage.settings => 4,
      _ => 0,
    };
    return SafeArea(
      top: false,
      child: Container(
        height: 66,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        decoration: BoxDecoration(
          color: p.rail,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          children: [
            _MobileNavItem(
              icon: Icons.blur_circular_rounded,
              label: '连接',
              selected: current == 0,
              onTap: () => controller.goToPage(AppPage.dashboard),
            ),
            _MobileNavItem(
              icon: Icons.hub_rounded,
              label: '节点',
              selected: current == 1,
              onTap: () => controller.goToPage(AppPage.nodes),
            ),
            _MobileNavItem(
              icon: Icons.storefront_rounded,
              label: '套餐',
              selected: current == 2,
              onTap: () => controller.goToPage(AppPage.shop),
            ),
            _MobileNavItem(
              icon: Icons.person_rounded,
              label: '我的',
              selected: current == 3,
              onTap: () => controller.goToPage(AppPage.account),
            ),
            _MobileNavItem(
              icon: Icons.tune_rounded,
              label: '设置',
              selected: current == 4,
              onTap: () => controller.goToPage(AppPage.settings),
            ),
          ],
        ),
      ),
    );
  }
}

class _MobileNavItem extends StatelessWidget {
  const _MobileNavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 20,
              color: selected ? p.accent : Colors.white.withValues(alpha: 0.48),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: selected
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.42),
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DesktopWindowBar extends StatelessWidget {
  const _DesktopWindowBar();

  @override
  Widget build(BuildContext context) {
    if (!Platform.isWindows && !Platform.isMacOS && !Platform.isLinux) {
      return const SizedBox.shrink();
    }
    final p = V3Palette.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onPanStart: (_) => windowManager.startDragging(),
      onDoubleTap: () async {
        if (await windowManager.isMaximized()) {
          await windowManager.unmaximize();
        } else {
          await windowManager.maximize();
        }
      },
      child: SizedBox(
        height: 44,
        child: Row(
          children: [
            const SizedBox(width: 16),
            Text(
              'LITCHI / V3',
              style: TextStyle(
                color: p.textMuted,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.6,
              ),
            ),
            const Spacer(),
            if (!Platform.isMacOS) ...[
              _WindowButton(icon: Icons.remove_rounded, onTap: windowManager.minimize),
              _WindowButton(
                icon: Icons.crop_square_rounded,
                onTap: () async {
                  if (await windowManager.isMaximized()) {
                    await windowManager.unmaximize();
                  } else {
                    await windowManager.maximize();
                  }
                },
              ),
              _WindowButton(
                icon: Icons.close_rounded,
                danger: true,
                onTap: windowManager.close,
              ),
            ] else
              const SizedBox(width: 12),
          ],
        ),
      ),
    );
  }
}

class _WindowButton extends StatelessWidget {
  const _WindowButton({
    required this.icon,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        width: 46,
        height: 44,
        child: Icon(
          icon,
          size: 16,
          color: danger ? p.danger : p.textMuted,
        ),
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
      color: p.rail,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: p.accent,
                borderRadius: BorderRadius.circular(17),
              ),
              child: const Text(
                'L',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'STARTING LITCHI V3',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.55),
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
