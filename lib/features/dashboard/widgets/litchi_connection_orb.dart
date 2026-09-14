import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/core_controller.dart' show ConnectionStatus;
import '../../../l10n/l10n.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_motion.dart';
import '../../../shared/theme/app_shadows.dart';

/// Brand interaction for a connection state. It deliberately has no knowledge
/// of the core: callers retain ownership of whether a tap may toggle a tunnel.
class LitchiConnectionOrb extends StatefulWidget {
  const LitchiConnectionOrb({
    super.key,
    required this.status,
    required this.onPressed,
    this.enabled = true,
    this.size = 76,
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
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant LitchiConnectionOrb oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncAnimation(reduceMotion: MediaQuery.disableAnimationsOf(context));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAnimation(reduceMotion: MediaQuery.disableAnimationsOf(context));
  }

  void _syncAnimation({bool reduceMotion = false}) {
    if (_busy && !reduceMotion && !_breath.isAnimating) {
      _breath.repeat(reverse: true);
    } else if ((!_busy || reduceMotion) && _breath.isAnimating) {
      _breath
        ..stop()
        ..value = 0;
    }
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
    final iconColor = connected ? Colors.white : accent;

    return Semantics(
      button: true,
      enabled: widget.enabled,
      child: Tooltip(
        message: connected
            ? context.l10n.disconnectConnection
            : context.l10n.connectNow,
        child: AnimatedBuilder(
          animation: _breath,
          builder: (context, child) => Transform.scale(
            scale: 1 + (_busy ? _breath.value * 0.035 : 0),
            child: child,
          ),
          child: Material(
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
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: connected ? null : c.surfaceMuted,
                  gradient: connected ? c.brandGradient : null,
                  border: Border.all(
                    color: connected
                        ? Colors.white.withValues(alpha: 0.34)
                        : failed
                        ? c.danger.withValues(alpha: 0.5)
                        : c.border,
                  ),
                  boxShadow: connected ? AppShadows.powerButton : null,
                ),
                child: Center(
                  child: _busy
                      ? SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: accent,
                          ),
                        )
                      : Icon(
                          failed ? LucideIcons.rotateCw : LucideIcons.power,
                          color: iconColor,
                          size: 28,
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
