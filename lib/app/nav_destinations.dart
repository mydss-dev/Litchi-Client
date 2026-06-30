import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../l10n/l10n.dart';
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
    required this.icon,
    required this.compact,
  });

  final AppPage page;
  final IconData icon;
  final CompactPlacement compact;

  String labelFor(BuildContext context) {
    final l10n = context.l10n;
    return switch (page) {
      AppPage.dashboard => l10n.home,
      AppPage.shop => l10n.plans,
      AppPage.invite => l10n.invite,
      AppPage.account => l10n.account,
      AppPage.nodes => l10n.nodes,
      AppPage.wallet => l10n.wallet,
      AppPage.orders => l10n.orders,
      AppPage.traffic => l10n.usage,
      AppPage.tickets => l10n.support,
      AppPage.settings => l10n.settings,
    };
  }

  String subtitleFor(BuildContext context) {
    final l10n = context.l10n;
    return switch (page) {
      AppPage.wallet => l10n.walletSubtitle,
      AppPage.orders => l10n.ordersSubtitle,
      AppPage.traffic => l10n.usageSubtitle,
      AppPage.tickets => l10n.supportSubtitle,
      AppPage.settings => l10n.settingsNavSubtitle,
      _ => '',
    };
  }
}

// ── Single source of truth ───────────────────────────────────────────────────
//
// Sidebar, bottom-nav, and "我的" hub ALL derive from this list.
// Order = sidebar order.

const List<NavDestination> kNavDestinations = [
  // ── Primary (bottom nav) ──────────────────────────────────────────────────
  NavDestination(
    page: AppPage.dashboard,
    icon: LucideIcons.home,
    compact: CompactPlacement.primary,
  ),
  NavDestination(
    page: AppPage.shop,
    icon: LucideIcons.shoppingBag,
    compact: CompactPlacement.primary,
  ),
  NavDestination(
    page: AppPage.invite,
    icon: LucideIcons.gift,
    compact: CompactPlacement.primary,
  ),
  NavDestination(
    page: AppPage.account,
    icon: LucideIcons.user,
    compact: CompactPlacement.primary,
  ),

  // ── Sidebar only ──────────────────────────────────────────────────────────
  NavDestination(
    page: AppPage.nodes,
    icon: LucideIcons.server,
    compact: CompactPlacement.hidden,
  ),

  // ── "我的" hub ────────────────────────────────────────────────────────────
  NavDestination(
    page: AppPage.wallet,
    icon: LucideIcons.wallet,
    compact: CompactPlacement.hub,
  ),
  NavDestination(
    page: AppPage.orders,
    icon: LucideIcons.clipboardList,
    compact: CompactPlacement.hub,
  ),
  NavDestination(
    page: AppPage.traffic,
    icon: LucideIcons.chartColumn,
    compact: CompactPlacement.hub,
  ),
  NavDestination(
    page: AppPage.tickets,
    icon: LucideIcons.messageSquare,
    compact: CompactPlacement.hub,
  ),
  NavDestination(
    page: AppPage.settings,
    icon: LucideIcons.settings,
    compact: CompactPlacement.hub,
  ),
];

// ── Derived subsets ──────────────────────────────────────────────────────────

Iterable<NavDestination> get sidebarDestinations => kNavDestinations;

List<NavDestination> get compactPrimaryDestinations => kNavDestinations
    .where((d) => d.compact == CompactPlacement.primary)
    .toList();

List<NavDestination> get hubDestinations =>
    kNavDestinations.where((d) => d.compact == CompactPlacement.hub).toList();

/// Returns true when [page] is a primary bottom-nav tab (should show a
/// compact page header rather than a back-button row).
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
