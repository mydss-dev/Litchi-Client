import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../../app/app_controller.dart';
import '../../app/plan_presentation.dart';
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
        : const V3NoticeHost(child: _V3Workspace());
    if (!_isDesktopTarget) {
      return Material(
        color: V3Palette.of(context).canvas,
        child: SafeArea(bottom: false, child: body),
      );
    }
    return Material(
      color: V3Palette.of(context).canvas,
      child: Column(children: [
        const _DesktopWindowBar(),
        Expanded(child: body),
      ]),
    );
  }
}

class _V3Workspace extends StatelessWidget {
  const _V3Workspace();

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final p = V3Palette.of(context);
    return LayoutBuilder(builder: (context, constraints) {
      final compact = constraints.maxWidth < 760;
      final page = _pageFor(controller.page, context);
      if (compact) {
        return Scaffold(
          backgroundColor: p.canvas,
          body: page,
          bottomNavigationBar: _MobileNavigation(controller: controller),
        );
      }
      return ColoredBox(
        color: p.canvas,
        child: Row(children: [
          _DesktopRail(controller: controller),
          Expanded(child: Padding(
            padding: const EdgeInsets.fromLTRB(0, 0, 18, 18),
            child: page,
          )),
        ]),
      );
    });
  }
}

Widget _pageFor(AppPage page, BuildContext context) {
  final l = Localizations.of<AppLocalizations>(context, AppLocalizations) ??
      AppLocalizationsZh();
  return switch (page) {
    AppPage.nodes => const V3NodesPage(),
    AppPage.shop => const V3ShopPage(),
    AppPage.account => const V3AccountPage(),
    AppPage.invite => const V3InvitePage(),
    AppPage.traffic => const V3TrafficPage(),
    AppPage.orders => V3SheetPageFallback(
      kicker: 'ORDER LEDGER', title: l.orders, child: const V3OrdersPage(),
    ),
    AppPage.tickets => const V3TicketsPage(),
    AppPage.settings => const V3SettingsPage(),
    AppPage.dashboard => const V3DashboardPage(),
    AppPage.more => const V3MorePage(),
    AppPage.giftCard => V3SheetPageFallback(
      kicker: l.giftCardTitle, title: l.giftCardTitle,
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
    final l = Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        AppLocalizationsZh();
    return Container(
      width: 184,
      margin: const EdgeInsets.fromLTRB(18, 18, 14, 18),
      padding: const EdgeInsets.fromLTRB(14, 18, 14, 14),
      decoration: BoxDecoration(color: p.hero,
        borderRadius: BorderRadius.circular(24)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(2, 0, 2, 26),
          child: V3BrandMark(),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 10, bottom: 10),
          child: Text(l.localeName.startsWith('en') ? 'WORKSPACE' : '工作空间',
            style: TextStyle(color: p.inkMuted, fontSize: 10,
              fontWeight: FontWeight.w800, letterSpacing: 1.5)),
        ),
        ...[
          ...enabledNavItems(kDesktopRail),
          if (kRailSettings.isEnabled) kRailSettings,
        ].map((item) => _RailItem(
          key: railItemKey(item.page),
          item: item,
          selected: controller.page == item.page,
          onTap: () => openV3Page(context, item.page),
        )),
        const Spacer(),
        const SizedBox(height: 12),
        InkWell(
          key: kAccountCardKey,
          borderRadius: BorderRadius.circular(16),
          onTap: () => controller.goToPage(AppPage.account),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: p.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: p.line)),
            child: Row(children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: p.lychee,
                child: Text(user.avatarLetter.isEmpty ? '?' : user.avatarLetter,
                  style: const TextStyle(color: Colors.white,
                    fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user.name.isEmpty ? 'Guest' : user.name,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: p.ink, fontWeight: FontWeight.w700,
                      fontSize: 12)),
                  const SizedBox(height: 2),
                  Tooltip(
                    message: '${plan.shortLabel} · ${plan.expiry}',
                    child: Text(plan.shortLabel,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: plan.usable
                        ? p.successInk : p.inkMuted, fontSize: 10)),
                  ),
                ],
              )),
              Icon(Icons.chevron_right_rounded,
                color: p.ink.withValues(alpha: 0.45), size: 18),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _RailItem extends StatelessWidget {
  const _RailItem({super.key, required this.item,
    required this.selected, required this.onTap});
  final V3NavItem item;
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
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(end: selected ? 1 : 0),
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          builder: (context, t, _) {
            final iconColor = Color.lerp(p.inkMuted, p.lycheeInk, t)!;
            final textColor = Color.lerp(p.inkMuted, p.ink, t)!;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              decoration: BoxDecoration(
                color: p.lycheeSoft.withValues(alpha: t),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(children: [
                Icon(item.icon, color: iconColor, size: 19),
                const SizedBox(width: 12),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.localizedLabel(context),
                      style: TextStyle(color: textColor,
                        fontSize: 13, fontWeight: FontWeight.w700)),
                  ],
                )),
              ]),
            );
          },
        ),
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
      child: Row(children: [
        Text('LITCHI / PRIVATE NETWORK',
          style: TextStyle(color: p.inkMuted, fontSize: 10,
            fontWeight: FontWeight.w800, letterSpacing: 1.4)),
        const Spacer(),
        Text('V3', style: TextStyle(color: p.lycheeInk, fontSize: 10,
          fontWeight: FontWeight.w900, letterSpacing: 1.4)),
        const SizedBox(width: 14),
      ]),
    );
    return Container(
      height: 42,
      color: p.canvas,
      child: Row(children: [
        if (_usesNativeControls) const SizedBox(width: 76),
        Expanded(child: Padding(
          padding: const EdgeInsets.only(left: 22),
          child: draggableBrand,
        )),
        if (!_usesNativeControls) ...[
          _V3WindowButton(tooltip: 'Minimize', icon: Icons.remove_rounded,
            onPressed: windowManager.minimize),
          _V3WindowButton(tooltip: _maximized ? 'Restore' : 'Maximize',
            icon: _maximized ? Icons.filter_none_rounded
                : Icons.crop_square_rounded, onPressed: _toggleMaximize),
          _V3WindowButton(tooltip: 'Close', icon: Icons.close_rounded,
            close: true, onPressed: _closeWindow),
        ],
      ]),
    );
  }
}

class _V3WindowButton extends StatelessWidget {
  const _V3WindowButton({required this.tooltip,
    required this.icon, required this.onPressed, this.close = false});
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
      color: p.hero,
      child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(color: p.citrus,
            borderRadius: BorderRadius.circular(18)),
          child: Icon(Icons.blur_on_rounded, color: p.night, size: 34),
        ),
        const SizedBox(height: 18),
        Text('LITCHI', style: TextStyle(color: p.ink,
          fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 3)),
        const SizedBox(height: 20),
        SizedBox(width: 90, child: LinearProgressIndicator(
          minHeight: 3, color: p.lycheeInk,
          backgroundColor: p.ink.withValues(alpha: 0.15),
        )),
      ])),
    );
  }
}
