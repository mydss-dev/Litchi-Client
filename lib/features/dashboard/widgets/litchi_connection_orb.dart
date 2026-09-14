import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/core_controller.dart' show ConnectionStatus;
import '../../../l10n/l10n.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_motion.dart';
import '../../../shared/theme/app_shadows.dart';

/// Branded connection control used by the desktop dashboard.
///
/// It owns presentation and motion only. Core/tunnel state and the actual
/// connection action remain in the caller so this widget cannot change network
/// behavior on its own.
class LitchiConnectionOrb extends StatefulWidget {
  const LitchiConnectionOrb({
    super.key,
    required this.status,
    required this.onPressed,
    this.enabled = true,
    this.size = 136,
  });

  final ConnectionStatus status;
  final VoidCallback onPressed;
  final bool enabled;
  final double size;

  @override
  State<LitchiConnectionOrb> createState() => _LitchiConnectionOrbState();
}

class _LitchiConnectionOrbState extends State<LitchiConnectionOrb>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breath;

  bool get _busy =>
      widget.status == ConnectionStatus.connecting ||
      widget.status == ConnectionStatus.disconnecting;

  @override
  void initState() {
    super.initState();
    _breath = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant LitchiConnectionOrb oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncAnimation();
  }

  void _syncAnimation() {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (_busy && !reduceMotion) {
      if (!_breath.isAnimating) _breath.repeat(reverse: true);
      return;
    }
    if (_breath.isAnimating) _breath.stop();
    _breath.value = 0;
  }

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final connected = widget.status == ConnectionStatus.connected;
    final failed = widget.status == ConnectionStatus.error;
    final accent = failed ? c.danger : c.primary;
    final coreSize = widget.size * 0.72;

    return Semantics(
      button: true,
      enabled: widget.enabled,
      child: Tooltip(
        message: connected
            ? context.l10n.disconnectConnection
            : context.l10n.connectNow,
        child: AnimatedBuilder(
          animation: _breath,
          builder: (context, _) {
            final pulse = _busy ? _breath.value : 0.0;
            return SizedBox.square(
              dimension: widget.size,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  AnimatedContainer(
                    duration: AppMotion.normal,
                    curve: AppMotion.enter,
                    width: widget.size * (0.98 + pulse * 0.02),
                    height: widget.size * (0.98 + pulse * 0.02),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: accent.withValues(
                          alpha: connected ? 0.26 : 0.14 + pulse * 0.12,
                        ),
                      ),
                    ),
                  ),
                  AnimatedContainer(
                    duration: AppMotion.normal,
                    curve: AppMotion.enter,
                    width: widget.size * 0.84,
                    height: widget.size * 0.84,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: accent.withValues(
                          alpha: connected ? 0.38 : 0.20 + pulse * 0.14,
                        ),
                      ),
                    ),
                  ),
                  Material(
                    color: Colors.transparent,
                    shape: const CircleBorder(),
                    child: InkWell(
                      onTap: widget.enabled ? widget.onPressed : null,
                      mouseCursor: widget.enabled
                          ? SystemMouseCursors.click
                          : SystemMouseCursors.basic,
                      customBorder: const CircleBorder(),
                      child: AnimatedContainer(
                        duration: AppMotion.normal,
                        curve: AppMotion.enter,
                        width: coreSize,
                        height: coreSize,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: connected ? null : c.surfaceMuted,
                          gradient: connected ? c.brandGradient : null,
                          border: Border.all(
                            color: connected
                                ? Colors.white.withValues(alpha: 0.34)
                                : failed
                                ? c.danger.withValues(alpha: 0.52)
                                : c.border,
                          ),
                          boxShadow: connected
                              ? AppShadows.powerButton
                              : null,
                        ),
                        child: Center(
                          child: _busy
                              ? SizedBox.square(
                                  dimension: 28,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.4,
                                    color: accent,
                                  ),
                                )
                              : Icon(
                                  failed
                                      ? LucideIcons.rotateCw
                                      : LucideIcons.power,
                                  color: connected ? Colors.white : accent,
                                  size: 34,
                                ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
