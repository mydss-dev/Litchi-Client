#!/usr/bin/env python3
"""One-shot, guarded restoration of useful pre-V3 behaviors, excluding nodes."""
from pathlib import Path


def edit(path: str, old: str, new: str) -> None:
    file = Path(path)
    original = file.read_text(encoding='utf-8')
    occurrences = original.count(old)
    if occurrences != 1:
        raise RuntimeError(f'{path}: expected exactly one anchor, found {occurrences}: {old[:90]!r}')
    file.write_text(original.replace(old, new, 1), encoding='utf-8')
    print(f'Updated {path}')


account = 'lib/v3/pages/v3_account_page.dart'
edit(account, "import '../ui/v3_locale_copy.dart';\n", "import '../ui/v3_locale_copy.dart';\nimport '../ui/v3_logout_confirmation.dart';\n")
edit(account, "  @override\n  Widget build(BuildContext context) {\n    final controller = AppScope.of(context);\n    final p = V3Palette.of(context);\n    return SingleChildScrollView(", "  Future<void> _confirmLogout() async {\n    final confirmed = await showV3LogoutConfirmation(context);\n    if (!confirmed || !mounted) return;\n    await AppScope.read(context).logout();\n  }\n\n  @override\n  Widget build(BuildContext context) {\n    final controller = AppScope.of(context);\n    final p = V3Palette.of(context);\n    return SingleChildScrollView(")
edit(account, '          onLogout: controller.logout),', '          onLogout: _confirmLogout),')
edit(account, "    return SingleChildScrollView(\n      padding: const EdgeInsets.fromLTRB(24, 26, 24, 36),", "    return SingleChildScrollView(\n      physics: const AlwaysScrollableScrollPhysics(),\n      padding: const EdgeInsets.fromLTRB(24, 26, 24, 36),")

Path('lib/v3/ui/v3_logout_confirmation.dart').write_text('''import 'package:flutter/material.dart';

import '../theme/v3_palette.dart';
import 'v3_locale_copy.dart';

/// A destructive account action must not execute from an accidental tap.
Future<bool> showV3LogoutConfirmation(BuildContext context) async {
  final accepted = await showDialog<bool>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.48),
    builder: (dialogContext) {
      final p = V3Palette.of(dialogContext);
      return AlertDialog(
        backgroundColor: p.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Text(v3Copy(dialogContext,
          zh: '确认退出登录', en: 'Log out?', tw: '確認登出')),
        content: Text(v3Copy(dialogContext,
          zh: '退出后需要重新登录，确定继续吗？',
          en: 'You will need to sign in again. Continue?',
          tw: '登出後需要重新登入，確定繼續嗎？')),
        actions: [
          TextButton(
            key: const Key('v3-logout-cancel'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(v3Copy(dialogContext,
              zh: '取消', en: 'Cancel', tw: '取消')),
          ),
          FilledButton(
            key: const Key('v3-logout-confirm'),
            style: FilledButton.styleFrom(
              backgroundColor: p.danger,
              foregroundColor: Colors.white),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(v3Copy(dialogContext,
              zh: '退出登录', en: 'Log out', tw: '登出')),
          ),
        ],
      );
    },
  );
  return accepted == true;
}
''', encoding='utf-8')

dashboard = 'lib/v3/pages/v3_dashboard_page.dart'
edit(dashboard, "    final status = controller.connectionStatus;\n    return SingleChildScrollView(\n      padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),", "    final status = controller.connectionStatus;\n    // Only a confirmed account without a plan sees the purchase guidance.\n    final confirmedNoPlan = controller.hasAccountSummary &&\n        !controller.isInitialLoading && !controller.hasPlan;\n    return SingleChildScrollView(\n      physics: const AlwaysScrollableScrollPhysics(),\n      padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),")
edit(dashboard, '''          _ConnectionWorkspace(
            controller: controller,
            connected: status == ConnectionStatus.connected,
            connecting:
                status == ConnectionStatus.connecting ||
                status == ConnectionStatus.disconnecting,
          ),
          const SizedBox(height: 12),
          _ModeRail(controller: controller),
          const SizedBox(height: 12),
          _SessionMetrics(controller: controller),
          const SizedBox(height: 12),
          _PlanSummary(controller: controller),''', '''          if (confirmedNoPlan)
            _NoPlanDashboardPanel(controller: controller)
          else ...[
            _ConnectionWorkspace(
              controller: controller,
              connected: status == ConnectionStatus.connected,
              connecting:
                  status == ConnectionStatus.connecting ||
                  status == ConnectionStatus.disconnecting,
            ),
            const SizedBox(height: 12),
            _ModeRail(controller: controller),
            const SizedBox(height: 12),
            _SessionMetrics(controller: controller),
            const SizedBox(height: 12),
            _PlanSummary(controller: controller),
          ],''')
edit(dashboard, '/// A near-black local surface in dark mode; light mode keeps its own palette.', '''/// Purpose-built empty state without changing the connected dashboard layout.
class _NoPlanDashboardPanel extends StatelessWidget {
  const _NoPlanDashboardPanel({required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    final canBuy = isPageEnabled(AppPage.shop);
    return _DashboardCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inventory_2_outlined, size: 34, color: p.lychee),
            const SizedBox(height: 12),
            Text(v3Copy(context, zh: '当前没有可用套餐',
              en: 'No active plan', tw: '目前沒有可用方案'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(v3Copy(context,
              zh: canBuy ? '选择套餐后即可开始连接。' : '请联系服务商开通套餐。',
              en: canBuy ? 'Choose a plan to start connecting.'
                  : 'Contact your provider to activate a plan.',
              tw: canBuy ? '選擇方案後即可開始連線。' : '請聯絡服務商開通方案。'),
              textAlign: TextAlign.center,
              style: TextStyle(color: p.inkMuted, fontSize: 12)),
            if (canBuy) ...[
              const SizedBox(height: 18),
              FilledButton.icon(
                key: const Key('v3-dashboard-no-plan-buy'),
                onPressed: () => controller.goToPage(AppPage.shop),
                style: FilledButton.styleFrom(
                  backgroundColor: p.lychee, foregroundColor: Colors.white,
                  minimumSize: const Size(156, 44)),
                icon: const Icon(Icons.storefront_rounded, size: 18),
                label: Text(v3Copy(context, zh: '选择套餐',
                  en: 'Choose a plan', tw: '選擇方案')),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A near-black local surface in dark mode; light mode keeps its own palette.''')

shell = 'lib/v3/app/v3_shell.dart'
edit(shell, 'class V3Shell extends StatelessWidget {', '''/// Pull-to-refresh belongs to the four data-centric mobile pages, not nodes.
bool v3SupportsMobileRefresh(AppPage page) => switch (page) {
  AppPage.dashboard || AppPage.account || AppPage.invite || AppPage.traffic => true,
  _ => false,
};

class V3Shell extends StatelessWidget {''')
edit(shell, '''      if (compact) {
        return Scaffold(
          backgroundColor: p.canvas,
          body: page,
          bottomNavigationBar: _MobileNavigation(controller: controller),
        );
      }''', '''      if (compact) {
        final mobilePage = !_isDesktopTarget &&
                v3SupportsMobileRefresh(controller.page)
            ? RefreshIndicator(
                key: const Key('v3-mobile-refresh'),
                color: p.lychee,
                onRefresh: controller.refreshData,
                child: page,
              )
            : page;
        return Scaffold(
          backgroundColor: p.canvas,
          body: mobilePage,
          bottomNavigationBar: _MobileNavigation(controller: controller),
        );
      }''')

invite = 'lib/v3/pages/v3_invite_page.dart'
edit(invite, "      return SingleChildScrollView(\n        padding: const EdgeInsets.fromLTRB(24, 26, 24, 36),", "      return SingleChildScrollView(\n        physics: const AlwaysScrollableScrollPhysics(),\n        padding: const EdgeInsets.fromLTRB(24, 26, 24, 36),")

traffic = 'lib/v3/pages/v3_traffic_page.dart'
edit(traffic, '''      return Center(child: Container(
        constraints: const BoxConstraints(maxWidth: 520),''', '''      return LayoutBuilder(builder: (context, viewport) =>
        SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight:
              viewport.maxHeight.isFinite ? viewport.maxHeight : 0),
            child: Center(child: Container(
        constraints: const BoxConstraints(maxWidth: 520),''')
edit(traffic, '''      ));
    }

    final series = TrafficHistorySeries.build''', '''      )))));
    }

    final series = TrafficHistorySeries.build''')
edit(traffic, "      return SingleChildScrollView(\n        padding: const EdgeInsets.fromLTRB(24, 22, 24, 30),", "      return SingleChildScrollView(\n        physics: const AlwaysScrollableScrollPhysics(),\n        padding: const EdgeInsets.fromLTRB(24, 22, 24, 30),")

settings = 'lib/v3/pages/v3_settings_page.dart'
edit(settings, "import 'package:flutter/material.dart';\n", "import 'package:flutter/foundation.dart';\nimport 'package:flutter/material.dart';\n")
edit(settings, "import '../../app/app_controller.dart';\n", "import '../../app/app_controller.dart';\nimport '../../config/app_config.dart';\n")
edit(settings, '''class V3SettingsPage extends StatefulWidget {''', '''/// Startup and system-proxy tools are meaningful on Windows/macOS only.
bool v3HasDesktopSystemTools(TargetPlatform platform) =>
    platform == TargetPlatform.windows || platform == TargetPlatform.macOS;

class V3SettingsPage extends StatefulWidget {''')
edit(settings, '''  String? _message;

  Future<void> _apply''', '''  String? _message;
  late final Future<String> _coreVersionFuture = _loadCoreVersion();

  Future<String> _loadCoreVersion() async {
    try {
      return await AppController.getCoreVersion();
    } catch (_) {
      return '';
    }
  }

  Future<void> _apply''')
edit(settings, '''    final l = _copy(context);
    final currentNetwork = controller.networkMode''', '''    final l = _copy(context);
    final desktopTools = v3HasDesktopSystemTools(defaultTargetPlatform);
    final currentNetwork = controller.networkMode''')
edit(settings, '''                    _SettingRow(
                      index: '01',
                      title: l.connectionMethod,''', '''                    if (desktopTools) _SettingRow(
                      index: '01',
                      title: l.connectionMethod,''')
edit(settings, '''                    _SettingRow(
                      index: '02', title: l.dns,''', '''                    _SettingRow(
                      index: desktopTools ? '02' : '01', title: l.dns,''')
edit(settings, '''                        tw: '使用系統 DNS，或選擇其他解析服務。'),
                      fullWidthControl: true,''', '''                        tw: '使用系統 DNS，或選擇其他解析服務。'),
                      last: !desktopTools,
                      fullWidthControl: true,''')
edit(settings, '''                    _SettingRow(
                      index: '03', title: l.connectionProtection,''', '''                    if (desktopTools) _SettingRow(
                      index: '03', title: l.connectionProtection,''')
edit(settings, '''                    _SettingRow(
                      index: '04', title: l.launchAtStartup,''', '''                    if (desktopTools) _SettingRow(
                      index: '04', title: l.launchAtStartup,''')
edit(settings, '''                    _SettingRow(
                      index: '05', title: l.silentStartup,''', '''                    if (desktopTools) _SettingRow(
                      index: '05', title: l.silentStartup,''')
edit(settings, '''                    _SettingRow(
                      index: '06', title: l.automaticUpdates,''', '''                    _SettingRow(
                      index: desktopTools ? '06' : '02', title: l.automaticUpdates,''')
edit(settings, '''                      index: '07', title: l.appearance,
                      description: _hint(l,
                        zh: '选择浅色或深色界面。',
                        en: 'Choose a light or dark interface.',
                        tw: '選擇淺色或深色介面。'),''', '''                      index: desktopTools ? '07' : '03', title: l.appearance,
                      description: _hint(l,
                        zh: '跟随系统外观，或手动选择浅色和深色界面。',
                        en: 'Follow your system appearance or choose light/dark.',
                        tw: '跟隨系統外觀，或手動選擇淺色與深色介面。'),''')
edit(settings, '''                        value: controller.themeMode == ThemeMode.dark
                            ? ThemeMode.dark : ThemeMode.light,
                        items: const [ThemeMode.light, ThemeMode.dark],
                        label: (v) => v == ThemeMode.dark ? l.darkMode : l.lightMode,''', '''                        value: controller.themeMode,
                        items: const [ThemeMode.system, ThemeMode.light, ThemeMode.dark],
                        label: (v) => switch (v) {
                          ThemeMode.system => l.followSystem,
                          ThemeMode.light => l.lightMode,
                          ThemeMode.dark => l.darkMode,
                        },''')
edit(settings, '''                      index: '08', title: l.language,''', '''                      index: desktopTools ? '08' : '04', title: l.language,''')
edit(settings, '''                V3SectionLabel(l.repairNetworkSettings),''', '''                if (desktopTools) V3SectionLabel(l.repairNetworkSettings),''')
edit(settings, '''                _RecoveryPanel(
                  controller: controller,
                  label: currentNetwork,
                  title: l.repairSystemProxy,
                  action: l.repair,
                  onRepair: () => _apply(() async {
                    await controller.fixProxy();
                    return null;
                  }, l.networkSettingsRepaired),
                ),''', '''                if (desktopTools) _RecoveryPanel(
                  controller: controller,
                  label: currentNetwork,
                  title: l.repairSystemProxy,
                  action: l.repair,
                  onRepair: () => _apply(() async {
                    await controller.fixProxy();
                    return null;
                  }, l.networkSettingsRepaired),
                ),
                const SizedBox(height: 22),
                V3SectionLabel(l.about),
                const SizedBox(height: 10),
                V3Panel(
                  child: Row(children: [
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l.appVersion,
                          style: TextStyle(color: p.inkMuted, fontSize: 11)),
                        const SizedBox(height: 6),
                        Text(AppConfig.currentVersion.trim().isEmpty
                            ? '—' : AppConfig.currentVersion,
                          style: TextStyle(color: p.ink,
                            fontSize: 14, fontWeight: FontWeight.w800)),
                      ],
                    )),
                    Container(width: 1, height: 38, color: p.line),
                    const SizedBox(width: 18),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l.coreVersion,
                          style: TextStyle(color: p.inkMuted, fontSize: 11)),
                        const SizedBox(height: 6),
                        FutureBuilder<String>(
                          future: _coreVersionFuture,
                          builder: (context, snapshot) {
                            final version = snapshot.data?.trim() ?? '';
                            return Text(snapshot.connectionState !=
                                    ConnectionState.done ? l.loading
                                  : version.isEmpty ? '—' : version,
                              style: TextStyle(color: p.ink,
                                fontSize: 14, fontWeight: FontWeight.w800));
                          },
                        ),
                      ],
                    )),
                  ]),
                ),''')

# Refresh only the four chosen mobile pages; desktop retains its refresh icons.
assert not any('v3_nodes_page.dart' in path for path in [account, dashboard, shell, invite, traffic, settings])
print('Six restorations staged; nodes and node picker untouched.')
