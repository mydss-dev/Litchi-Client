import 'package:flutter/material.dart';

import '../../app/app_controller.dart';

/// Where a destination is surfaced in the v3 shell.
///
/// Desktop and compact placement are declared independently: the desktop rail
/// is a wide-screen information architecture, not a scaled-up bottom nav.
enum V3NavPlacement {
  /// Compact bottom-navigation tab.
  mobilePrimary,

  /// Reached from the account page's "我的服务" hub on compact layouts.
  mobileHub,

  /// Compact rail entry on wide layouts.
  desktopRail,
}

/// A navigable page plus how the shell should present it.
class V3NavItem {
  const V3NavItem({
    required this.page,
    required this.icon,
    required this.label,
    required this.placement,
  });

  final AppPage page;
  final IconData icon;
  final String label;
  final V3NavPlacement placement;

  bool get isEnabled => isPageEnabled(page);
}

// ── Compact IA ──────────────────────────────────────────────────────────────
//
// Four stable tabs. Everything else lives in the account hub so the bottom bar
// never grows past what fits at 360dp.

const List<V3NavItem> kMobilePrimary = [
  V3NavItem(
    page: AppPage.dashboard,
    icon: Icons.radar_rounded,
    label: '连接',
    placement: V3NavPlacement.mobilePrimary,
  ),
  V3NavItem(
    page: AppPage.nodes,
    icon: Icons.hub_rounded,
    label: '节点',
    placement: V3NavPlacement.mobilePrimary,
  ),
  V3NavItem(
    page: AppPage.shop,
    icon: Icons.shopping_bag_outlined,
    label: '套餐',
    placement: V3NavPlacement.mobilePrimary,
  ),
  V3NavItem(
    page: AppPage.account,
    icon: Icons.person_outline_rounded,
    label: '账户',
    placement: V3NavPlacement.mobilePrimary,
  ),
];

/// Secondary pages listed in the account page's hub.
const List<V3NavItem> kMobileHub = [
  V3NavItem(
    page: AppPage.wallet,
    icon: Icons.account_balance_wallet_outlined,
    label: '我的钱包',
    placement: V3NavPlacement.mobileHub,
  ),
  V3NavItem(
    page: AppPage.orders,
    icon: Icons.receipt_long_outlined,
    label: '订单记录',
    placement: V3NavPlacement.mobileHub,
  ),
  V3NavItem(
    page: AppPage.traffic,
    icon: Icons.insights_rounded,
    label: '流量用量',
    placement: V3NavPlacement.mobileHub,
  ),
  V3NavItem(
    page: AppPage.invite,
    icon: Icons.auto_awesome_rounded,
    label: '邀请好友',
    placement: V3NavPlacement.mobileHub,
  ),
  V3NavItem(
    page: AppPage.tickets,
    icon: Icons.forum_outlined,
    label: '工单支持',
    placement: V3NavPlacement.mobileHub,
  ),
  V3NavItem(
    page: AppPage.settings,
    icon: Icons.tune_rounded,
    label: '客户端设置',
    placement: V3NavPlacement.mobileHub,
  ),
];

// ── Desktop IA ──────────────────────────────────────────────────────────────
//
// Settings is pinned to the rail's footer and the account card is its own entry
// point, so neither is part of this list.

const List<V3NavItem> kDesktopRail = [
  V3NavItem(
    page: AppPage.dashboard,
    icon: Icons.radar_rounded,
    label: '连接',
    placement: V3NavPlacement.desktopRail,
  ),
  V3NavItem(
    page: AppPage.nodes,
    icon: Icons.hub_rounded,
    label: '节点',
    placement: V3NavPlacement.desktopRail,
  ),
  V3NavItem(
    page: AppPage.shop,
    icon: Icons.shopping_bag_outlined,
    label: '套餐',
    placement: V3NavPlacement.desktopRail,
  ),
  V3NavItem(
    page: AppPage.traffic,
    icon: Icons.insights_rounded,
    label: '流量',
    placement: V3NavPlacement.desktopRail,
  ),
  V3NavItem(
    page: AppPage.invite,
    icon: Icons.auto_awesome_rounded,
    label: '邀请',
    placement: V3NavPlacement.desktopRail,
  ),
  V3NavItem(
    page: AppPage.tickets,
    icon: Icons.forum_outlined,
    label: '工单',
    placement: V3NavPlacement.desktopRail,
  ),
];

const V3NavItem kRailSettings = V3NavItem(
  page: AppPage.settings,
  icon: Icons.tune_rounded,
  label: '设置',
  placement: V3NavPlacement.desktopRail,
);

const V3NavItem kAccountDestination = V3NavItem(
  page: AppPage.account,
  icon: Icons.person_outline_rounded,
  label: '账户',
  placement: V3NavPlacement.mobilePrimary,
);

/// Stable handles for the navigation surfaces, so widget tests can tap a
/// specific destination instead of matching ambiguous label text (a page header
/// can share a word with the nav item that opens it).
Key railItemKey(AppPage page) => ValueKey('v3-rail-${page.name}');

Key hubRowKey(AppPage page) => ValueKey('v3-hub-${page.name}');

const Key kAccountCardKey = ValueKey('v3-rail-account-card');

/// The enabled subset of [items], in declaration order.
List<V3NavItem> enabledNavItems(List<V3NavItem> items) =>
    items.where((item) => item.isEnabled).toList();

/// Bottom-navigation index for [current], or null when the bottom bar should
/// not be rendered at all.
///
/// Pages that live in the account hub deliberately highlight 账户: they are
/// account sub-pages, and the highlight is what tells the user where they are.
int? selectedPrimaryIndex(AppPage current) {
  final primary = enabledNavItems(kMobilePrimary);
  if (primary.isEmpty) return null;
  final index = primary.indexWhere((item) => item.page == current);
  if (index >= 0) return index;
  final accountIndex = primary.indexWhere(
    (item) => item.page == AppPage.account,
  );
  return accountIndex >= 0 ? accountIndex : 0;
}
