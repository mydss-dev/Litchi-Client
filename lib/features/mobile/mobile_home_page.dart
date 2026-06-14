import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/app_controller.dart';
import '../../app/core_controller.dart' show ConnectionStatus;
import '../../shared/models/app_models.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_radius.dart';
import '../../shared/theme/app_shadows.dart';
import '../../shared/theme/app_text_styles.dart';
import '../../shared/widgets/app_toast.dart';
import 'mobile_node_picker_sheet.dart';

class MobileHomePage extends StatefulWidget {
  const MobileHomePage({super.key});

  @override
  State<MobileHomePage> createState() => _MobileHomePageState();
}

class _MobileHomePageState extends State<MobileHomePage> {
  Timer? _tickTimer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncTimer();
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    super.dispose();
  }

  void _syncTimer() {
    final ctrl = AppScope.of(context);
    if (ctrl.coreRunning && _tickTimer == null) {
      _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else if (!ctrl.coreRunning && _tickTimer != null) {
      _tickTimer!.cancel();
      _tickTimer = null;
    }
  }

  Future<void> _toggleConnection() async {
    final ctrl = AppScope.of(context);
    if (ctrl.coreConnecting) return;

    final error = await ctrl.toggleConnection();
    _syncTimer();
    if (!mounted) return;

    if (error != null && error.isNotEmpty) {
      AppToast.show(context, error, type: AppToastType.error);
    } else if (ctrl.coreRunning) {
      AppToast.show(context, '连接成功', type: AppToastType.success);
    }
  }

  Future<void> _refresh() async {
    await AppScope.of(context).refreshData();
  }

  String _formatDuration(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = AppScope.of(context);
    final c = AppColors.of(context);

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        children: [
          _MobileHeader(connected: ctrl.coreRunning),
          const SizedBox(height: 16),
          if (ctrl.dataLoadError != null) ...[
            _InlineNotice(
              icon: LucideIcons.circleAlert,
              text: ctrl.dataLoadError!,
              color: c.warning,
            ),
            const SizedBox(height: 12),
          ],
          _MobileConnectionCard(
            status: ctrl.connectionStatus,
            node: ctrl.currentNode,
            proxyMode: ctrl.proxyMode,
            automatic: ctrl.autoSelected,
            elapsedLabel: _formatDuration(ctrl.connectedDuration),
            supportsConnection: ctrl.supportsCoreConnection,
            onToggle: _toggleConnection,
            onNodesTap: () => showMobileNodePicker(context),
          ),
          if (ctrl.connectionStatus == ConnectionStatus.error &&
              ctrl.coreError.isNotEmpty) ...[
            const SizedBox(height: 12),
            _InlineNotice(
              icon: LucideIcons.circleX,
              text: ctrl.coreError,
              color: c.danger,
            ),
          ],
          const SizedBox(height: 14),
          _ModeStrip(selected: ctrl.proxyMode, onChanged: ctrl.setProxyMode),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _MetricCard(
                  icon: LucideIcons.crown,
                  label: '当前套餐',
                  value: ctrl.user.plan.isEmpty ? '--' : ctrl.user.plan,
                  color: c.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricCard(
                  icon: LucideIcons.activity,
                  label: '剩余流量',
                  value: '${ctrl.traffic.remainGb.toStringAsFixed(1)} GB',
                  color: c.success,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MobileHeader extends StatelessWidget {
  const _MobileHeader({required this.connected});

  final bool connected;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Litchi',
                style: AppTextStyles.pageTitle.copyWith(
                  color: c.textPrimary,
                  fontSize: 28,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
        Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: connected
                ? c.success.withValues(alpha: 0.12)
                : c.surfaceMuted,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: c.softBorder),
          ),
          child: Icon(
            connected ? LucideIcons.shieldCheck : LucideIcons.shield,
            color: connected ? c.success : c.iconMuted,
            size: 19,
          ),
        ),
      ],
    );
  }
}

class _MobileConnectionCard extends StatelessWidget {
  const _MobileConnectionCard({
    required this.status,
    required this.node,
    required this.proxyMode,
    required this.automatic,
    required this.elapsedLabel,
    required this.supportsConnection,
    required this.onToggle,
    required this.onNodesTap,
  });

  final ConnectionStatus status;
  final NodeModel node;
  final ProxyMode proxyMode;
  final bool automatic;
  final String elapsedLabel;
  final bool supportsConnection;
  final VoidCallback onToggle;
  final VoidCallback onNodesTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final isBusy =
        status == ConnectionStatus.connecting ||
        status == ConnectionStatus.disconnecting;
    final (statusText, statusColor) = !supportsConnection
        ? ('业务版', c.textMuted)
        : switch (status) {
            ConnectionStatus.connected => ('保护中', c.success),
            ConnectionStatus.connecting => ('连接中', c.primary),
            ConnectionStatus.disconnecting => ('断开中', c.textMuted),
            ConnectionStatus.error => ('连接失败', c.danger),
            ConnectionStatus.disconnected => ('未连接', c.textMuted),
          };
    final actionText = !supportsConnection
        ? '暂未开放'
        : switch (status) {
            ConnectionStatus.connected => '断开连接',
            ConnectionStatus.connecting => '正在连接',
            ConnectionStatus.disconnecting => '正在断开',
            ConnectionStatus.error => '重新连接',
            ConnectionStatus.disconnected => '开始连接',
          };
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        color: c.cardBg,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: c.softBorder),
        boxShadow: AppShadows.card(c),
      ),
      child: Column(
        children: [
          Row(
            children: [_StatusPill(label: statusText, color: statusColor)],
          ),
          const SizedBox(height: 18),
          GestureDetector(
            onTap: isBusy || !supportsConnection ? null : onToggle,
            child: Container(
              width: 132,
              height: 132,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: status == ConnectionStatus.connected
                    ? c.brandGradient
                    : null,
                color: status == ConnectionStatus.connected
                    ? null
                    : c.surfaceMuted,
                boxShadow: status == ConnectionStatus.connected
                    ? AppShadows.powerButton
                    : AppShadows.soft(c),
                border: Border.all(
                  color: status == ConnectionStatus.connected
                      ? Colors.white.withValues(alpha: 0.3)
                      : c.softBorder,
                  width: 1,
                ),
              ),
              child: Center(
                child: isBusy
                    ? CircularProgressIndicator(
                        strokeWidth: 3,
                        color: c.primary,
                      )
                    : Icon(
                        LucideIcons.power,
                        size: 46,
                        color: status == ConnectionStatus.connected
                            ? Colors.white
                            : c.primary,
                      ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            actionText,
            style: AppTextStyles.sectionTitle.copyWith(
              color: statusColor == c.textMuted ? c.textPrimary : statusColor,
              fontSize: 20,
            ),
          ),
          if (status == ConnectionStatus.connected) ...[
            const SizedBox(height: 4),
            Text(
              elapsedLabel,
              style: AppTextStyles.caption.copyWith(color: c.textMuted),
            ),
          ] else if (!supportsConnection) ...[
            const SizedBox(height: 4),
            Text(
              '当前 Android 版本先提供登录、购买和节点查看',
              textAlign: TextAlign.center,
              style: AppTextStyles.caption.copyWith(color: c.textMuted),
            ),
          ],
          const SizedBox(height: 20),
          GestureDetector(
            onTap: onNodesTap,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: c.surfaceMuted,
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(color: c.softBorder),
              ),
              child: Row(
                children: [
                  _NodeAvatar(node: node),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          node.name.isEmpty ? '请选择节点' : node.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.bodyStrong.copyWith(
                            color: c.textPrimary,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${proxyMode.label} · ${automatic ? '自动选择' : '手动选择'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.caption.copyWith(
                            color: c.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(LucideIcons.chevronRight, size: 18, color: c.iconMuted),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeStrip extends StatelessWidget {
  const _ModeStrip({required this.selected, required this.onChanged});

  final ProxyMode selected;
  final ValueChanged<ProxyMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: c.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: c.softBorder),
      ),
      child: Row(
        children: [
          for (final mode in ProxyMode.values)
            Expanded(
              child: _ModeButton(
                label: switch (mode) {
                  ProxyMode.rule => '规则',
                  ProxyMode.global => '全局',
                  ProxyMode.direct => '直连',
                },
                selected: selected == mode,
                onTap: () => onChanged(mode),
              ),
            ),
        ],
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Ink(
          height: 42,
          decoration: BoxDecoration(
            color: selected ? c.cardBg : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.md),
            boxShadow: selected ? AppShadows.soft(c) : null,
          ),
          child: Center(
            child: Text(
              label,
              style: AppTextStyles.bodyStrong.copyWith(
                color: selected ? c.primary : c.textMuted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: c.cardBg,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: c.softBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTextStyles.caption.copyWith(color: c.textMuted),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyStrong.copyWith(
                    color: c.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineNotice extends StatelessWidget {
  const _InlineNotice({
    required this.icon,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.caption.copyWith(color: c.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 9,
      height: 9,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StatusDot(color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
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
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: c.cardBg,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: c.softBorder),
      ),
      child: Text(
        node.flag.isEmpty ? '·' : node.flag,
        style: const TextStyle(fontSize: 22),
      ),
    );
  }
}
