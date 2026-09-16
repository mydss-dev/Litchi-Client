import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../../app/app_controller.dart';
import '../auth/v3_auth_view.dart';
import '../pages/v3_account_page.dart';
import '../pages/v3_dashboard_page.dart';
import '../pages/v3_invite_page.dart';
import '../pages/v3_nodes_page.dart';
import '../pages/v3_orders_page.dart';
import '../pages/v3_settings_page.dart';
import '../pages/v3_shop_page.dart';
import '../pages/v3_tickets_page.dart';
import '../pages/v3_traffic_page.dart';
import '../pages/v3_wallet_page.dart';
import '../theme/v3_palette.dart';

bool get _isDesktopTarget =>
    !kIsWeb &&
    switch (defaultTargetPlatform) {
      TargetPlatform.windows ||
      TargetPlatform.macOS ||
      TargetPlatform.linux => true,
      _ => false,
    };

class V3Shell extends StatelessWidget {
  const V3Shell({super.key, this.launchSilently = false});

  final bool launchSilently;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final body = controller.isInitializing
        ? const _V3BootView()
        : !controller.isAuthenticated
        ? const V3AuthView()
        : const _V3Workspace();
    if (!_isDesktopTarget) return body;
    return Material(
      color: V3Palette.of(context).canvas,
      child: Column(
        children: [
          const _DesktopWindowBar(),
          Expanded(child: body),
        ],
      ),
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
        final compact = constraints.maxWidth < 760;
        final page = _pageFor(controller.page);
        if (compact) {
          return Scaffold(
            backgroundColor: p.canvas,
            body: page,
            bottomNavigationBar: _MobileNavigation(controller: controller),
          );
        }
        return ColoredBox(
          color: p.canvas,
          child: Row(
            children: [
              _DesktopRail(controller: controller),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 0, 18, 18),
                  child: page,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

Widget _pageFor(AppPage page) => switch (page) {
  AppPage.nodes => const V3NodesPage(),
  AppPage.shop => const V3ShopPage(),
  AppPage.account => const V3AccountPage(),
  AppPage.wallet => const V3WalletPage(),
  AppPage.invite => const V3InvitePage(),
  AppPage.traffic => const V3TrafficPage(),
  AppPage.orders => const V3OrdersPage(),
  AppPage.tickets => const V3TicketsPage(),
  AppPage.settings => const V3SettingsPage(),
  AppPage.dashboard => const V3DashboardPage(),
};

class _DesktopRail extends StatelessWidget {
  const _DesktopRail({required this.controller});

  final AppController controller;

  static const _items =
      <({AppPage page, IconData icon, String label, String hint})>[
        (
          page: AppPage.dashboard,
          icon: Icons.radar_rounded,
          label: '连接',
          hint: 'overview',
        ),
        (
          page: AppPage.nodes,
          icon: Icons.hub_rounded,
          label: '节点',
          hint: 'nodes',
        ),
        (
          page: AppPage.shop,
          icon: Icons.shopping_bag_outlined,
          label: '套餐',
          hint: 'upgrade',
        ),
        (
          page: AppPage.traffic,
          icon: Icons.insights_rounded,
          label: '流量',
          hint: 'usage',
        ),
        (
          page: AppPage.invite,
          icon: Icons.auto_awesome_rounded,
          label: '邀请',
          hint: 'invite',
        ),
        (
          page: AppPage.tickets,
          icon: Icons.forum_outlined,
          label: '工单',
          hint: 'support',
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    final user = controller.user;
    return Container(
      width: 184,
      margin: const EdgeInsets.fromLTRB(18, 18, 14, 18),
      padding: const EdgeInsets.fromLTRB(14, 18, 14, 14),
      decoration: BoxDecoration(
        color: p.night,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 0, 2, 26),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: p.citrus,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.blur_on_rounded, color: p.night, size: 20),
                ),
                const SizedBox(width: 10),
                const Text(
                  'LITCHI',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.8,
                  ),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(left: 10, bottom: 10),
            child: Text(
              '工作空间',
              style: TextStyle(
                color: Color(0xFF8E9A95),
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
              ),
            ),
          ),
          ..._items.map(
            (item) => _RailItem(
              item: item,
              selected: controller.page == item.page,
              onTap: () => controller.goToPage(item.page),
            ),
          ),
          const Spacer(),
          _RailItem(
            item: (
              page: AppPage.settings,
              icon: Icons.tune_rounded,
              label: '设置',
              hint: 'settings',
            ),
            selected: controller.page == AppPage.settings,
            onTap: () => controller.goToPage(AppPage.settings),
          ),
          const SizedBox(height: 12),
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => controller.goToPage(AppPage.account),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: p.lychee,
                    child: Text(
                      user.avatarLetter.isEmpty ? '?' : user.avatarLetter,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.name.isEmpty ? 'Guest' : user.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          controller.hasPlan
                              ? (user.plan.trim().isEmpty ? '已激活套餐' : user.plan)
                              : '暂无套餐',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF9BA8A3),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.white.withValues(alpha: 0.45),
                    size: 18,
                  ),
                ],
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
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final ({AppPage page, IconData icon, String label, String hint}) item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? p.lychee.withValues(alpha: 0.18)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Icon(
                item.icon,
                color: selected ? p.lychee : const Color(0xFF9BA8A3),
                size: 19,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.label,
                      style: TextStyle(
                        color: selected
                            ? Colors.white
                            : const Color(0xFFE3E9E5),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MobileNavigation extends StatelessWidget {
  const _MobileNavigation({required this.controller});

  final AppController controller;

  static const _pages = [
    AppPage.dashboard,
    AppPage.nodes,
    AppPage.shop,
    AppPage.account,
  ];
  static const _icons = [
    Icons.radar_rounded,
    Icons.hub_rounded,
    Icons.shopping_bag_outlined,
    Icons.person_outline_rounded,
  ];
  static const _labels = ['连接', '节点', '套餐', '账户'];

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    final selected = switch (controller.page) {
      AppPage.dashboard => 0,
      AppPage.nodes => 1,
      AppPage.shop => 2,
      _ => 3,
    };
    return NavigationBar(
      height: 72,
      backgroundColor: p.surface,
      indicatorColor: p.lycheeSoft,
      selectedIndex: selected,
      onDestinationSelected: (index) => controller.goToPage(_pages[index]),
      destinations: [
        for (var i = 0; i < _pages.length; i++)
          NavigationDestination(
            icon: Icon(_icons[i]),
            selectedIcon: Icon(_icons[i], color: p.lychee),
            label: _labels[i],
          ),
      ],
    );
  }
}

class _DesktopWindowBar extends StatefulWidget {
  const _DesktopWindowBar();

  @override
  State<_DesktopWindowBar> createState() => _DesktopWindowBarState();
}

class _DesktopWindowBarState extends State<_DesktopWindowBar>
    with WindowListener {
  bool _maximized = false;

  bool get _usesNativeControls => defaultTargetPlatform == TargetPlatform.macOS;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
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

  Future<void> _closeWindow() async {
    try {
      await AppScope.of(context).shutdown();
      await windowManager.close();
    } catch (_) {
      // Native window APIs are unavailable in widget tests.
    }
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
    final p = V3Palette.of(context);
    final draggableBrand = GestureDetector(
      behavior: HitTestBehavior.translucent,
      onPanStart: (_) => windowManager.startDragging(),
      onDoubleTap: _toggleMaximize,
      child: Row(
        children: [
          Text(
            'LITCHI / PRIVATE NETWORK',
            style: TextStyle(
              color: p.inkMuted,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
            ),
          ),
          const Spacer(),
          Text(
            'V3',
            style: TextStyle(
              color: p.lychee,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(width: 14),
        ],
      ),
    );
    return Container(
      height: 42,
      color: p.canvas,
      child: Row(
        children: [
          if (_usesNativeControls) const SizedBox(width: 76),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 22),
              child: draggableBrand,
            ),
          ),
          if (!_usesNativeControls) ...[
            _V3WindowButton(
              tooltip: 'Minimize',
              icon: Icons.remove_rounded,
              onPressed: windowManager.minimize,
            ),
            _V3WindowButton(
              tooltip: _maximized ? 'Restore' : 'Maximize',
              icon: _maximized
                  ? Icons.filter_none_rounded
                  : Icons.crop_square_rounded,
              onPressed: _toggleMaximize,
            ),
            _V3WindowButton(
              tooltip: 'Close',
              icon: Icons.close_rounded,
              close: true,
              onPressed: _closeWindow,
            ),
          ],
        ],
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
      height: 42,
      child: IconButton(
        tooltip: tooltip,
        padding: EdgeInsets.zero,
        style: IconButton.styleFrom(
          shape: const RoundedRectangleBorder(),
          foregroundColor: close ? p.lychee : p.inkMuted,
          hoverColor: close ? p.lychee : p.surfaceRaised,
          highlightColor: close ? p.lychee : p.line,
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
      color: p.night,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: p.citrus,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(Icons.blur_on_rounded, color: p.night, size: 34),
            ),
            const SizedBox(height: 18),
            const Text(
              'LITCHI',
              style: TextStyle(
                color: Colors.white,
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
                color: p.lychee,
                backgroundColor: Colors.white24,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
