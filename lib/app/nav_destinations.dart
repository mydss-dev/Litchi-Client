import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../config/app_config.dart';
import '../l10n/l10n.dart';
import 'app_controller.dart'; // AppPage

/// Where a destination lives in the compact (narrow-screen) layout.
enum CompactPlacement {
  /// Bottom-nav primary tab.
  primary,

  /// Inside the "我的" hub.
  hub,

  /// Not reachable from the bottom-nav or "我的" hub directly.
  hidden,
}

/// Compact/mobile navigation metadata.
///
/// Desktop does not derive its information architecture from [compact].
class NavDestination {
  const NavDestination({
    required this.page,
    required this.icon,
    required this.compact,
  });

  final AppPage page;
  final IconData icon;
  final CompactPlacement compact;

  bool get isEnabled => switch (page) {
    AppPage.shop => AppConfig.panelFeatures.shop,
    AppPage.invite => AppConfig.panelFeatures.invite,
    AppPage.wallet => AppConfig.panelFeatures.wallet,
    AppPage.orders => AppConfig.panelFeatures.orders,
    AppPage.traffic => AppConfig.panelFeatures.traffic,
    AppPage.tickets => AppConfig.panelFeatures.tickets,
    _ => true,
  };

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

// ── Compact/mobile IA ───────────────────────────────────────────────────────
//
// Bottom-nav and "我的" hub derive only from this list.

const List<NavDestination> kNavDestinations = [
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
  NavDestination(
    page: AppPage.nodes,
    icon: LucideIcons.server,
    compact: CompactPlacement.hidden,
  ),
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

List<NavDestination> get compactPrimaryDestinations => kNavDestinations
    .where((d) => d.compact == CompactPlacement.primary && d.isEnabled)
    .toList();

List<NavDestination> get hubDestinations => kNavDestinations
    .where((d) => d.compact == CompactPlacement.hub && d.isEnabled)
    .toList();

// ── Desktop IA ──────────────────────────────────────────────────────────────
//
// Desktop placement is explicit and completely independent from compact
// primary/hub/hidden placement. Shared feature flags remain the only common
// concern between the two layouts.

class DesktopNavDestination {
  const DesktopNavDestination({required this.page, required this.icon});

  final AppPage page;
  final IconData icon;

  bool get isEnabled => isPageEnabled(page);

  String labelFor(BuildContext context) => desktopPageLabel(context, page);

  String subtitleFor(BuildContext context) {
    final source = kNavDestinations.firstWhere((item) => item.page == page);
    return source.subtitleFor(context);
  }
}

/// High-frequency desktop destinations. The account is intentionally not here:
/// the pinned identity card is its single desktop entry point.
const List<DesktopNavDestination> desktopPrimaryDestinations = [
  DesktopNavDestination(page: AppPage.dashboard, icon: LucideIcons.home),
  DesktopNavDestination(page: AppPage.nodes, icon: LucideIcons.server),
  DesktopNavDestination(page: AppPage.shop, icon: LucideIcons.shoppingBag),
  DesktopNavDestination(page: AppPage.traffic, icon: LucideIcons.chartColumn),
  DesktopNavDestination(page: AppPage.invite, icon: LucideIcons.gift),
  DesktopNavDestination(page: AppPage.settings, icon: LucideIcons.settings),
];

/// Low-frequency account services shown once inside Account Overview.
const List<DesktopNavDestination> desktopAccountDestinations = [
  DesktopNavDestination(page: AppPage.wallet, icon: LucideIcons.wallet),
  DesktopNavDestination(page: AppPage.orders, icon: LucideIcons.clipboardList),
  DesktopNavDestination(page: AppPage.tickets, icon: LucideIcons.messageSquare),
];

bool isDesktopAccountPage(AppPage page) =>
    page == AppPage.account ||
    desktopAccountDestinations.any((item) => item.page == page);

/// Desktop Chinese labels are deliberately normalized to four characters.
String desktopPageLabel(BuildContext context, AppPage page) {
  final locale = Localizations.localeOf(context);
  final isChinese = locale.languageCode == 'zh';
  final isTraditional =
      isChinese &&
      (locale.scriptCode == 'Hant' ||
          locale.countryCode == 'TW' ||
          locale.countryCode == 'HK' ||
          locale.countryCode == 'MO');

  if (isChinese) {
    if (isTraditional) {
      return switch (page) {
        AppPage.dashboard => '首頁概覽',
        AppPage.nodes => '節點列表',
        AppPage.shop => '套餐購買',
        AppPage.traffic => '用量統計',
        AppPage.invite => '邀請好友',
        AppPage.account => '帳戶概覽',
        AppPage.wallet => '我的錢包',
        AppPage.orders => '訂單記錄',
        AppPage.tickets => '工單支援',
        AppPage.settings => '系統設定',
      };
    }
    return switch (page) {
      AppPage.dashboard => '首页概览',
      AppPage.nodes => '节点列表',
      AppPage.shop => '套餐购买',
      AppPage.traffic => '用量统计',
      AppPage.invite => '邀请好友',
      AppPage.account => '账户概览',
      AppPage.wallet => '我的钱包',
      AppPage.orders => '订单记录',
      AppPage.tickets => '工单支持',
      AppPage.settings => '系统设置',
    };
  }

  return switch (page) {
    AppPage.dashboard => 'Home Overview',
    AppPage.nodes => 'Node List',
    AppPage.shop => 'Plans',
    AppPage.traffic => 'Usage',
    AppPage.invite => 'Invite Friends',
    AppPage.account => 'Account Overview',
    AppPage.wallet => 'Wallet',
    AppPage.orders => 'Orders',
    AppPage.tickets => 'Support',
    AppPage.settings => 'Settings',
  };
}

bool isPageEnabled(AppPage page) =>
    kNavDestinations
        .where((item) => item.page == page)
        .firstOrNull
        ?.isEnabled ??
    true;

bool isPrimaryCompactTab(AppPage page) =>
    compactPrimaryDestinations.any((d) => d.page == page);

AppPage compactSelectedPrimary(AppPage current, bool inHubChild) {
  if (inHubChild) return AppPage.account;
  if (compactPrimaryDestinations.any((d) => d.page == current)) return current;
  if (hubDestinations.any((d) => d.page == current)) return AppPage.account;
  return current;
}
