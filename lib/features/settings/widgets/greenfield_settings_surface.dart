import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../l10n/l10n.dart';
import '../../../shared/models/app_models.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_radius.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_text_styles.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_select.dart';
import '../../../shared/widgets/app_switch.dart';

class GreenfieldSettingsSurface extends StatelessWidget {
  const GreenfieldSettingsSurface({
    super.key,
    required this.secureServer,
    required this.showDesktopStartup,
    required this.showNetworkModeToggle,
    required this.showSystemProxyTools,
    required this.autoStart,
    required this.silentStart,
    required this.autoUpdate,
    required this.themeMode,
    required this.language,
    required this.networkMode,
    required this.dnsMode,
    required this.killSwitch,
    required this.appVersion,
    required this.coreVersion,
    required this.coreLoaded,
    required this.onAutoStartChanged,
    required this.onSilentStartChanged,
    required this.onAutoUpdateChanged,
    required this.onThemeModeChanged,
    required this.onLanguageChanged,
    required this.onTunChanged,
    required this.onDnsModeChanged,
    required this.onKillSwitchChanged,
    required this.onRepairNetwork,
    required this.onShowDiagnostics,
  });

  final bool secureServer;
  final bool showDesktopStartup;
  final bool showNetworkModeToggle;
  final bool showSystemProxyTools;
  final bool autoStart;
  final bool silentStart;
  final bool autoUpdate;
  final ThemeMode themeMode;
  final AppLocalePreference language;
  final NetworkMode networkMode;
  final DnsMode dnsMode;
  final bool killSwitch;
  final String appVersion;
  final String coreVersion;
  final bool coreLoaded;
  final ValueChanged<bool> onAutoStartChanged;
  final ValueChanged<bool> onSilentStartChanged;
  final ValueChanged<bool> onAutoUpdateChanged;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final ValueChanged<AppLocalePreference> onLanguageChanged;
  final ValueChanged<bool> onTunChanged;
  final ValueChanged<DnsMode> onDnsModeChanged;
  final ValueChanged<bool> onKillSwitchChanged;
  final VoidCallback onRepairNetwork;
  final VoidCallback onShowDiagnostics;

  @override
  Widget build(BuildContext context) {
    final sections = [
      _SettingsSection(
        icon: LucideIcons.monitorCog,
        title: context.l10n.systemSettings,
        children: [
          if (showDesktopStartup)
            _SettingRow(
              label: context.l10n.launchAtStartup,
              trailing: AppSwitch(
                value: autoStart,
                onChanged: onAutoStartChanged,
              ),
            ),
          if (showDesktopStartup)
            _SettingRow(
              label: context.l10n.silentStartup,
              trailing: AppSwitch(
                value: silentStart,
                onChanged: onSilentStartChanged,
              ),
            ),
          _SettingRow(
            label: context.l10n.automaticUpdates,
            trailing: AppSwitch(
              value: autoUpdate,
              onChanged: onAutoUpdateChanged,
            ),
          ),
          _SettingRow(
            label: context.l10n.appearance,
            trailing: AppSelect<ThemeMode>(
              value: themeMode,
              items: const [ThemeMode.system, ThemeMode.light, ThemeMode.dark],
              labelOf: (value) => switch (value) {
                ThemeMode.system => context.l10n.followSystem,
                ThemeMode.light => context.l10n.lightMode,
                ThemeMode.dark => context.l10n.darkMode,
              },
              onChanged: onThemeModeChanged,
            ),
          ),
          _SettingRow(
            label: context.l10n.language,
            trailing: AppSelect<AppLocalePreference>(
              value: language,
              items: AppLocalePreference.values,
              labelOf: (value) => switch (value) {
                AppLocalePreference.system => context.l10n.followSystem,
                AppLocalePreference.simplifiedChinese =>
                  context.l10n.simplifiedChinese,
                AppLocalePreference.traditionalChinese =>
                  context.l10n.traditionalChinese,
                AppLocalePreference.english => context.l10n.english,
              },
              onChanged: onLanguageChanged,
            ),
          ),
        ],
      ),
      _SettingsSection(
        icon: LucideIcons.network,
        title: context.l10n.connectionSettings,
        children: [
          if (showNetworkModeToggle)
            _SettingRow(
              label: context.l10n.tunMode,
              trailing: AppSwitch(
                value: networkMode == NetworkMode.tun,
                onChanged: onTunChanged,
              ),
            ),
          _SettingRow(
            label: context.l10n.dns,
            trailing: AppSelect<DnsMode>(
              value: dnsMode,
              items: DnsMode.values,
              labelOf: (value) => switch (value) {
                DnsMode.system => context.l10n.systemDns,
                DnsMode.cloudflare => context.l10n.cloudflareDns,
                DnsMode.google => context.l10n.googleDns,
              },
              onChanged: onDnsModeChanged,
            ),
          ),
        ],
      ),
      _SettingsSection(
        icon: LucideIcons.shieldCheck,
        title: context.l10n.advancedSettings,
        children: [
          if (showSystemProxyTools)
            _SettingRow(
              label: context.l10n.connectionProtection,
              trailing: AppSwitch(
                value: killSwitch,
                onChanged: onKillSwitchChanged,
              ),
            ),
          if (showSystemProxyTools)
            _SettingRow(
              label: context.l10n.repairNetworkSettings,
              trailing: AppButton(
                label: context.l10n.repair,
                leadingIcon: LucideIcons.wrench,
                variant: AppButtonVariant.secondary,
                size: AppControlSize.compact,
                onPressed: onRepairNetwork,
              ),
            ),
          _SettingRow(
            label: context.l10n.diagnostics,
            trailing: AppButton(
              label: context.l10n.view,
              leadingIcon: LucideIcons.activity,
              variant: AppButtonVariant.secondary,
              size: AppControlSize.compact,
              onPressed: onShowDiagnostics,
            ),
          ),
        ],
      ),
      _SettingsSection(
        icon: LucideIcons.info,
        title: context.l10n.about,
        children: [
          _SettingRow(
            label: context.l10n.appVersion,
            trailing: _VersionText(
              value: appVersion.isEmpty ? '—' : appVersion,
            ),
          ),
          _SettingRow(
            label: context.l10n.coreVersion,
            trailing: _VersionText(
              value: coreVersion.isNotEmpty
                  ? coreVersion
                  : coreLoaded
                  ? '—'
                  : context.l10n.loading,
            ),
          ),
        ],
      ),
    ];

    return Column(
      key: const ValueKey('greenfield-settings-surface'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!secureServer) ...[
          const _HttpsWarningCard(),
          const SizedBox(height: AppSpacing.lg),
        ],
        LayoutBuilder(
          builder: (context, constraints) {
            final twoColumns = constraints.maxWidth >= 920;
            if (!twoColumns) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var index = 0; index < sections.length; index++) ...[
                    sections[index],
                    if (index != sections.length - 1)
                      const SizedBox(height: AppSpacing.lg),
                  ],
                ],
              );
            }

            const gap = AppSpacing.lg;
            final columnWidth = (constraints.maxWidth - gap) / 2;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final section in sections)
                  SizedBox(width: columnWidth, child: section),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.icon,
    required this.title,
    required this.children,
  });

  final IconData icon;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      shadow: AppCardShadow.soft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: c.primarySoft,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(icon, size: 17, color: c.primary),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  title,
                  style: AppTextStyles.sectionTitle.copyWith(
                    color: c.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          for (var index = 0; index < children.length; index++) ...[
            children[index],
            if (index != children.length - 1)
              Divider(height: 1, color: c.softBorder),
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < 380;
        if (stacked) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  label,
                  style: AppTextStyles.body.copyWith(color: c.textPrimary),
                ),
                const SizedBox(height: AppSpacing.sm),
                Align(alignment: Alignment.centerLeft, child: trailing),
              ],
            ),
          );
        }

        return ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: AppTextStyles.body.copyWith(color: c.textPrimary),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                trailing,
              ],
            ),
          ),
        );
      },
    );
  }
}

class _VersionText extends StatelessWidget {
  const _VersionText({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    return Text(
      value,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AppTextStyles.body.copyWith(color: AppColors.of(context).textMuted),
    );
  }
}

class _HttpsWarningCard extends StatelessWidget {
  const _HttpsWarningCard();

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: c.warning.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: c.warning.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(LucideIcons.triangleAlert, size: 17, color: c.warning),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              context.l10n.httpSecurityWarning,
              style: AppTextStyles.caption.copyWith(
                color: c.warning,
                height: 1.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
