from pathlib import Path

# Sidebar-only desktop IA refactor. This script is temporary and is deleted
# after CI verifies the resulting product code.

shell_path = Path('lib/app/app_shell.dart')
shell = shell_path.read_text(encoding='utf-8')

import_anchor = "import '../shared/theme/app_text_styles.dart';\n"
if import_anchor not in shell:
    raise SystemExit('app_shell import anchor not found')
if "../shared/widgets/app_toast.dart" not in shell:
    shell = shell.replace(
        import_anchor,
        import_anchor + "import '../shared/widgets/app_toast.dart';\n",
        1,
    )

start = shell.find('class _DesktopSidebar extends StatelessWidget {')
end = shell.find('/// Logged-out layout: full-width controls strip + centered auth panel.')
if start < 0 or end < 0 or end <= start:
    raise SystemExit('desktop sidebar replacement markers not found')

new_sidebar = r'''class _DesktopSidebar extends StatelessWidget {
  const _DesktopSidebar({required this.ctrl});

  static const double _width = 196;
  static const List<AppPage> _mainPages = [
    AppPage.dashboard,
    AppPage.nodes,
    AppPage.shop,
    AppPage.traffic,
    AppPage.invite,
  ];
  static const List<AppPage> _accountPages = [
    AppPage.account,
    AppPage.wallet,
    AppPage.orders,
    AppPage.tickets,
  ];

  final AppController ctrl;

  NavDestination _destination(AppPage page) =>
      kNavDestinations.firstWhere((item) => item.page == page);

  List<NavDestination> _orderedEnabled(List<AppPage> pages) => [
    for (final page in pages)
      for (final destination in kNavDestinations)
        if (destination.page == page && destination.isEnabled) destination,
  ];

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final mainItems = _orderedEnabled(_mainPages);
    final accountItems = _orderedEnabled(_accountPages);
    final accountActive = _accountPages.contains(ctrl.page);
    final settings = _destination(AppPage.settings);

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
                for (final item in mainItems)
                  _SidebarItem(
                    item: item,
                    label: _desktopNavLabel(context, item.page),
                    selected: ctrl.page == item.page,
                    onTap: () => ctrl.goToPage(item.page),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 10, 8, 6),
                  child: Divider(height: 1, color: c.softBorder),
                ),
                _SidebarGroupHeader(
                  icon: LucideIcons.userRound,
                  label: _desktopAccountCenterLabel(context),
                  active: accountActive,
                ),
                const SizedBox(height: 2),
                for (final item in accountItems)
                  _SidebarItem(
                    item: item,
                    label: _desktopNavLabel(context, item.page),
                    selected: ctrl.page == item.page,
                    nested: true,
                    onTap: () => ctrl.goToPage(item.page),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
                  child: Divider(height: 1, color: c.softBorder),
                ),
                if (settings.isEnabled)
                  _SidebarItem(
                    item: settings,
                    label: _desktopNavLabel(context, settings.page),
                    selected: ctrl.page == settings.page,
                    onTap: () => ctrl.goToPage(settings.page),
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

String _desktopNavLabel(BuildContext context, AppPage page) {
  final locale = Localizations.localeOf(context);
  final isChinese = locale.languageCode == 'zh';
  final isTraditional = isChinese &&
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

  final item = kNavDestinations.firstWhere((d) => d.page == page);
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

String _desktopAccountCenterLabel(BuildContext context) {
  final locale = Localizations.localeOf(context);
  if (locale.languageCode != 'zh') return 'Account Center';
  final traditional = locale.scriptCode == 'Hant' ||
      locale.countryCode == 'TW' ||
      locale.countryCode == 'HK' ||
      locale.countryCode == 'MO';
  return traditional ? '帳戶中心' : '账户中心';
}

class _SidebarGroupHeader extends StatelessWidget {
  const _SidebarGroupHeader({
    required this.icon,
    required this.label,
    required this.active,
  });

  final IconData icon;
  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final color = active ? c.primary : c.textMuted;
    return SizedBox(
      height: 36,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 13),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodyStrong.copyWith(
                  color: color,
                  fontSize: 13.5,
                ),
              ),
            ),
            Icon(
              LucideIcons.chevronDown,
              size: 14,
              color: active ? c.primary : c.iconMuted,
            ),
          ],
        ),
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.item,
    required this.label,
    required this.selected,
    required this.onTap,
    this.nested = false,
  });

  final NavDestination item;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool nested;

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
            height: nested ? 36 : 42,
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
                      height: selected ? (nested ? 16 : 20) : 0,
                      decoration: BoxDecoration(
                        color: c.primary,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: nested ? 25 : 9),
                Icon(item.icon, size: nested ? 15 : 18, color: foreground),
                SizedBox(width: nested ? 8 : 10),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        (selected
                                ? AppTextStyles.bodyStrong
                                : AppTextStyles.body)
                            .copyWith(
                              color: foreground,
                              fontSize: nested ? 12.5 : 13.5,
                            ),
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

enum _SidebarAccountAction {
  expiryReminder,
  trafficReminder,
  autoRenewal,
  changePassword,
  logout,
}

/// Identity strip + account quick actions. It deliberately does not navigate to
/// Account Overview: the sidebar already owns that navigation entry.
class _SidebarAccountCard extends StatelessWidget {
  const _SidebarAccountCard({required this.ctrl});

  final AppController ctrl;

  Future<void> _handleAction(
    BuildContext context,
    _SidebarAccountAction action,
  ) async {
    switch (action) {
      case _SidebarAccountAction.expiryReminder:
        await _updatePreference(
          context,
          remindExpire: !ctrl.user.remindExpire,
        );
      case _SidebarAccountAction.trafficReminder:
        await _updatePreference(
          context,
          remindTraffic: !ctrl.user.remindTraffic,
        );
      case _SidebarAccountAction.autoRenewal:
        await _updatePreference(
          context,
          autoRenewal: !ctrl.user.autoRenewal,
        );
      case _SidebarAccountAction.changePassword:
        await showAccountChangePasswordModal(context);
      case _SidebarAccountAction.logout:
        final confirmed = await showAccountLogoutConfirmation(context);
        if (confirmed && context.mounted) await ctrl.logout();
    }
  }

  Future<void> _updatePreference(
    BuildContext context, {
    bool? remindExpire,
    bool? remindTraffic,
    bool? autoRenewal,
  }) async {
    final error = await ctrl.updateUserSettings(
      remindExpire: remindExpire ?? ctrl.user.remindExpire,
      remindTraffic: remindTraffic ?? ctrl.user.remindTraffic,
      autoRenewal: autoRenewal ?? ctrl.user.autoRenewal,
    );
    if (error != null && context.mounted) {
      AppToast.show(context, error, type: AppToastType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final user = ctrl.user;
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
      child: PopupMenuButton<_SidebarAccountAction>(
        tooltip: context.l10n.accountManagement,
        position: PopupMenuPosition.over,
        constraints: const BoxConstraints.tightFor(width: 220),
        onSelected: (action) => unawaited(_handleAction(context, action)),
        itemBuilder: (context) => [
          if (ctrl.hasPlan) ...[
            _preferenceMenuItem(
              context,
              value: _SidebarAccountAction.expiryReminder,
              icon: LucideIcons.calendarClock,
              label: context.l10n.expiryReminder,
              enabled: user.remindExpire,
            ),
            _preferenceMenuItem(
              context,
              value: _SidebarAccountAction.trafficReminder,
              icon: LucideIcons.gauge,
              label: context.l10n.trafficReminder,
              enabled: user.remindTraffic,
            ),
            _preferenceMenuItem(
              context,
              value: _SidebarAccountAction.autoRenewal,
              icon: LucideIcons.refreshCw,
              label: context.l10n.autoRenewal,
              enabled: user.autoRenewal,
            ),
            const PopupMenuDivider(height: 8),
          ],
          PopupMenuItem<_SidebarAccountAction>(
            value: _SidebarAccountAction.changePassword,
            height: 40,
            child: Row(
              children: [
                Icon(LucideIcons.lockKeyhole, size: 17, color: c.iconDefault),
                const SizedBox(width: 10),
                Text(context.l10n.changePasswordTitle),
              ],
            ),
          ),
          const PopupMenuDivider(height: 8),
          PopupMenuItem<_SidebarAccountAction>(
            value: _SidebarAccountAction.logout,
            height: 40,
            child: Row(
              children: [
                Icon(LucideIcons.logOut, size: 17, color: c.danger),
                const SizedBox(width: 10),
                Text(
                  context.l10n.logout,
                  style: TextStyle(color: c.danger),
                ),
              ],
            ),
          ),
        ],
        child: Material(
          color: Colors.transparent,
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 9),
            decoration: BoxDecoration(
              color: c.surfaceMuted,
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
                          color: c.textPrimary,
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
                Icon(LucideIcons.ellipsisVertical, size: 15, color: c.iconMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }

  PopupMenuItem<_SidebarAccountAction> _preferenceMenuItem(
    BuildContext context, {
    required _SidebarAccountAction value,
    required IconData icon,
    required String label,
    required bool enabled,
  }) {
    final c = AppColors.of(context);
    return PopupMenuItem<_SidebarAccountAction>(
      value: value,
      height: 40,
      child: Row(
        children: [
          Icon(icon, size: 17, color: c.iconDefault),
          const SizedBox(width: 10),
          Expanded(child: Text(label)),
          Transform.scale(
            scale: 0.72,
            child: IgnorePointer(
              child: Switch(value: enabled, onChanged: (_) {}),
            ),
          ),
        ],
      ),
    );
  }
}

'''

shell = shell[:start] + new_sidebar + shell[end:]
shell_path.write_text(shell, encoding='utf-8')

account_path = Path('lib/features/account/account_page.dart')
account = account_path.read_text(encoding='utf-8')

helper_anchor = "/// Account / Profile — the mobile profile page.\n"
if helper_anchor not in account:
    raise SystemExit('account helper anchor not found')
helpers = r'''Future<void> showAccountChangePasswordModal(BuildContext context) {
  return showAppBottomSheet<void>(
    context: context,
    builder: (_) => const _ChangePasswordSheet(),
  );
}

Future<bool> showAccountLogoutConfirmation(BuildContext context) async {
  final confirmed = await showAppBottomSheet<bool>(
    context: context,
    builder: (_) => const _LogoutSheet(),
  );
  return confirmed == true;
}

'''
if 'showAccountChangePasswordModal' not in account:
    account = account.replace(helper_anchor, helpers + helper_anchor, 1)

old_change = """  void _showChangePasswordSheet() {\n    showAppBottomSheet<void>(\n      context: context,\n      builder: (_) => const _ChangePasswordSheet(),\n    );\n  }\n"""
new_change = """  void _showChangePasswordSheet() {\n    unawaited(showAccountChangePasswordModal(context));\n  }\n"""
if old_change not in account:
    raise SystemExit('change-password handler anchor not found')
account = account.replace(old_change, new_change, 1)

old_logout = """  Future<void> _confirmLogout() async {\n    final confirmed = await showAppBottomSheet<bool>(\n      context: context,\n      builder: (_) => const _LogoutSheet(),\n    );\n    if (confirmed != true || !mounted) return;\n    await AppScope.of(context).logout();\n  }\n"""
new_logout = """  Future<void> _confirmLogout() async {\n    final confirmed = await showAccountLogoutConfirmation(context);\n    if (!confirmed || !mounted) return;\n    await AppScope.of(context).logout();\n  }\n"""
if old_logout not in account:
    raise SystemExit('logout handler anchor not found')
account = account.replace(old_logout, new_logout, 1)
account_path.write_text(account, encoding='utf-8')
