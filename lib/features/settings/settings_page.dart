import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/app_controller.dart';
import '../../app/core_platform_support.dart';
import '../../app/nav_destinations.dart';
import '../../config/app_config.dart';
import '../../l10n/l10n.dart';
import '../../shared/models/app_models.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_radius.dart';
import '../../shared/theme/app_text_styles.dart';
import '../../shared/services/secure_logger.dart';
import '../../shared/widgets/app_bottom_sheet.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_select.dart';
import '../../shared/widgets/app_switch.dart';
import '../../shared/widgets/app_toast.dart';
import '../../shared/widgets/responsive_page_scaffold.dart';

/// Settings page (§15): General / Network / Advanced cards.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _coreVersion = '';
  bool _coreLoaded = false;

  @override
  void initState() {
    super.initState();
    AppController.getCoreVersion().then((version) {
      if (!mounted) return;
      setState(() {
        _coreVersion = version;
        _coreLoaded = true;
      });
    });
  }

  Future<void> _onFixProxy() async {
    await AppScope.of(context).fixProxy();
    if (!mounted) return;
    AppToast.show(
      context,
      context.l10n.networkSettingsRepaired,
      type: AppToastType.success,
    );
  }

  Future<void> _setNetworkMode(NetworkMode mode) async {
    final ctrl = AppScope.of(context);
    if (mode == ctrl.networkMode) return;
    if (mode == NetworkMode.tun) {
      final isAdmin = await AppController.checkAdminPrivileges();
      if (!mounted) return;
      if (!isAdmin) {
        AppToast.show(
          context,
          context.l10n.administratorRequired,
          type: AppToastType.warning,
        );
        return;
      }
    }

    final wasRunning = ctrl.coreRunning;
    ctrl.setNetworkMode(mode);
    if (wasRunning && mounted) {
      AppToast.show(context, context.l10n.switchingConnectionMethod);
    }
  }

  void _showDiagnosticInfo() {
    final ctrl = AppScope.of(context);
    final logs = ctrl.coreLogs
        .map(SecureLogRedactor.redact)
        .where((line) => line.isNotEmpty)
        .toList();
    final status = ctrl.coreConnecting
        ? context.l10n.connectionInProgress
        : ctrl.coreRunning
        ? context.l10n.connected
        : context.l10n.notConnected;
    final text = [
      '${AppConfig.appName} ${AppConfig.currentVersion}',
      context.l10n.diagnosticPlatform(Platform.operatingSystem),
      context.l10n.diagnosticConnectionStatus(status),
      context.l10n.diagnosticProxyPort(ctrl.activeProxyPort),
      context.l10n.diagnosticRecordedAt('${DateTime.now().toLocal()}'),
      if (ctrl.coreError.isNotEmpty)
        context.l10n.diagnosticRecentError(
          SecureLogRedactor.redact(ctrl.coreError),
        ),
      '',
      if (logs.isEmpty) context.l10n.noRuntimeLogs else ...logs,
    ].join('\n');

    showAppBottomSheet<void>(
      context: context,
      builder: (_) => _DiagnosticInfoSheet(text: text),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ResponsivePageScaffold(
      title: l10n.settings,
      subtitle: l10n.settingsSubtitle,
      compactTitle: l10n.settings,
      primaryCompact: isPrimaryCompactTab(AppPage.settings),
      onBack: () => AppScope.of(context).goToPage(AppPage.account),
      compactBodySpacing: 18,
      showWideBack: false,
      children: _bodyChildren(context),
    );
  }

  // ── Shared body (all settings sections) ────────────────────────────────────

  List<Widget> _bodyChildren(BuildContext context) {
    final ctrl = AppScope.of(context);
    final l10n = context.l10n;
    final supportsSystemProxy = Platform.isWindows || Platform.isMacOS;
    final networkModes = NetworkMode.values
        .where(CorePlatformSupport.supportsNetworkMode)
        .toList();

    return [
      if (!AppConfig.isSecureServer) ...[
        const _HttpsWarningCard(),
        const SizedBox(height: 12),
      ],
      _SettingsGroup(
        title: l10n.systemSettings,
        children: [
          if (Platform.isWindows || Platform.isMacOS)
            _SettingRow(
              label: l10n.launchAtStartup,
              trailing: AppSwitch(
                value: ctrl.autoStart,
                onChanged: ctrl.setAutoStart,
              ),
            ),
          if (Platform.isWindows || Platform.isMacOS)
            _SettingRow(
              label: l10n.silentStartup,
              trailing: AppSwitch(
                value: ctrl.silentStart,
                onChanged: ctrl.setSilentStart,
              ),
            ),
          _SettingRow(
            label: l10n.automaticUpdates,
            trailing: AppSwitch(
              value: ctrl.autoUpdate,
              onChanged: ctrl.setAutoUpdate,
            ),
          ),
          _SettingRow(
            label: l10n.appearance,
            trailing: AppSelect<ThemeMode>(
              value: ctrl.themeMode,
              items: const [ThemeMode.system, ThemeMode.light, ThemeMode.dark],
              labelOf: (v) => switch (v) {
                ThemeMode.system => l10n.followSystem,
                ThemeMode.light => l10n.lightMode,
                ThemeMode.dark => l10n.darkMode,
              },
              onChanged: ctrl.setThemeMode,
            ),
          ),
          _SettingRow(
            label: l10n.language,
            trailing: AppSelect<AppLocalePreference>(
              value: ctrl.language,
              items: AppLocalePreference.values,
              labelOf: (v) => switch (v) {
                AppLocalePreference.system => l10n.followSystem,
                AppLocalePreference.simplifiedChinese => l10n.simplifiedChinese,
                AppLocalePreference.traditionalChinese =>
                  l10n.traditionalChinese,
                AppLocalePreference.english => l10n.english,
              },
              onChanged: ctrl.setLanguage,
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),
      _SettingsGroup(
        title: l10n.connectionSettings,
        children: [
          if (networkModes.length > 1)
            _SettingRow(
              label: l10n.tunMode,
              trailing: AppSwitch(
                value: ctrl.networkMode == NetworkMode.tun,
                onChanged: (on) => _setNetworkMode(
                  on ? NetworkMode.tun : NetworkMode.system,
                ),
              ),
            ),
          _SettingRow(
            label: l10n.dns,
            trailing: AppSelect<DnsMode>(
              value: ctrl.dnsMode,
              items: DnsMode.values,
              labelOf: (v) => switch (v) {
                DnsMode.system => l10n.systemDns,
                DnsMode.cloudflare => l10n.cloudflareDns,
                DnsMode.google => l10n.googleDns,
              },
              onChanged: ctrl.setDnsMode,
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),
      _SettingsGroup(
        title: l10n.advancedSettings,
        children: [
          if (supportsSystemProxy)
            _SettingRow(
              label: l10n.connectionProtection,
              trailing: AppSwitch(
                value: ctrl.killSwitch,
                onChanged: ctrl.setKillSwitch,
              ),
            ),
          if (supportsSystemProxy)
            _SettingRow(
              label: l10n.repairNetworkSettings,
              trailing: _DiagnosticButton(
                label: l10n.repair,
                onTap: _onFixProxy,
              ),
            ),
          _SettingRow(
            label: l10n.diagnostics,
            trailing: _DiagnosticButton(
              label: l10n.view,
              onTap: _showDiagnosticInfo,
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),
      _SettingsGroup(
        title: l10n.about,
        children: [
          _SettingRow(
            label: l10n.appVersion,
            trailing: Text(
              AppConfig.currentVersion.isEmpty ? '—' : AppConfig.currentVersion,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.body.copyWith(
                color: AppColors.of(context).textMuted,
              ),
            ),
          ),
          _SettingRow(
            label: l10n.coreVersion,
            trailing: Text(
              _coreVersion.isNotEmpty
                  ? _coreVersion
                  : _coreLoaded
                  ? '—'
                  : l10n.loading,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.body.copyWith(
                color: AppColors.of(context).textMuted,
              ),
            ),
          ),
        ],
      ),
    ];
  }
}

class _HttpsWarningCard extends StatelessWidget {
  const _HttpsWarningCard();

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: c.warning.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: c.warning.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(LucideIcons.triangleAlert, size: 15, color: c.warning),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              context.l10n.httpSecurityWarning,
              style: AppTextStyles.caption.copyWith(
                color: c.warning,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return AppCard(
      radius: AppRadius.lg,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTextStyles.sectionTitle.copyWith(color: c.textPrimary),
          ),
          const SizedBox(height: 6),
          for (int i = 0; i < children.length; i++) ...[
            children[i],
            if (i != children.length - 1)
              Divider(color: c.softBorder, height: 1),
          ],
        ],
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({required this.label, required this.trailing});

  final String label;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return SizedBox(
      height: 46,
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: AppTextStyles.body.copyWith(color: c.textPrimary),
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}

class _DiagnosticButton extends StatelessWidget {
  const _DiagnosticButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 30,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: c.primarySoft,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(color: c.primary.withValues(alpha: 0.3)),
          ),
          child: Text(
            label,
            style: AppTextStyles.button.copyWith(
              color: c.primary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _DiagnosticInfoSheet extends StatelessWidget {
  const _DiagnosticInfoSheet({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return AppBottomSheet(
      title: context.l10n.diagnostics,
      subtitle: context.l10n.diagnosticCopyDescription,
      children: [
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 180, maxHeight: 360),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: c.surfaceMuted,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: c.softBorder),
          ),
          child: SingleChildScrollView(
            child: SelectableText(
              text,
              style: TextStyle(
                color: c.textSecondary,
                fontSize: 11,
                height: 1.5,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          height: 44,
          child: FilledButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: text));
              AppToast.show(
                context,
                context.l10n.diagnosticCopied,
                type: AppToastType.success,
              );
            },
            icon: const Icon(LucideIcons.copy, size: 17),
            label: Text(context.l10n.copyDiagnostics),
          ),
        ),
      ],
    );
  }
}
