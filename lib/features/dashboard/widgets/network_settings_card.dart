import 'package:flutter/material.dart';

import '../../../app/app_controller.dart';
import '../../../app/core_platform_support.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/models/app_models.dart';
import '../../../shared/services/windows_tun_conflict_detector.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_radius.dart';
import '../../../shared/theme/app_shadows.dart';
import '../../../shared/theme/app_text_styles.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_modal.dart';
import '../../../shared/widgets/app_toast.dart';

/// Settings-page wrapper around the reusable [NetworkModeSelector].
class NetworkSettingsCard extends StatelessWidget {
  const NetworkSettingsCard({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final ctrl = AppScope.of(context);
    final mode = ctrl.networkMode;

    return AppCard(
      radius: AppRadius.card,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.networkSettings,
            style: AppTextStyles.sectionTitle.copyWith(
              color: c.textPrimary,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            mode == NetworkMode.system
                ? context.l10n.systemProxyDescription
                : context.l10n.tunDescription,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.body.copyWith(color: c.textMuted),
          ),
          const SizedBox(height: 16),
          const NetworkModeSelector(),
        ],
      ),
    );
  }
}

/// Reusable segmented selector for system-proxy / TUN connection methods.
///
/// The permission check stays here so the dashboard and settings page share
/// exactly the same behavior instead of duplicating TUN privilege logic.
/// Visually this follows [ModeStrip]: primary-soft selected fill, restrained
/// primary border, primary selected text and muted unselected text.
class NetworkModeSelector extends StatefulWidget {
  const NetworkModeSelector({super.key, this.height = 38});

  final double height;

  @override
  State<NetworkModeSelector> createState() => _NetworkModeSelectorState();
}

class _NetworkModeSelectorState extends State<NetworkModeSelector> {
  bool _checkingAdmin = false;

  Future<void> _setMode(NetworkMode mode) async {
    if (!CorePlatformSupport.supportsNetworkMode(mode)) return;
    final ctrl = AppScope.of(context);
    if (ctrl.networkMode == mode) return;

    if (mode == NetworkMode.tun) {
      setState(() => _checkingAdmin = true);
      final isAdmin = await AppController.checkAdminPrivileges();
      if (!mounted) return;

      if (!isAdmin) {
        setState(() => _checkingAdmin = false);
        await showAppAdaptiveModal<void>(
          context: context,
          builder: (ctx) {
            final c = AppColors.of(ctx);
            return AppAdaptiveModal(
              title: context.l10n.administratorRequired,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.tunAdminHintWindows,
                    style: AppTextStyles.body.copyWith(
                      color: c.textSecondary,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      style: TextButton.styleFrom(
                        foregroundColor: c.primary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                      ),
                      child: Text(
                        context.l10n.gotIt,
                        style: AppTextStyles.button.copyWith(
                          color: c.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
        return;
      }

      final conflict = await WindowsTunConflictDetector.findActiveConflict();
      if (!mounted) return;
      setState(() => _checkingAdmin = false);
      if (conflict != null) {
        AppToast.show(
          context,
          WindowsTunConflictDetector.messageFor(conflict),
          type: AppToastType.error,
        );
        return;
      }
    }

    ctrl.setNetworkMode(mode);
    if (ctrl.coreRunning && mounted) {
      AppToast.show(context, context.l10n.networkModeReconnect);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final ctrl = AppScope.of(context);
    final mode = ctrl.networkMode;
    final supportsSystem = CorePlatformSupport.supportsNetworkMode(
      NetworkMode.system,
    );
    final supportsTun = CorePlatformSupport.supportsNetworkMode(
      NetworkMode.tun,
    );

    return Container(
      height: widget.height,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: c.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: c.softBorder),
      ),
      child: Row(
        children: [
          if (supportsSystem)
            Expanded(
              child: _NetworkModeOption(
                label: context.l10n.systemProxy,
                selected: mode == NetworkMode.system,
                loading: false,
                onTap: () => _setMode(NetworkMode.system),
              ),
            ),
          if (supportsTun)
            Expanded(
              child: _NetworkModeOption(
                label: context.l10n.tunMode,
                selected: mode == NetworkMode.tun,
                loading: _checkingAdmin,
                onTap: () => _setMode(NetworkMode.tun),
              ),
            ),
        ],
      ),
    );
  }
}

class _NetworkModeOption extends StatelessWidget {
  const _NetworkModeOption({
    required this.label,
    required this.selected,
    required this.loading,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return MouseRegion(
      cursor: loading ? SystemMouseCursors.basic : SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: loading ? null : onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? c.primarySoft : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: selected
                ? Border.all(color: c.primary.withValues(alpha: 0.22))
                : null,
            boxShadow: selected ? AppShadows.soft(c) : null,
          ),
          child: loading
              ? SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: c.primary,
                  ),
                )
              : Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.button.copyWith(
                    color: selected ? c.primary : c.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
      ),
    );
  }
}
