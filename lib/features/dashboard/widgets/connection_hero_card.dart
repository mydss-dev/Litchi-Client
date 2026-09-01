import 'dart:math' as math;

import 'package:country_flags/country_flags.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/app_controller.dart';
import '../../../app/core_controller.dart' show ConnectionStatus;
import '../../../l10n/l10n.dart';
import '../../../shared/models/app_models.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_palette.dart';
import '../../../shared/theme/app_radius.dart';
import '../../../shared/theme/app_shadows.dart';
import '../../../shared/theme/app_text_styles.dart';
import '../../../shared/widgets/app_card.dart';
import '../../nodes/node_picker.dart';

class ConnectionHeroCard extends StatelessWidget {
  const ConnectionHeroCard({
    super.key,
    required this.status,
    required this.elapsedLabel,
    required this.onToggle,
  });

  final ConnectionStatus status;
  final String elapsedLabel;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final ctrl = AppScope.of(context);
    final node = ctrl.currentNode;
    final hasNode = node.name.isNotEmpty;
    final isLoading = ctrl.isInitialLoading;

    return AppCard(
      radius: AppRadius.xl,
      height: 228,
      padding: const EdgeInsets.fromLTRB(22, 22, 20, 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        hasNode
                            ? context.l10n.currentNode
                            : (isLoading
                                  ? context.l10n.nodeLoading
                                  : context.l10n.nodeStatus),
                        style: AppTextStyles.heroTitle.copyWith(
                          color: c.textPrimary,
                          fontSize: 21,
                        ),
                      ),
                    ),
                    _NodeInlineAction(
                      hasNodes: ctrl.nodes.isNotEmpty,
                      onTap: () => showNodePicker(context),
                    ),
                  ],
                ),
                const Spacer(),
                _SecurityBadge(status: status),
                const SizedBox(height: 16),
                if (isLoading && !hasNode)
                  Row(
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: c.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        context.l10n.fetchingNodes,
                        style: AppTextStyles.heroTitle.copyWith(
                          color: c.textMuted,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  )
                else
                  Row(
                    children: [
                      _HeroNodeIcon(node: node),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          hasNode ? node.name : context.l10n.noAvailableNodes,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.heroTitle.copyWith(
                            color: c.textPrimary,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 10),
                if (!hasNode)
                  Text(
                    isLoading
                        ? context.l10n.syncingSubscription
                        : context.l10n.subscriptionLoadsAfterLogin,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(color: c.textMuted),
                  )
                else
                  _NodeMetaRow(node: node, automatic: ctrl.autoSelected),
                const Spacer(),
              ],
            ),
          ),
          Container(
            width: 1,
            margin: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
            color: c.softBorder,
          ),
          Expanded(
            child: Column(
              children: [
                const Spacer(),
                _PowerButton(
                  status: status,
                  locked: ctrl.connectionActionLocked,
                  onTap: onToggle,
                ),
                const SizedBox(height: 12),
                _ConnectionActionText(status: status),
                if (status == ConnectionStatus.connected) ...[
                  const SizedBox(height: 6),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: Text(
                      elapsedLabel,
                      key: ValueKey(elapsedLabel),
                      style: AppTextStyles.caption.copyWith(color: c.textMuted),
                    ),
                  ),
                ],
                const Spacer(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroNodeIcon extends StatelessWidget {
  const _HeroNodeIcon({required this.node});

  final NodeModel node;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    if (node.code.isNotEmpty) {
      return CountryFlag.fromCountryCode(
        node.code,
        theme: const ImageTheme(
          width: 36,
          height: 26,
          shape: RoundedRectangle(4),
        ),
      );
    }
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: c.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Icon(LucideIcons.globe2, size: 19, color: c.primary),
    );
  }
}

class _SecurityBadge extends StatelessWidget {
  const _SecurityBadge({required this.status});

  final ConnectionStatus status;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final (icon, text, color) = switch (status) {
      ConnectionStatus.connected => (
        LucideIcons.shieldCheck,
        context.l10n.encryptionProtectionEnabled,
        c.success,
      ),
      ConnectionStatus.connecting => (
        LucideIcons.shield,
        context.l10n.establishingEncryptedChannel,
        c.primary,
      ),
      ConnectionStatus.disconnecting => (
        LucideIcons.shield,
        context.l10n.closingEncryptedChannel,
        c.textMuted,
      ),
      _ => (
        LucideIcons.shieldOff,
        context.l10n.networkNotProtected,
        c.textMuted,
      ),
    };
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: Row(
        key: ValueKey(text),
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Text(
            text,
            style: AppTextStyles.caption.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _NodeMetaRow extends StatelessWidget {
  const _NodeMetaRow({required this.node, required this.automatic});

  final NodeModel node;
  final bool automatic;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Text(
      context.l10n.nodeMode(
        automatic ? context.l10n.autoSelect : context.l10n.manualSelect,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AppTextStyles.body.copyWith(
        color: c.textMuted,
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

class _NodeInlineAction extends StatelessWidget {
  const _NodeInlineAction({required this.hasNodes, required this.onTap});

  final bool hasNodes;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          height: 30,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: c.primarySoft,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.chevronsUpDown, size: 14, color: c.primary),
              const SizedBox(width: 6),
              Text(
                hasNodes ? context.l10n.switchNode : context.l10n.viewNodes,
                style: AppTextStyles.button.copyWith(
                  color: c.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PowerButton extends StatefulWidget {
  const _PowerButton({
    required this.status,
    required this.locked,
    required this.onTap,
  });

  final ConnectionStatus status;
  final bool locked;
  final VoidCallback onTap;

  @override
  State<_PowerButton> createState() => _PowerButtonState();
}

class _PowerButtonState extends State<_PowerButton>
    with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final AnimationController _chargeController;
  late final AnimationController _successController;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1150),
    );
    _chargeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _successController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 720),
    );
    _syncPulse();
    _syncCharge();
  }

  @override
  void didUpdateWidget(covariant _PowerButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncPulse();
    _syncCharge();
    // Fire the success burst once when we land on "connected".
    if (_isConnected && oldWidget.status != ConnectionStatus.connected) {
      _successController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _chargeController.dispose();
    _successController.dispose();
    super.dispose();
  }

  void _syncPulse() {
    final shouldPulse = _shouldPulse;
    if (shouldPulse && !_pulseController.isAnimating) {
      _pulseController.repeat();
    } else if (!shouldPulse && _pulseController.isAnimating) {
      _pulseController.stop();
      _pulseController.value = 0;
    }
  }

  void _syncCharge() {
    if (_isConnecting && !_chargeController.isAnimating) {
      _chargeController.repeat();
    } else if (!_isConnecting && _chargeController.isAnimating) {
      _chargeController.stop();
      _chargeController.value = 0;
    }
  }

  bool get _isConnected => widget.status == ConnectionStatus.connected;
  bool get _isConnecting => widget.status == ConnectionStatus.connecting;
  bool get _isDisconnecting => widget.status == ConnectionStatus.disconnecting;
  bool get _isTransitioning => _isConnecting || _isDisconnecting;
  bool get _isDisabled => widget.locked || _isTransitioning;
  bool get _shouldPulse => widget.locked || _isTransitioning;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final pulseColor = _isDisconnecting ? c.textMuted : c.primary;
    final progressColor = _isDisconnecting ? c.textMuted : c.primary;

    return MouseRegion(
      cursor: _isDisabled ? MouseCursor.defer : SystemMouseCursors.click,
      child: GestureDetector(
        onTap: _isDisabled ? null : widget.onTap,
        onTapDown: _isDisabled ? null : (_) => setState(() => _pressed = true),
        onTapUp: _isDisabled ? null : (_) => setState(() => _pressed = false),
        onTapCancel: _isDisabled
            ? null
            : () => setState(() => _pressed = false),
        child: SizedBox(
          width: 126,
          height: 126,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              if (_shouldPulse)
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, _) {
                    final t = Curves.easeOut.transform(_pulseController.value);
                    return Container(
                      width: 108 + 26 * t,
                      height: 108 + 26 * t,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: pulseColor.withValues(alpha: 0.18 * (1 - t)),
                        border: Border.all(
                          color: pulseColor.withValues(alpha: 0.24 * (1 - t)),
                        ),
                      ),
                    );
                  },
                ),
              // Success glow + radiating rings, behind the button so they read
              // as emanating from its edge.
              AnimatedBuilder(
                animation: _successController,
                builder: (context, _) => _buildSuccessBurst(c),
              ),
              AnimatedBuilder(
                animation: _successController,
                builder: (context, child) {
                  final t = _successController.value;
                  // Elastic "pop" on success: 1 → ~1.07 → 1.
                  return Transform.scale(
                    scale: 1 + 0.07 * math.sin(t * math.pi),
                    child: child,
                  );
                },
                child: AnimatedScale(
                  duration: const Duration(milliseconds: 170),
                  curve: Curves.easeOutCubic,
                  scale: _isDisabled ? 0.96 : (_pressed ? 0.92 : 1.0),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 320),
                    curve: Curves.easeOutCubic,
                    width: 104,
                    height: 104,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: _isConnected ? AppPalette.brandGradient : null,
                      color: _isConnected ? null : c.surfaceMuted,
                      border: _isConnected || _isTransitioning
                          ? null
                          : Border.all(
                              color: c.primary.withValues(alpha: 0.14),
                            ),
                      boxShadow: _isConnected
                          ? AppShadows.powerButton
                          : [
                              BoxShadow(
                                color: c.primary.withValues(
                                  alpha: _isTransitioning ? 0.16 : 0.08,
                                ),
                                blurRadius: _isTransitioning ? 26 : 18,
                                offset: const Offset(0, 8),
                              ),
                            ],
                    ),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeOutCubic,
                      margin: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _isConnected
                              ? Colors.white.withValues(alpha: 0.72)
                              : c.cardBg.withValues(alpha: 0.72),
                          width: 3,
                        ),
                      ),
                      child: Center(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 240),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          transitionBuilder: (child, animation) {
                            return FadeTransition(
                              opacity: animation,
                              child: ScaleTransition(
                                scale: Tween<double>(
                                  begin: 0.88,
                                  end: 1,
                                ).animate(animation),
                                child: child,
                              ),
                            );
                          },
                          child: _isTransitioning
                              ? _ChargingRing(
                                  key: ValueKey(widget.status),
                                  turns: _chargeController,
                                  color: progressColor,
                                )
                              : Icon(
                                  LucideIcons.power,
                                  key: ValueKey(widget.status),
                                  size: 40,
                                  color: _isConnected
                                      ? Colors.white
                                      : c.primary,
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuccessBurst(AppColors c) {
    final t = _successController.value;
    if (t <= 0 || t >= 1) return const SizedBox.shrink();
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 104 + 24 * t,
          height: 104 + 24 * t,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: c.success.withValues(alpha: 0.20 * (1 - t)),
          ),
        ),
        for (var i = 0; i < 2; i++) _successRing(c, t, i),
      ],
    );
  }

  Widget _successRing(AppColors c, double t, int i) {
    final progress = ((t - i * 0.10) / 0.90).clamp(0.0, 1.0);
    if (progress <= 0 || progress >= 1) return const SizedBox.shrink();
    final size = 104 + progress * 56;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: c.success.withValues(alpha: 0.45 * (1 - progress)),
          width: 2,
        ),
      ),
    );
  }
}

class _ChargingRing extends StatelessWidget {
  const _ChargingRing({
    super.key,
    required this.turns,
    required this.color,
  });

  final Animation<double> turns;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: turns,
      child: SizedBox(
        width: 46,
        height: 46,
        child: CircularProgressIndicator(
          value: 0.33,
          strokeWidth: 3,
          strokeCap: StrokeCap.round,
          color: color,
        ),
      ),
    );
  }
}

class _ConnectionActionText extends StatelessWidget {
  const _ConnectionActionText({required this.status});

  final ConnectionStatus status;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final (text, color) = switch (status) {
      ConnectionStatus.disconnected => (
        context.l10n.startConnection,
        c.primary,
      ),
      ConnectionStatus.connecting => (context.l10n.connecting, c.primary),
      ConnectionStatus.connected => (
        context.l10n.disconnectConnection,
        c.success,
      ),
      ConnectionStatus.disconnecting => (
        context.l10n.disconnecting,
        c.textMuted,
      ),
      ConnectionStatus.error => (context.l10n.reconnect, c.danger),
    };

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.10),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
      child: Row(
        key: ValueKey(text),
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: AppTextStyles.sectionTitle.copyWith(
              color: color,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }
}
