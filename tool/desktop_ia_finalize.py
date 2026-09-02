from pathlib import Path

# Final desktop IA refactor. Compact/mobile navigation stays unchanged.

nav_path = Path('lib/app/nav_destinations.dart')
nav_path.write_text(r'''import 'package:flutter/widgets.dart';
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
''', encoding='utf-8')

# ── Desktop shell/sidebar ────────────────────────────────────────────────────
shell_path = Path('lib/app/app_shell.dart')
shell = shell_path.read_text(encoding='utf-8')
shell = shell.replace("import '../shared/widgets/app_toast.dart';\n", '')
start = shell.find('class _DesktopSidebar extends StatelessWidget {')
end = shell.find('/// Logged-out layout: full-width controls strip + centered auth panel.')
if start < 0 or end < 0 or end <= start:
    raise SystemExit('desktop sidebar markers not found')

sidebar = r'''class _DesktopSidebar extends StatelessWidget {
  const _DesktopSidebar({required this.ctrl});

  static const double _width = 196;

  final AppController ctrl;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final items = desktopPrimaryDestinations
        .where((item) => item.isEnabled)
        .toList(growable: false);

    return Container(
      width: _width,
      decoration: BoxDecoration(
        color: c.cardBg,
        border: Border(right: BorderSide(color: c.softBorder)),
      ),
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
              children: [
                for (final item in items)
                  _DesktopSidebarItem(
                    item: item,
                    selected: ctrl.page == item.page,
                    onTap: () => ctrl.goToPage(item.page),
                  ),
              ],
            ),
          ),
          Divider(height: 1, color: c.softBorder),
          _SidebarAccountCard(ctrl: ctrl),
        ],
      ),
    );
  }
}

class _DesktopSidebarItem extends StatelessWidget {
  const _DesktopSidebarItem({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final DesktopNavDestination item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final foreground = selected ? c.primary : c.textMuted;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          mouseCursor: SystemMouseCursors.click,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Ink(
            height: 42,
            decoration: BoxDecoration(
              color: selected ? c.primarySoft : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 4,
                  child: Center(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 140),
                      width: 3,
                      height: selected ? 20 : 0,
                      decoration: BoxDecoration(
                        color: c.primary,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 9),
                Icon(item.icon, size: 18, color: foreground),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item.labelFor(context),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        (selected
                                ? AppTextStyles.bodyStrong
                                : AppTextStyles.body)
                            .copyWith(color: foreground, fontSize: 13.5),
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The pinned account card is the single desktop entry point for account and
/// account-service pages. Account actions live inside Account Overview itself.
class _SidebarAccountCard extends StatelessWidget {
  const _SidebarAccountCard({required this.ctrl});

  final AppController ctrl;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final user = ctrl.user;
    final selected = isDesktopAccountPage(ctrl.page);
    final file = BrandAssetCache.avatarFile;
    final letter = user.avatarLetter.isEmpty ? 'L' : user.avatarLetter;

    final Widget avatar;
    if (BrandAssetCache.avatarUrl.isEmpty || file == null) {
      avatar = CircleAvatar(
        radius: 16,
        backgroundColor: c.primarySoft,
        child: Text(
          letter,
          style: AppTextStyles.bodyStrong.copyWith(
            color: c.primary,
            fontSize: 12,
          ),
        ),
      );
    } else {
      avatar = ClipOval(
        child: Image.file(
          file,
          width: 32,
          height: 32,
          fit: BoxFit.cover,
          gaplessPlayback: true,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => ctrl.goToPage(AppPage.account),
          mouseCursor: SystemMouseCursors.click,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 9),
            decoration: BoxDecoration(
              color: selected ? c.primarySoft : c.surfaceMuted,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Row(
              children: [
                avatar,
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.name.isEmpty ? '--' : user.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodyStrong.copyWith(
                          color: selected ? c.primary : c.textPrimary,
                          fontSize: 12.5,
                        ),
                      ),
                      if (user.plan.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          user.plan,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.caption.copyWith(
                            color: c.textMuted,
                            fontSize: 10.5,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  LucideIcons.chevronRight,
                  size: 14,
                  color: selected ? c.primary : c.iconMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

'''
shell = shell[:start] + sidebar + shell[end:]
shell_path.write_text(shell, encoding='utf-8')

# ── Desktop account page ─────────────────────────────────────────────────────
account_path = Path('lib/features/account/account_page.dart')
account = account_path.read_text(encoding='utf-8')

start = account.find('  Widget _buildDesktop(BuildContext context) {')
end = account.find('  // ── Compact (bottom-nav) layout')
if start < 0 or end < 0 or end <= start:
    raise SystemExit('desktop account build markers not found')

desktop_build = r'''  Widget _buildDesktop(BuildContext context) {
    final c = AppColors.of(context);
    final ctrl = AppScope.of(context);
    final user = ctrl.user;
    final canRenew = isPageEnabled(AppPage.shop) && ctrl.hasPlan;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    desktopPageLabel(context, AppPage.account),
                    style: AppTextStyles.pageTitle.copyWith(
                      color: c.textPrimary,
                      fontSize: 26,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    context.l10n.myAccountSubtitle,
                    style: AppTextStyles.body.copyWith(color: c.textMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Tooltip(
              message: context.l10n.refresh,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _handlePullRefresh,
                  mouseCursor: SystemMouseCursors.click,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: Ink(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: c.surfaceMuted,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: c.softBorder),
                    ),
                    child: Icon(
                      LucideIcons.refreshCw,
                      size: 17,
                      color: c.iconDefault,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _ProfileHeader(
          userName: user.name,
          plan: user.plan,
          expiry: user.expiry,
          avatar: user.avatarLetter,
          hidePlan: false,
          hideExpiry: false,
          onRenew: canRenew ? _renewCurrentPlan : null,
        ),
        const SizedBox(height: 14),
        if (!ctrl.hasPlan)
          NoPlanCard(
            onPurchase: isPageEnabled(AppPage.shop)
                ? () => ctrl.goToPage(AppPage.shop)
                : null,
          )
        else
          _DesktopAccountMetrics(ctrl: ctrl),
        const SizedBox(height: 16),
        _DesktopAccountServices(ctrl: ctrl),
        const SizedBox(height: 16),
        _DesktopAccountSettings(
          hasPlan: ctrl.hasPlan,
          remindExpire: user.remindExpire,
          remindTraffic: user.remindTraffic,
          autoRenewal: user.autoRenewal,
          onExpireChanged: (value) => _updateSettings(remindExpire: value),
          onTrafficChanged: (value) => _updateSettings(remindTraffic: value),
          onAutoRenewalChanged: (value) => _updateSettings(autoRenewal: value),
          onChangePassword: _showChangePasswordSheet,
          onLogout: _confirmLogout,
        ),
      ],
    );
  }

'''
account = account[:start] + desktop_build + account[end:]

# Replace the desktop quick-tile hub with a true account services/settings list.
start = account.find('class _DesktopProfileMenuSection extends StatelessWidget {')
end = account.find('// ── Compact-layout widgets + helpers')
if start < 0 or end < 0 or end <= start:
    raise SystemExit('desktop account menu markers not found')

account_sections = r'''class _DesktopAccountServices extends StatelessWidget {
  const _DesktopAccountServices({required this.ctrl});

  final AppController ctrl;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final items = desktopAccountDestinations
        .where((item) => item.isEnabled)
        .toList(growable: false);
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _desktopAccountServicesLabel(context),
          style: AppTextStyles.bodyStrong.copyWith(color: c.textPrimary),
        ),
        const SizedBox(height: 8),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          shadow: AppCardShadow.soft,
          child: Column(
            children: [
              for (var index = 0; index < items.length; index++) ...[
                _ActionRow(
                  icon: items[index].icon,
                  title: items[index].labelFor(context),
                  subtitle: items[index].subtitleFor(context),
                  onTap: () => ctrl.goToPage(items[index].page),
                ),
                if (index != items.length - 1) _Divider(color: c.softBorder),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _DesktopAccountSettings extends StatelessWidget {
  const _DesktopAccountSettings({
    required this.hasPlan,
    required this.remindExpire,
    required this.remindTraffic,
    required this.autoRenewal,
    required this.onExpireChanged,
    required this.onTrafficChanged,
    required this.onAutoRenewalChanged,
    required this.onChangePassword,
    required this.onLogout,
  });

  final bool hasPlan;
  final bool remindExpire;
  final bool remindTraffic;
  final bool autoRenewal;
  final ValueChanged<bool> onExpireChanged;
  final ValueChanged<bool> onTrafficChanged;
  final ValueChanged<bool> onAutoRenewalChanged;
  final VoidCallback onChangePassword;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _desktopAccountSettingsLabel(context),
          style: AppTextStyles.bodyStrong.copyWith(color: c.textPrimary),
        ),
        const SizedBox(height: 8),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          shadow: AppCardShadow.soft,
          child: Column(
            children: [
              if (hasPlan) ...[
                _SwitchRow(
                  icon: LucideIcons.calendarClock,
                  title: context.l10n.expiryReminder,
                  subtitle: context.l10n.expiryReminderSubtitle,
                  value: remindExpire,
                  onChanged: onExpireChanged,
                ),
                _Divider(color: c.softBorder),
                _SwitchRow(
                  icon: LucideIcons.gauge,
                  title: context.l10n.trafficReminder,
                  subtitle: context.l10n.trafficReminderSubtitle,
                  value: remindTraffic,
                  onChanged: onTrafficChanged,
                ),
                _Divider(color: c.softBorder),
                _SwitchRow(
                  icon: LucideIcons.refreshCw,
                  title: context.l10n.autoRenewal,
                  subtitle: context.l10n.autoRenewalSubtitle,
                  value: autoRenewal,
                  onChanged: onAutoRenewalChanged,
                ),
                _Divider(color: c.softBorder),
              ],
              _ActionRow(
                icon: LucideIcons.lockKeyhole,
                title: context.l10n.changePasswordTitle,
                subtitle: context.l10n.updateLoginPassword,
                onTap: onChangePassword,
              ),
              _Divider(color: c.softBorder),
              _ActionRow(
                icon: LucideIcons.logOut,
                title: context.l10n.logout,
                subtitle: context.l10n.logoutCurrentAccount,
                danger: true,
                onTap: onLogout,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

String _desktopAccountServicesLabel(BuildContext context) {
  final locale = Localizations.localeOf(context);
  if (locale.languageCode != 'zh') return 'Account services';
  final traditional =
      locale.scriptCode == 'Hant' ||
      locale.countryCode == 'TW' ||
      locale.countryCode == 'HK' ||
      locale.countryCode == 'MO';
  return traditional ? '帳戶服務' : '账户服务';
}

String _desktopAccountSettingsLabel(BuildContext context) {
  final locale = Localizations.localeOf(context);
  if (locale.languageCode != 'zh') return 'Account settings';
  final traditional =
      locale.scriptCode == 'Hant' ||
      locale.countryCode == 'TW' ||
      locale.countryCode == 'HK' ||
      locale.countryCode == 'MO';
  return traditional ? '帳戶設定' : '账户设置';
}

'''
account = account[:start] + account_sections + account[end:]

# Make Manage mobile-only by allowing Desktop to omit it.
account = account.replace(
    '    this.onRenew,\n    required this.onManage,\n',
    '    this.onRenew,\n    this.onManage,\n',
    1,
)
account = account.replace(
    '  final VoidCallback? onRenew;\n  final VoidCallback onManage;\n',
    '  final VoidCallback? onRenew;\n  final VoidCallback? onManage;\n',
    1,
)
old_actions = r'''          const SizedBox(width: 10),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (onRenew != null) ...[
                _ProfileActionButton(
                  icon: LucideIcons.shoppingCart,
                  label: context.l10n.renewPlan,
                  onTap: onRenew!,
                  filled: true,
                ),
                const SizedBox(width: 6),
              ],
              _ProfileActionButton(
                icon: LucideIcons.slidersHorizontal,
                label: context.l10n.manage,
                onTap: onManage,
              ),
            ],
          ),
'''
new_actions = r'''          if (onRenew != null || onManage != null) ...[
            const SizedBox(width: 10),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (onRenew != null) ...[
                  _ProfileActionButton(
                    icon: LucideIcons.shoppingCart,
                    label: context.l10n.renewPlan,
                    onTap: onRenew!,
                    filled: true,
                  ),
                  if (onManage != null) const SizedBox(width: 6),
                ],
                if (onManage != null)
                  _ProfileActionButton(
                    icon: LucideIcons.slidersHorizontal,
                    label: context.l10n.manage,
                    onTap: onManage!,
                  ),
              ],
            ),
          ],
'''
if old_actions not in account:
    raise SystemExit('profile header action block not found')
account = account.replace(old_actions, new_actions, 1)

account_path.write_text(account, encoding='utf-8')
