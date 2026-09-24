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
  AppPage.dashboard || AppPage.account || AppPage.invite || AppPage.traffic => true,
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
    return LayoutBuilder(builder: (context, constraints) {
      final compact = constraints.maxWidth < 760;
      final current = controller.page;
      if (!_visited.contains(current)) _visited.add(current);
      // StackFit.expand keeps every page's scroll view filling the pane: a
      // loose stack shrinks short pages (empty states, error states) to their
      // content height and the Offstage stack then centers them vertically —
      // tall pages top-align while short ones float mid-pane.
      final stack = Stack(fit: StackFit.expand, children: [
        for (final page in _visited)
          Offstage(
            offstage: page != current,
            child: _pageFor(page, context),
          ),
      ]);
      if (compact) {
        final mobilePage = !_isDesktopTarget &&
                v3SupportsMobileRefresh(current)
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
        child: Row(children: [
          _DesktopRail(controller: controller),
          Expanded(child: Padding(
            padding: const EdgeInsets.fromLTRB(0, 0, 12, 12),
            child: stack,
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
      kicker: v3Copy(context, zh: '订单中心',
        en: 'ORDER CENTER', tw: '訂單中心'),
      title: l.orders,
      description: v3Copy(context,
        zh: '所有购买记录和支付状态都集中在这里。',
        en: 'Every purchase and its payment status in one place.',
        tw: '所有購買紀錄與付款狀態集中在這裡。'),
      child: const V3OrdersPage(),
    ),
    AppPage.tickets => const V3TicketsPage(),
    AppPage.settings => const V3SettingsPage(),
    AppPage.dashboard => const V3DashboardPage(),
    AppPage.more => const V3MorePage(),
    AppPage.giftCard => V3SheetPageFallback(
      kicker: v3Copy(context, zh: '兑换中心',
        en: 'REDEMPTION', tw: '兌換中心'),
      title: v3Copy(context,
        zh: '礼品卡兑换', en: 'Gift card', tw: '禮品卡兌換'),
      description: v3Copy(context,
        zh: '输入兑换码，权益到账后自动同步到账户。',
        en: 'Enter a code; benefits sync to your account automatically.',
        tw: '輸入兌換碼，權益到賬後自動同步到帳戶。'),
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
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
      decoration: BoxDecoration(
        color: p.hero,
        border: Border.all(color: p.line),
        borderRadius: BorderRadius.circular(V3Radius.card)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(2, 0, 2, 26),
          child: V3BrandMark(boxSize: 34),
        ),
        ...[
          // Dashboard and connection are the same AppPage.dashboard route.
          // Never introduce a second Home item alongside Connect.
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
        Container(
          key: kAccountCardKey,
          decoration: BoxDecoration(color: p.surface,
            borderRadius: BorderRadius.circular(V3Radius.card),
            border: Border.all(color: p.line)),
          child: V3Pressable(
            borderRadius: BorderRadius.circular(V3Radius.card),
            onTap: () => controller.goToPage(AppPage.account),
            child: Padding(
              padding: const EdgeInsets.all(9),
              child: Row(children: [
                CircleAvatar(
                  radius: 17,
                  backgroundColor: p.lychee,
                  child: Text(user.avatarLetter.isEmpty ? '?' : user.avatarLetter,
                    style: TextStyle(color: p.onLychee,
                      fontWeight: FontWeight.w800)),
                ),
                const SizedBox(width: 7),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user.name.isEmpty
                        ? v3Copy(context, zh: '访客', en: 'Guest', tw: '訪客')
                        : user.name,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: p.ink, fontWeight: FontWeight.w700,
                        fontSize: 11)),
                    const SizedBox(height: 2),
                    Tooltip(message: '${plan.shortLabel} · ${plan.expiry}',
                      child: Text(plan.shortLabel, maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: plan.usable
                          ? p.successInk : p.inkMuted, fontSize: 10)),
                    ),
                  ],
                )),
                Icon(Icons.chevron_right_rounded,
                  color: p.ink.withValues(alpha: 0.45), size: 16),
              ]),
            ),
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
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: p.lycheeSoft.withValues(alpha: t),
              borderRadius: BorderRadius.circular(V3Radius.field),
            ),
            child: V3Pressable(
              borderRadius: BorderRadius.circular(V3Radius.field),
              onTap: onTap,
              child: Row(children: [
                Icon(item.icon, color: iconColor, size: 19),
                const SizedBox(width: 12),
                Expanded(child: Text(item.localizedLabel(context),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: textColor,
                    fontSize: 13, fontWeight: FontWeight.w700))),
              ]),
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
    final p = V3Palette.of(context);
    final controller = AppScope.of(context);
    // Redemption moves to the title bar: the gift button replaces the V3 mark
    // when the panel offers it, and the mark stays when it does not.
    final giftEntry = isPageEnabled(AppPage.giftCard) && controller.isAuthenticated;
    // The gift button sits OUTSIDE the drag surface: a double-tap recognizer
    // on its ancestor enters the gesture arena and delays or swallows the
    // button's single tap.
    final dragSurface = GestureDetector(
      behavior: HitTestBehavior.translucent,
      onPanStart: (_) => windowManager.startDragging(),
      onDoubleTap: _toggleMaximize,
      child: Row(children: [
        Text('LITCHI / PRIVATE NETWORK',
          style: TextStyle(color: p.inkMuted, fontSize: 10,
            fontWeight: FontWeight.w800, letterSpacing: 1.4)),
        const Spacer(),
      ]),
    );
    return Container(
      height: 42,
      color: p.canvas,
      child: Row(children: [
        if (_usesNativeControls) const SizedBox(width: 76),
        Expanded(child: Padding(
          padding: const EdgeInsets.only(left: 22),
          child: dragSurface,
        )),
        if (giftEntry) ...[
          IconButton(
            key: kWindowGiftCardKey,
            tooltip: v3Copy(context, zh: '兑换中心',
              en: 'Redemption', tw: '兌換中心'),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
            onPressed: () => openV3Page(context, AppPage.giftCard),
            icon: Icon(Icons.redeem_rounded, size: 18, color: p.lycheeInk)),
          const SizedBox(width: 4),
        ] else
          Padding(padding: const EdgeInsets.only(right: 14),
            child: Text('V3', style: TextStyle(color: p.lycheeInk, fontSize: 10,
              fontWeight: FontWeight.w900, letterSpacing: 1.4))),
        if (!_usesNativeControls) ...[
          _V3WindowButton(
            tooltip: v3Copy(context, zh: '最小化', en: 'Minimize', tw: '最小化'),
            icon: Icons.remove_rounded, onPressed: windowManager.minimize),
          _V3WindowButton(
            tooltip: _maximized
                ? v3Copy(context, zh: '还原', en: 'Restore', tw: '還原')
                : v3Copy(context, zh: '最大化', en: 'Maximize', tw: '最大化'),
            icon: _maximized ? Icons.filter_none_rounded
                : Icons.crop_square_rounded, onPressed: _toggleMaximize),
          _V3WindowButton(
            tooltip: v3Copy(context, zh: '关闭', en: 'Close', tw: '關閉'),
            icon: Icons.close_rounded,
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
      child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(color: p.citrus,
            borderRadius: BorderRadius.circular(V3Radius.card)),
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
