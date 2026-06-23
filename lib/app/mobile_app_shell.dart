import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../features/auth/auth_flow.dart';
import '../features/mobile/mobile_home_page.dart';
import '../features/mobile/mobile_invite_page.dart';
import '../features/mobile/mobile_nodes_page.dart';
import '../features/mobile/mobile_orders_page.dart';
import '../features/mobile/mobile_profile_page.dart';
import '../features/mobile/mobile_settings_page.dart';
import '../features/mobile/mobile_shop_page.dart';
import '../features/mobile/mobile_tickets_page.dart';
import '../features/mobile/mobile_traffic_page.dart';
import '../features/mobile/mobile_wallet_page.dart';
import '../shared/config/app_config.dart';
import '../shared/theme/app_colors.dart';
import '../shared/theme/app_radius.dart';
import '../shared/theme/app_shadows.dart';
import '../shared/theme/app_text_styles.dart';
import 'app_controller.dart';

class MobileAppShell extends StatelessWidget {
  const MobileAppShell({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = AppScope.of(context);
    if (!ctrl.isAuthenticated) return const AuthFlow();
    return const _MobileShell();
  }
}

class _MobileShell extends StatelessWidget {
  const _MobileShell();

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final ctrl = AppScope.of(context);
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Container(
      color: c.appBg,
      child: SafeArea(
        top: true,
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: _pageFor(ctrl.page),
              ),
            ),
            _MobileBottomNav(bottomPadding: bottom),
          ],
        ),
      ),
    );
  }

  Widget _pageFor(AppPage page) {
    switch (page) {
      case AppPage.dashboard:
        return const MobileHomePage();
      case AppPage.traffic:
        return const MobileTrafficPage();
      case AppPage.nodes:
        return const MobileNodesPage();
      case AppPage.shop:
        return const MobileShopPage();
      case AppPage.orders:
        return const MobileOrdersPage();
      case AppPage.settings:
        return const MobileSettingsPage();
      case AppPage.invite:
        return const MobileInvitePage();
      case AppPage.tickets:
        return const MobileTicketsPage();
      case AppPage.account:
        return const MobileProfilePage();
      case AppPage.wallet:
        return const MobileWalletPage();
    }
  }
}

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
    for (final tab in AppConfig.mobileTabs.take(3)) _mobileNavItemFor(tab),
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
