import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../l10n/generated/app_localizations_zh.dart';

/// Where a destination is surfaced in the v3 shell.
///
/// Desktop and compact placement are declared independently: the desktop rail
/// is a wide-screen information architecture, not a scaled-up bottom nav.
enum V3NavPlacement {
  /// Compact bottom-navigation tab.
  mobilePrimary,

  /// Reached from the account page's "我的服务" hub on compact layouts.
  mobileHub,

  /// Reached from the compact "更多" tab, for the pages that are neither an
  /// account concern nor common enough to hold a tab.
  mobileMore,

  /// Compact rail entry on wide layouts.
  desktopRail,
}

/// A navigable page plus how the shell should present it.
class V3NavItem {
  const V3NavItem({
    required this.page,
    required this.icon,
    required this.placement,
  });

  final AppPage page;
  final IconData icon;
  final V3NavPlacement placement;

  bool get isEnabled => isPageEnabled(page);

  /// Short labels belong in navigation, not in page headings. Keep the
  /// surrounding localized copy and full page titles unchanged.
  String localizedLabel(BuildContext context) {
    final l = Localizations.of<AppLocalizations>(
      context, AppLocalizations,
    ) ?? AppLocalizationsZh();
    if (l.localeName.startsWith('zh')) {
      return switch (page) {
        AppPage.dashboard => '连接',
        AppPage.nodes => '节点',
        AppPage.shop => '套餐',
        AppPage.account => '账户',
        AppPage.more => '更多',
        AppPage.traffic => '流量',
        AppPage.invite => '邀请',
        AppPage.tickets => '工单',
        AppPage.settings => '设置',
        AppPage.orders => '订单',
        AppPage.giftCard => '兑换',
      };
    }
    return switch (page) {
      AppPage.dashboard => l.connection,
      AppPage.nodes => l.nodes,
      AppPage.shop => l.plans,
      AppPage.account => l.account,
      AppPage.more => l.more,
      AppPage.traffic => l.trafficUsage,
      AppPage.invite => l.inviteFriends,
      AppPage.tickets => l.support,
      AppPage.settings => l.clientSettings,
      AppPage.orders => l.orders,
      AppPage.giftCard => l.giftCardRedemption,
    };
  }
}

// ── Compact IA ──────────────────────────────────────────────────────────────
//
// Five tabs. 更多 is the overflow, so the bottom bar never grows past what fits
// at 360dp.

const List<V3NavItem> kMobilePrimary = [
  V3NavItem(
    page: AppPage.dashboard,
    icon: Icons.radar_rounded,
    placement: V3NavPlacement.mobilePrimary,
  ),
  V3NavItem(
    page: AppPage.nodes,
    icon: Icons.hub_rounded,
    placement: V3NavPlacement.mobilePrimary,
  ),
  V3NavItem(
    page: AppPage.shop,
    icon: Icons.shopping_bag_outlined,
    placement: V3NavPlacement.mobilePrimary,
  ),
  V3NavItem(
    page: AppPage.account,
    icon: Icons.person_outline_rounded,
    placement: V3NavPlacement.mobilePrimary,
  ),
  V3NavItem(
    page: AppPage.more,
    icon: Icons.more_horiz_rounded,
    placement: V3NavPlacement.mobilePrimary,
  ),
];

/// Account business, listed in the account page's hub.
///
/// This list is the answer to "what belongs to my account": money spent and
/// money redeemed. Money *held* is not a destination any more — the account
/// page shows the balance in its own wallet panel, so a 我的钱包 row would only
/// lead to a second place that says the same number.
const List<V3NavItem> kMobileHub = [
  V3NavItem(
    page: AppPage.orders,
    icon: Icons.receipt_long_outlined,
    placement: V3NavPlacement.mobileHub,
  ),
  V3NavItem(
    page: AppPage.giftCard,
    icon: Icons.card_giftcard_rounded,
    placement: V3NavPlacement.mobileHub,
  ),
];

/// The 更多 tab's list: everything compact has no tab or hub row for, in the
/// order the desktop rail presents its equivalents.
const List<V3NavItem> kMobileMore = [
  V3NavItem(
    page: AppPage.traffic,
    icon: Icons.insights_rounded,
    placement: V3NavPlacement.mobileMore,
  ),
  V3NavItem(
    page: AppPage.invite,
    icon: Icons.auto_awesome_rounded,
    placement: V3NavPlacement.mobileMore,
  ),
  V3NavItem(
    page: AppPage.tickets,
    icon: Icons.forum_outlined,
    placement: V3NavPlacement.mobileMore,
  ),
  V3NavItem(
    page: AppPage.settings,
    icon: Icons.tune_rounded,
    placement: V3NavPlacement.mobileMore,
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
    placement: V3NavPlacement.desktopRail,
  ),
  V3NavItem(
    page: AppPage.nodes,
    icon: Icons.hub_rounded,
    placement: V3NavPlacement.desktopRail,
  ),
  V3NavItem(
    page: AppPage.shop,
    icon: Icons.shopping_bag_outlined,
    placement: V3NavPlacement.desktopRail,
  ),
  V3NavItem(
    page: AppPage.traffic,
    icon: Icons.insights_rounded,
    placement: V3NavPlacement.desktopRail,
  ),
  V3NavItem(
    page: AppPage.invite,
    icon: Icons.auto_awesome_rounded,
    placement: V3NavPlacement.desktopRail,
  ),
  V3NavItem(
    page: AppPage.tickets,
    icon: Icons.forum_outlined,
    placement: V3NavPlacement.desktopRail,
  ),
];

const V3NavItem kRailSettings = V3NavItem(
  page: AppPage.settings,
  icon: Icons.tune_rounded,
  placement: V3NavPlacement.desktopRail,
);

const V3NavItem kAccountDestination = V3NavItem(
  page: AppPage.account,
  icon: Icons.person_outline_rounded,
  placement: V3NavPlacement.mobilePrimary,
);

/// Stable handles for the navigation surfaces, so widget tests can tap a
/// specific destination instead of matching ambiguous label text (a page header
/// can share a word with the nav item that opens it).
Key railItemKey(AppPage page) => ValueKey('v3-rail-${page.name}');

Key hubRowKey(AppPage page) => ValueKey('v3-hub-${page.name}');

Key moreRowKey(AppPage page) => ValueKey('v3-more-${page.name}');

const Key kAccountCardKey = ValueKey('v3-rail-account-card');

/// The enabled subset of [items], in declaration order.
List<V3NavItem> enabledNavItems(List<V3NavItem> items) =>
    items.where((item) => item.isEnabled).toList();

/// Bottom-navigation index for [current], or null when the bottom bar should
/// not be rendered at all.
///
/// A page with no tab of its own highlights the tab that leads to it — 账户 for
/// the hub rows, 更多 for the overflow — which is what tells the user which
/// corner of the app they are standing in.
int? selectedPrimaryIndex(AppPage current) {
  final primary = enabledNavItems(kMobilePrimary);
  if (primary.isEmpty) return null;
  int? indexOf(AppPage page) {
    final index = primary.indexWhere((item) => item.page == page);
    return index >= 0 ? index : null;
  }

  final own = indexOf(current);
  if (own != null) return own;
  final viaHub = kMobileHub.any((item) => item.page == current);
  final viaMore = kMobileMore.any((item) => item.page == current);
  return (viaMore ? indexOf(AppPage.more) : null) ??
      (viaHub ? indexOf(AppPage.account) : null) ??
      indexOf(AppPage.account) ??
      0;
}
