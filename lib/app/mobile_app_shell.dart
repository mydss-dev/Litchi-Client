import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../features/auth/auth_flow.dart';
import '../features/mobile/mobile_home_page.dart';
import '../features/mobile/mobile_nodes_page.dart';
import '../features/mobile/mobile_profile_page.dart';
import '../features/mobile/mobile_shop_page.dart';
import '../shared/theme/app_colors.dart';
import '../shared/theme/app_radius.dart';
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
      case AppPage.traffic:
        return const MobileHomePage();
      case AppPage.nodes:
        return const MobileNodesPage();
      case AppPage.shop:
      case AppPage.orders:
        return const MobileShopPage();
      case AppPage.account:
      case AppPage.invite:
      case AppPage.settings:
      case AppPage.tickets:
        return const MobileProfilePage();
    }
  }
}

class _MobileBottomNav extends StatelessWidget {
  const _MobileBottomNav({required this.bottomPadding});

  final double bottomPadding;

  static const _items = [
    _MobileNavItem(AppPage.dashboard, LucideIcons.home, '首页'),
    _MobileNavItem(AppPage.nodes, LucideIcons.globe, '节点'),
    _MobileNavItem(AppPage.shop, LucideIcons.shoppingBag, '套餐'),
    _MobileNavItem(AppPage.account, LucideIcons.user, '我的'),
  ];

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final ctrl = AppScope.of(context);

    return Container(
      padding: EdgeInsets.fromLTRB(10, 8, 10, bottomPadding + 8),
      decoration: BoxDecoration(
        color: c.cardBg,
        border: Border(top: BorderSide(color: c.softBorder)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: Row(
        children: [
          for (final item in _items)
            Expanded(
              child: _MobileNavButton(
                item: item,
                selected: _isSelected(ctrl.page, item.page),
                onTap: () => ctrl.goToPage(item.page),
              ),
            ),
        ],
      ),
    );
  }

  bool _isSelected(AppPage current, AppPage tab) {
    if (tab == AppPage.dashboard) {
      return current == AppPage.dashboard || current == AppPage.traffic;
    }
    if (tab == AppPage.shop) {
      return current == AppPage.shop || current == AppPage.orders;
    }
    if (tab == AppPage.account) {
      return current == AppPage.account ||
          current == AppPage.invite ||
          current == AppPage.settings ||
          current == AppPage.tickets;
    }
    return current == tab;
  }
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

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 48,
        margin: const EdgeInsets.symmetric(horizontal: 3),
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
    );
  }
}

class _MobileNavItem {
  const _MobileNavItem(this.page, this.icon, this.label);

  final AppPage page;
  final IconData icon;
  final String label;
}
