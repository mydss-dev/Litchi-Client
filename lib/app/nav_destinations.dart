import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'app_controller.dart'; // AppPage

/// Where a destination lives in the compact (narrow-screen) layout.
enum CompactPlacement {
  /// Bottom-nav primary tab.
  primary,

  /// Inside the "我的" hub.
  hub,

  /// Sidebar only — not reachable from the compact UI directly.
  hidden,
}

class NavDestination {
  const NavDestination({
    required this.page,
    required this.label,
    required this.icon,
    required this.compact,
    this.subtitle = '',
  });

  final AppPage page;
  final String label;
  final IconData icon;
  final CompactPlacement compact;
  final String subtitle;
}

// ── Single source of truth ───────────────────────────────────────────────────
//
// Sidebar, bottom-nav, and "我的" hub ALL derive from this list.
// Order = sidebar order.

const List<NavDestination> kNavDestinations = [
  // ── Primary (bottom nav) ──────────────────────────────────────────────────
  NavDestination(
    page: AppPage.dashboard,
    label: '首页',
    icon: LucideIcons.home,
    compact: CompactPlacement.primary,
  ),
  NavDestination(
    page: AppPage.shop,
    label: '套餐',
    icon: LucideIcons.shoppingBag,
    compact: CompactPlacement.primary,
  ),
  NavDestination(
    page: AppPage.invite,
    label: '邀请',
    icon: LucideIcons.gift,
    compact: CompactPlacement.primary,
  ),
  NavDestination(
    page: AppPage.account,
    label: '我的',
    icon: LucideIcons.user,
    compact: CompactPlacement.primary,
  ),

  // ── Sidebar only ──────────────────────────────────────────────────────────
  NavDestination(
    page: AppPage.nodes,
    label: '节点',
    icon: LucideIcons.server,
    compact: CompactPlacement.hidden,
  ),

  // ── "我的" hub ────────────────────────────────────────────────────────────
  NavDestination(
    page: AppPage.orders,
    label: '订单',
    icon: LucideIcons.clipboardList,
    compact: CompactPlacement.hub,
    subtitle: '购买记录与支付状态',
  ),
  NavDestination(
    page: AppPage.traffic,
    label: '流量',
    icon: LucideIcons.chartColumn,
    compact: CompactPlacement.hub,
    subtitle: '用量统计',
  ),
  NavDestination(
    page: AppPage.wallet,
    label: '钱包',
    icon: LucideIcons.wallet,
    compact: CompactPlacement.hub,
    subtitle: '余额与充值',
  ),
  NavDestination(
    page: AppPage.tickets,
    label: '工单',
    icon: LucideIcons.messageSquare,
    compact: CompactPlacement.hub,
    subtitle: '联系客服',
  ),
  NavDestination(
    page: AppPage.settings,
    label: '设置',
    icon: LucideIcons.settings,
    compact: CompactPlacement.hub,
    subtitle: '应用偏好',
  ),
];

// ── Derived subsets ──────────────────────────────────────────────────────────

Iterable<NavDestination> get sidebarDestinations =>
    kNavDestinations;

List<NavDestination> get compactPrimaryDestinations =>
    kNavDestinations
        .where((d) => d.compact == CompactPlacement.primary)
        .toList();

List<NavDestination> get hubDestinations =>
    kNavDestinations
        .where((d) => d.compact == CompactPlacement.hub)
        .toList();

/// Returns true when [page] is a primary bottom-nav tab (should show a
/// [MobilePageHeader] in compact layout rather than a back-button row).
bool isPrimaryCompactTab(AppPage page) =>
    compactPrimaryDestinations.any((d) => d.page == page);

/// Returns which bottom-nav tab should be highlighted for [current].
/// Hub sub-pages highlight "我的".
AppPage compactSelectedPrimary(AppPage current, bool inHubChild) {
  if (inHubChild) return AppPage.account;
  if (compactPrimaryDestinations.any((d) => d.page == current)) return current;
  if (hubDestinations.any((d) => d.page == current)) return AppPage.account;
  return current;
}
