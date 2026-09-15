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
    final system = _SystemPreferences(
      showDesktopStartup: showDesktopStartup,
      autoStart: autoStart,
      silentStart: silentStart,
      autoUpdate: autoUpdate,
      themeMode: themeMode,
      language: language,
      onAutoStartChanged: onAutoStartChanged,
      onSilentStartChanged: onSilentStartChanged,
      onAutoUpdateChanged: onAutoUpdateChanged,
      onThemeModeChanged: onThemeModeChanged,
      onLanguageChanged: onLanguageChanged,
    );
    final network = _NetworkControl(
      showNetworkModeToggle: showNetworkModeToggle,
      networkMode: networkMode,
      dnsMode: dnsMode,
      onTunChanged: onTunChanged,
      onDnsModeChanged: onDnsModeChanged,
    );
    final advanced = _ProtectionAndDiagnostics(
      showSystemProxyTools: showSystemProxyTools,
      killSwitch: killSwitch,
      onKillSwitchChanged: onKillSwitchChanged,
      onRepairNetwork: onRepairNetwork,
      onShowDiagnostics: onShowDiagnostics,
    );
    final about = _AboutStrip(
      appVersion: appVersion,
      coreVersion: coreVersion,
      coreLoaded: coreLoaded,
    );

    return Column(
      key: const ValueKey('greenfield-settings-surface'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!secureServer) ...[
          const _HttpsWarningCard(),
          const SizedBox(height: AppSpacing.xl),
        ],
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 920) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  system,
                  const SizedBox(height: AppSpacing.xl),
                  network,
                  const SizedBox(height: AppSpacing.xl),
                  advanced,
                  const SizedBox(height: AppSpacing.xl),
                  about,
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      system,
                      const SizedBox(height: AppSpacing.xl),
                      network,
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.xl),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      advanced,
                      const SizedBox(height: AppSpacing.xl),
                      about,
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _SystemPreferences extends StatelessWidget {
  const _SystemPreferences({
    required this.showDesktopStartup,
    required this.autoStart,
    required this.silentStart,
    required this.autoUpdate,
    required this.themeMode,
    required this.language,
    required this.onAutoStartChanged,
    required this.onSilentStartChanged,
    required this.onAutoUpdateChanged,
    required this.onThemeModeChanged,
    required this.onLanguageChanged,
  });

  final bool showDesktopStartup;
  final bool autoStart;
  final bool silentStart;
  final bool autoUpdate;
  final ThemeMode themeMode;
  final AppLocalePreference language;
  final ValueChanged<bool> onAutoStartChanged;
  final ValueChanged<bool> onSilentStartChanged;
  final ValueChanged<bool> onAutoUpdateChanged;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final ValueChanged<AppLocalePreference> onLanguageChanged;

  @override
  Widget build(BuildContext context) {
    return _FlatSection(
      icon: LucideIcons.slidersHorizontal,
      title: context.l10n.systemSettings,
      children: [
        if (showDesktopStartup)
          _ControlRow(
            icon: LucideIcons.power,
            label: context.l10n.launchAtStartup,
            trailing: AppSwitch(value: autoStart, onChanged: onAutoStartChanged),
          ),
        if (showDesktopStartup)
          _ControlRow(
            icon: LucideIcons.moonStar,
            label: context.l10n.silentStartup,
            trailing: AppSwitch(value: silentStart, onChanged: onSilentStartChanged),
          ),
        _ControlRow(
          icon: LucideIcons.refreshCw,
          label: context.l10n.automaticUpdates,
          trailing: AppSwitch(value: autoUpdate, onChanged: onAutoUpdateChanged),
        ),
        _ControlRow(
          icon: LucideIcons.palette,
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
        _ControlRow(
          icon: LucideIcons.languages,
          label: context.l10n.language,
          trailing: AppSelect<AppLocalePreference>(
            value: language,
            items: AppLocalePreference.values,
            labelOf: (value) => switch (value) {
              AppLocalePreference.system => context.l10n.followSystem,
              AppLocalePreference.simplifiedChinese => context.l10n.simplifiedChinese,
              AppLocalePreference.traditionalChinese => context.l10n.traditionalChinese,
              AppLocalePreference.english => context.l10n.english,
            },
            onChanged: onLanguageChanged,
          ),
        ),
      ],
    );
  }
}

class _NetworkControl extends StatelessWidget {
  const _NetworkControl({
    required this.showNetworkModeToggle,
    required this.networkMode,
    required this.dnsMode,
    required this.onTunChanged,
    required this.onDnsModeChanged,
  });

  final bool showNetworkModeToggle;
  final NetworkMode networkMode;
  final DnsMode dnsMode;
  final ValueChanged<bool> onTunChanged;
  final ValueChanged<DnsMode> onDnsModeChanged;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final rows = <Widget>[
      if (showNetworkModeToggle)
        _ControlRow(
          icon: LucideIcons.route,
          label: context.l10n.tunMode,
          trailing: AppSwitch(
            value: networkMode == NetworkMode.tun,
            onChanged: onTunChanged,
          ),
        ),
      _ControlRow(
        icon: LucideIcons.serverCog,
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
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeading(
          icon: LucideIcons.network,
          title: context.l10n.connectionSettings,
        ),
        const SizedBox(height: AppSpacing.md),
        AppCard(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          color: c.cardBg,
          borderColor: c.softBorder,
          shadow: AppCardShadow.soft,
          child: Column(
            children: [
              for (var index = 0; index < rows.length; index++) ...[
                rows[index],
                if (index != rows.length - 1)
                  Divider(height: 1, color: c.softBorder),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ProtectionAndDiagnostics extends StatelessWidget {
  const _ProtectionAndDiagnostics({
    required this.showSystemProxyTools,
    required this.killSwitch,
    required this.onKillSwitchChanged,
    required this.onRepairNetwork,
    required this.onShowDiagnostics,
  });

  final bool showSystemProxyTools;
  final bool killSwitch;
  final ValueChanged<bool> onKillSwitchChanged;
  final VoidCallback onRepairNetwork;
  final VoidCallback onShowDiagnostics;

  @override
  Widget build(BuildContext context) {
    return _FlatSection(
      icon: LucideIcons.shieldCheck,
      title: context.l10n.advancedSettings,
      children: [
        if (showSystemProxyTools)
          _ControlRow(
            icon: LucideIcons.shield,
            label: context.l10n.connectionProtection,
            trailing: AppSwitch(value: killSwitch, onChanged: onKillSwitchChanged),
          ),
        if (showSystemProxyTools)
          _ControlRow(
            icon: LucideIcons.wrench,
            label: context.l10n.repairNetworkSettings,
            trailing: AppButton(
              label: context.l10n.repair,
              leadingIcon: LucideIcons.wrench,
              variant: AppButtonVariant.secondary,
              size: AppControlSize.compact,
              onPressed: onRepairNetwork,
            ),
          ),
        _ControlRow(
          icon: LucideIcons.activity,
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
    );
  }
}

class _AboutStrip extends StatelessWidget {
  const _AboutStrip({
    required this.appVersion,
    required this.coreVersion,
    required this.coreLoaded,
  });

  final String appVersion;
  final String coreVersion;
  final bool coreLoaded;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final coreValue = coreVersion.isNotEmpty
        ? coreVersion
        : coreLoaded
        ? '—'
        : context.l10n.loading;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeading(icon: LucideIcons.info, title: context.l10n.about),
        const SizedBox(height: AppSpacing.md),
        Container(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: c.softBorder),
              bottom: BorderSide(color: c.softBorder),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: _VersionMetric(
                  label: context.l10n.appVersion,
                  value: appVersion.isEmpty ? '—' : appVersion,
                ),
              ),
              Container(width: 1, height: 34, color: c.softBorder),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: AppSpacing.lg),
                  child: _VersionMetric(
                    label: context.l10n.coreVersion,
                    value: coreValue,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FlatSection extends StatelessWidget {
  const _FlatSection({
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeading(icon: icon, title: title),
        const SizedBox(height: AppSpacing.sm),
        for (var index = 0; index < children.length; index++) ...[
          children[index],
          if (index != children.length - 1)
            Divider(height: 1, color: c.softBorder),
        ],
      ],
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: c.primarySoft,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Icon(icon, size: 16, color: c.primary),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            title,
            style: AppTextStyles.sectionTitle.copyWith(color: c.textPrimary),
          ),
        ),
      ],
    );
  }
}

class _ControlRow extends StatelessWidget {
  const _ControlRow({
    required this.icon,
    required this.label,
    required this.trailing,
  });

  final IconData icon;
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
                Row(
                  children: [
                    Icon(icon, size: 16, color: c.iconMuted),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        label,
                        style: AppTextStyles.body.copyWith(color: c.textPrimary),
                      ),
                    ),
                  ],
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
                Icon(icon, size: 16, color: c.iconMuted),
                const SizedBox(width: AppSpacing.sm),
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

class _VersionMetric extends StatelessWidget {
  const _VersionMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTextStyles.caption.copyWith(color: c.textMuted)),
          const SizedBox(height: AppSpacing.xs),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodyStrong.copyWith(color: c.textPrimary),
          ),
        ],
      ),
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
