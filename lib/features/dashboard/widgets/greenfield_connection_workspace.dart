import 'package:country_flags/country_flags.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/app_controller.dart';
import '../../../app/core_controller.dart' show ConnectionStatus;
import '../../../l10n/l10n.dart';
import '../../../shared/models/app_models.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_radius.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_text_styles.dart';
import '../../../shared/utils/formatters.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/mode_strip.dart';
import '../../../shared/widgets/node_latency.dart';
import 'litchi_connection_orb.dart';
import 'network_settings_card.dart';

class GreenfieldConnectionWorkspace extends StatelessWidget {
  const GreenfieldConnectionWorkspace({
    super.key,
    required this.ctrl,
    required this.tick,
    required this.compact,
    required this.onToggleConnection,
    required this.onProxyModeChanged,
    required this.onNodeTap,
  });

  final AppController ctrl;
  final ValueListenable<int> tick;
  final bool compact;
  final VoidCallback onToggleConnection;
  final ValueChanged<ProxyMode> onProxyModeChanged;
  final VoidCallback onNodeTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final status = ctrl.connectionStatus;
    final busy =
        status == ConnectionStatus.connecting ||
        status == ConnectionStatus.disconnecting;
    final supported = ctrl.supportsCoreConnection;
    final copy = _copyFor(context, c, status, supported);

    return AppCard(
      height: compact ? null : 248,
      padding: EdgeInsets.all(compact ? AppSpacing.lg : AppSpacing.xl),
      child: compact
          ? _CompactWorkspace(
              ctrl: ctrl,
              tick: tick,
              statusText: copy.status,
              actionText: copy.action,
              statusColor: copy.color,
              busy: busy,
              supported: supported,
              onToggleConnection: onToggleConnection,
              onProxyModeChanged: onProxyModeChanged,
              onNodeTap: onNodeTap,
            )
          : _DesktopWorkspace(
              ctrl: ctrl,
              tick: tick,
              statusText: copy.status,
              actionText: copy.action,
              statusColor: copy.color,
              busy: busy,
              supported: supported,
              onToggleConnection: onToggleConnection,
              onProxyModeChanged: onProxyModeChanged,
              onNodeTap: onNodeTap,
            ),
    );
  }
}

class _DesktopWorkspace extends StatelessWidget {
  const _DesktopWorkspace({
    required this.ctrl,
    required this.tick,
    required this.statusText,
    required this.actionText,
    required this.statusColor,
    required this.busy,
    required this.supported,
    required this.onToggleConnection,
    required this.onProxyModeChanged,
    required this.onNodeTap,
  });

  final AppController ctrl;
  final ValueListenable<int> tick;
  final String statusText;
  final String actionText;
  final Color statusColor;
  final bool busy;
  final bool supported;
  final VoidCallback onToggleConnection;
  final ValueChanged<ProxyMode> onProxyModeChanged;
  final VoidCallback onNodeTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final connected = ctrl.connectionStatus == ConnectionStatus.connected;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 150,
          child: Center(
            child: LitchiConnectionOrb(
              status: ctrl.connectionStatus,
              enabled: !busy && supported,
              onPressed: onToggleConnection,
              size: 136,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.lg),
        Container(width: 1, color: c.softBorder),
        const SizedBox(width: AppSpacing.lg),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _StatusLine(label: statusText, color: statusColor, busy: busy),
              const SizedBox(height: AppSpacing.sm),
              Text(
                actionText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.pageTitle.copyWith(color: c.textPrimary),
              ),
              const SizedBox(height: AppSpacing.xs),
              ValueListenableBuilder<int>(
                valueListenable: tick,
                builder: (context, _, _) => Text(
                  connected
                      ? formatDuration(ctrl.connectedDuration)
                      : _connectionDescription(context, ctrl.networkMode),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body.copyWith(color: c.textSecondary),
                ),
              ),
              const Spacer(),
              _NodeSelector(
                node: ctrl.currentNode,
                loading: ctrl.isInitialLoading && ctrl.nodes.isEmpty,
                automatic: ctrl.autoSelected,
                onTap: onNodeTap,
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.lg),
        SizedBox(
          width: 204,
          child: _RouteControls(
            ctrl: ctrl,
            compact: false,
            onProxyModeChanged: onProxyModeChanged,
          ),
        ),
      ],
    );
  }
}

class _CompactWorkspace extends StatelessWidget {
  const _CompactWorkspace({
    required this.ctrl,
    required this.tick,
    required this.statusText,
    required this.actionText,
    required this.statusColor,
    required this.busy,
    required this.supported,
    required this.onToggleConnection,
    required this.onProxyModeChanged,
    required this.onNodeTap,
  });

  final AppController ctrl;
  final ValueListenable<int> tick;
  final String statusText;
  final String actionText;
  final Color statusColor;
  final bool busy;
  final bool supported;
  final VoidCallback onToggleConnection;
  final ValueChanged<ProxyMode> onProxyModeChanged;
  final VoidCallback onNodeTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final connected = ctrl.connectionStatus == ConnectionStatus.connected;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: _StatusLine(label: statusText, color: statusColor, busy: busy),
        ),
        const SizedBox(height: AppSpacing.lg),
        Center(
          child: LitchiConnectionOrb(
            status: ctrl.connectionStatus,
            enabled: !busy && supported,
            onPressed: onToggleConnection,
            size: 136,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          actionText,
          textAlign: TextAlign.center,
          style: AppTextStyles.pageTitle.copyWith(color: c.textPrimary),
        ),
        const SizedBox(height: AppSpacing.xs),
        ValueListenableBuilder<int>(
          valueListenable: tick,
          builder: (context, _, _) => Text(
            connected
                ? formatDuration(ctrl.connectedDuration)
                : _connectionDescription(context, ctrl.networkMode),
            textAlign: TextAlign.center,
            style: AppTextStyles.caption.copyWith(color: c.textSecondary),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        _NodeSelector(
          node: ctrl.currentNode,
          loading: ctrl.isInitialLoading && ctrl.nodes.isEmpty,
          automatic: ctrl.autoSelected,
          onTap: onNodeTap,
        ),
        const SizedBox(height: AppSpacing.lg),
        Divider(height: 1, thickness: 1, color: c.softBorder),
        const SizedBox(height: AppSpacing.lg),
        _RouteControls(
          ctrl: ctrl,
          compact: true,
          onProxyModeChanged: onProxyModeChanged,
        ),
      ],
    );
  }
}

class _RouteControls extends StatelessWidget {
  const _RouteControls({
    required this.ctrl,
    required this.compact,
    required this.onProxyModeChanged,
  });

  final AppController ctrl;
  final bool compact;
  final ValueChanged<ProxyMode> onProxyModeChanged;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: c.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: c.softBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(LucideIcons.route, size: 16, color: c.primary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  context.l10n.networkSettings,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyStrong.copyWith(color: c.textPrimary),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            context.l10n.connectionMethod,
            style: AppTextStyles.metricLabel.copyWith(color: c.textSecondary),
          ),
          const SizedBox(height: AppSpacing.sm),
          const NetworkModeSelector(height: 40),
          const SizedBox(height: AppSpacing.md),
          Text(
            context.l10n.proxyMode,
            style: AppTextStyles.metricLabel.copyWith(color: c.textSecondary),
          ),
          const SizedBox(height: AppSpacing.sm),
          ModeStrip(
            selected: ctrl.proxyMode,
            onChanged: onProxyModeChanged,
            buttonHeight: compact ? 44 : 36,
            padding: AppSpacing.xs,
          ),
        ],
      ),
    );
  }
}

class _NodeSelector extends StatelessWidget {
  const _NodeSelector({
    required this.node,
    required this.loading,
    required this.automatic,
    required this.onTap,
  });

  final NodeModel node;
  final bool loading;
  final bool automatic;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final name = node.name.isEmpty
        ? loading
              ? context.l10n.syncingNodes
              : context.l10n.selectNodePrompt
        : node.name;
    final secondary = node.englishName.isNotEmpty
        ? node.englishName
        : context.l10n.nodeModeLabel(
            automatic ? context.l10n.autoSelect : context.l10n.manualSelect,
          );

    return Material(
      color: c.surfaceMuted,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        onTap: onTap,
        mouseCursor: SystemMouseCursors.click,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          constraints: const BoxConstraints(minHeight: 58),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: c.softBorder),
          ),
          child: Row(
            children: [
              _NodeAvatar(node: node),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodyStrong.copyWith(color: c.textPrimary),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      secondary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption.copyWith(color: c.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              if (!loading || node.name.isNotEmpty)
                NodeLatency(latency: node.latency, style: NodeLatencyStyle.badge),
              const SizedBox(width: AppSpacing.sm),
              Icon(LucideIcons.chevronRight, size: 17, color: c.primary),
            ],
          ),
        ),
      ),
    );
  }
}

class _NodeAvatar extends StatelessWidget {
  const _NodeAvatar({required this.node});

  final NodeModel node;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      width: 38,
      height: 38,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: c.cardBg,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: c.softBorder),
      ),
      child: node.code.isNotEmpty
          ? CountryFlag.fromCountryCode(
              node.code,
              theme: const ImageTheme(
                width: 25,
                height: 18,
                shape: RoundedRectangle(3),
              ),
            )
          : Icon(LucideIcons.globe2, size: 18, color: c.iconMuted),
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({
    required this.label,
    required this.color,
    required this.busy,
  });

  final String label;
  final Color color;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (busy)
          SizedBox.square(
            dimension: 10,
            child: CircularProgressIndicator(strokeWidth: 1.5, color: color),
          )
        else
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        const SizedBox(width: AppSpacing.sm),
        Text(label, style: AppTextStyles.bodyStrong.copyWith(color: color)),
      ],
    );
  }
}

({String status, String action, Color color}) _copyFor(
  BuildContext context,
  AppColors c,
  ConnectionStatus status,
  bool supported,
) {
  if (!supported) {
    return (
      status: context.l10n.businessEdition,
      action: context.l10n.unavailable,
      color: c.textMuted,
    );
  }

  return switch (status) {
    ConnectionStatus.connected => (
        status: context.l10n.protected,
        action: context.l10n.disconnectConnection,
        color: c.primary,
      ),
    ConnectionStatus.connecting => (
        status: context.l10n.connecting,
        action: context.l10n.connecting,
        color: c.primary,
      ),
    ConnectionStatus.disconnecting => (
        status: context.l10n.disconnecting,
        action: context.l10n.disconnecting,
        color: c.textMuted,
      ),
    ConnectionStatus.error => (
        status: context.l10n.connectionFailed,
        action: context.l10n.reconnect,
        color: c.danger,
      ),
    ConnectionStatus.disconnected => (
        status: context.l10n.notConnected,
        action: context.l10n.startConnection,
        color: c.textMuted,
      ),
  };
}

String _connectionDescription(BuildContext context, NetworkMode mode) {
  return mode == NetworkMode.tun
      ? context.l10n.tunDescription
      : context.l10n.systemProxyDescription;
}
