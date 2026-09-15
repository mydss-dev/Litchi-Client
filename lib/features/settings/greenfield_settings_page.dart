import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../app/core_platform_support.dart';
import '../../app/nav_destinations.dart';
import '../../config/app_config.dart';
import '../../l10n/l10n.dart';
import '../../shared/models/app_models.dart';
import '../../shared/services/secure_logger.dart';
import '../../shared/widgets/app_modal.dart';
import '../../shared/widgets/app_toast.dart';
import '../../shared/widgets/responsive_page_scaffold.dart';
import 'widgets/greenfield_diagnostic_modal.dart';
import 'widgets/greenfield_settings_surface.dart';

class GreenfieldSettingsPage extends StatefulWidget {
  const GreenfieldSettingsPage({super.key});

  @override
  State<GreenfieldSettingsPage> createState() => _GreenfieldSettingsPageState();
}

class _GreenfieldSettingsPageState extends State<GreenfieldSettingsPage> {
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

  Future<void> _fixProxy() async {
    await AppScope.of(context).fixProxy();
    if (!mounted) return;
    AppToast.show(
      context,
      context.l10n.networkSettingsRepaired,
      type: AppToastType.success,
    );
  }

  Future<void> _setNetworkMode(NetworkMode mode) async {
    final controller = AppScope.of(context);
    if (mode == controller.networkMode) return;

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

    final wasRunning = controller.coreRunning;
    controller.setNetworkMode(mode);
    if (wasRunning && mounted) {
      AppToast.show(context, context.l10n.switchingConnectionMethod);
    }
  }

  void _showDiagnostics() {
    final controller = AppScope.of(context);
    final logs = controller.coreLogs
        .map(SecureLogRedactor.redact)
        .where((line) => line.isNotEmpty)
        .toList();
    final status = controller.coreConnecting
        ? context.l10n.connectionInProgress
        : controller.coreRunning
        ? context.l10n.connected
        : context.l10n.notConnected;
    final text = [
      '${AppConfig.appName} ${AppConfig.currentVersion}',
      context.l10n.diagnosticPlatform(Platform.operatingSystem),
      context.l10n.diagnosticConnectionStatus(status),
      context.l10n.diagnosticProxyPort(controller.activeProxyPort),
      context.l10n.diagnosticRecordedAt('${DateTime.now().toLocal()}'),
      if (controller.coreError.isNotEmpty)
        context.l10n.diagnosticRecentError(
          SecureLogRedactor.redact(controller.coreError),
        ),
      '',
      if (logs.isEmpty) context.l10n.noRuntimeLogs else ...logs,
    ].join('\n');

    showAppAdaptiveModal<void>(
      context: context,
      builder: (_) => GreenfieldDiagnosticModal(text: text),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final desktopStartup = Platform.isWindows || Platform.isMacOS;
    final systemProxyTools = Platform.isWindows || Platform.isMacOS;
    final networkModes = NetworkMode.values
        .where(CorePlatformSupport.supportsNetworkMode)
        .toList();

    return ResponsivePageScaffold(
      title: context.l10n.settings,
      subtitle: context.l10n.settingsSubtitle,
      compactTitle: context.l10n.settings,
      primaryCompact: isPrimaryCompactTab(AppPage.settings),
      onBack: () => controller.goToPage(AppPage.account),
      children: [
        GreenfieldSettingsSurface(
          secureServer: AppConfig.isSecureServer,
          showDesktopStartup: desktopStartup,
          showNetworkModeToggle: networkModes.length > 1,
          showSystemProxyTools: systemProxyTools,
          autoStart: controller.autoStart,
          silentStart: controller.silentStart,
          autoUpdate: controller.autoUpdate,
          themeMode: controller.themeMode,
          language: controller.language,
          networkMode: controller.networkMode,
          dnsMode: controller.dnsMode,
          killSwitch: controller.killSwitch,
          appVersion: AppConfig.currentVersion,
          coreVersion: _coreVersion,
          coreLoaded: _coreLoaded,
          onAutoStartChanged: controller.setAutoStart,
          onSilentStartChanged: controller.setSilentStart,
          onAutoUpdateChanged: controller.setAutoUpdate,
          onThemeModeChanged: controller.setThemeMode,
          onLanguageChanged: controller.setLanguage,
          onTunChanged: (enabled) {
            unawaited(
              _setNetworkMode(
                enabled ? NetworkMode.tun : NetworkMode.system,
              ),
            );
          },
          onDnsModeChanged: controller.setDnsMode,
          onKillSwitchChanged: controller.setKillSwitch,
          onRepairNetwork: () => unawaited(_fixProxy()),
          onShowDiagnostics: _showDiagnostics,
        ),
      ],
    );
  }
}
