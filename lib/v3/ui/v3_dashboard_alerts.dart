import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../app/core_controller.dart' show ConnectionStatus;
import '../../app/core_error_message_service.dart';
import '../theme/v3_palette.dart';
import 'v3_locale_copy.dart';

/// Persistent, actionable connection errors. This is independent of the
/// short-lived toast used by node selection.
const kV3ConnectionErrorBannerKey = Key('v3-connection-error-banner');
const kV3DataWarningBannerKey = Key('v3-data-warning-banner');

class V3DashboardAlerts extends StatelessWidget {
  const V3DashboardAlerts({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final connectionFailed =
        controller.connectionStatus == ConnectionStatus.error;
    final dataWarning = controller.dataLoadError?.trim().isNotEmpty ?? false;
    if (!connectionFailed && !dataWarning) return const SizedBox.shrink();

    final l10n = v3Localizations(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (connectionFailed)
            _DashboardAlertTile(
              key: kV3ConnectionErrorBannerKey,
              message: CoreErrorMessageService.userFacing(
                controller.coreError,
                l10n: l10n,
              ),
              warning: false,
              onRetry: controller.connectionActionLocked
                  ? null
                  : () async {
                      await controller.toggleConnection();
                    },
            ),
          if (connectionFailed && dataWarning) const SizedBox(height: 8),
          if (dataWarning)
            _DashboardAlertTile(
              key: kV3DataWarningBannerKey,
              message: controller.nodes.isNotEmpty
                  ? l10n.cachedModeActive
                  : l10n.serverUnavailableNoCache,
              warning: true,
              onRetry: () async {
                await controller.refreshData();
              },
            ),
        ],
      ),
    );
  }
}

class _DashboardAlertTile extends StatefulWidget {
  const _DashboardAlertTile({
    super.key,
    required this.message,
    required this.warning,
    required this.onRetry,
  });

  final String message;
  final bool warning;
  final Future<void> Function()? onRetry;

  @override
  State<_DashboardAlertTile> createState() => _DashboardAlertTileState();
}

class _DashboardAlertTileState extends State<_DashboardAlertTile> {
  bool _retrying = false;

  Future<void> _retry() async {
    if (_retrying || widget.onRetry == null) return;
    setState(() => _retrying = true);
    try {
      await widget.onRetry!();
    } finally {
      if (mounted) setState(() => _retrying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    final color = widget.warning ? p.warning : p.danger;
    final ink = widget.warning ? p.warningInk : p.dangerInk;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 8, 10, 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: .28)),
        ),
        child: Row(
          children: [
            Icon(
              widget.warning
                  ? Icons.warning_amber_rounded
                  : Icons.error_outline_rounded,
              size: 18,
              color: color,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Tooltip(
                message: widget.message,
                child: Text(
                  widget.message,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: ink, fontSize: 12, height: 1.4),
                ),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: _retrying || widget.onRetry == null ? null : _retry,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(58, 44),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                foregroundColor: ink,
                side: BorderSide(color: color.withValues(alpha: .4)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                v3Localizations(context).retry,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
