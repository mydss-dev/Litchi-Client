import 'package:flutter/material.dart';

import '../../../app/app_controller.dart';
import '../../../app/core_platform_support.dart';
import '../../../shared/models/app_models.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_radius.dart';
import '../../../shared/theme/app_text_styles.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_toast.dart';

class NetworkSettingsCard extends StatefulWidget {
  const NetworkSettingsCard({super.key});

  @override
  State<NetworkSettingsCard> createState() => _NetworkSettingsCardState();
}

class _NetworkSettingsCardState extends State<NetworkSettingsCard> {
  bool _checkingAdmin = false;

  Future<void> _setMode(NetworkMode mode) async {
    if (!CorePlatformSupport.supportsNetworkMode(mode)) return;
    final ctrl = AppScope.of(context);
    if (ctrl.networkMode == mode) return;

    if (mode == NetworkMode.tun) {
      setState(() => _checkingAdmin = true);
      final isAdmin = await AppController.checkAdminPrivileges();
      if (!mounted) return;
      setState(() => _checkingAdmin = false);

      if (!isAdmin) {
        await showDialog<void>(
          context: context,
          barrierColor: Colors.black.withValues(alpha: 0.42),
          builder: (ctx) {
            final c = AppColors.of(ctx);
            return Dialog(
              backgroundColor: Colors.transparent,
              child: Container(
                width: 360,
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: c.cardBg,
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 40,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '需要管理员权限',
                      style: AppTextStyles.heroTitle.copyWith(
                        color: c.textPrimary,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'TUN 虚拟网卡模式需要管理员权限才能创建虚拟网络接口。\n\n'
                      '请右键点击客户端图标，选择「以管理员身份运行」后重新启动，再切换至此模式。',
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
                          '知道了',
                          style: AppTextStyles.button.copyWith(
                            color: c.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
        return;
      }
    }

    ctrl.setNetworkMode(mode);
    if (ctrl.coreRunning && mounted) {
      AppToast.show(context, '网络模式已切换，重新连接后生效');
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

    return AppCard(
      radius: AppRadius.card,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '网络设置',
            style: AppTextStyles.sectionTitle.copyWith(
              color: c.textPrimary,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            mode == NetworkMode.system ? '使用系统代理接管网络请求' : '通过虚拟网卡接管全部流量',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.body.copyWith(color: c.textMuted),
          ),
          const SizedBox(height: 16),
          // ── Mode toggle ───────────────────────────────────────────────────
          Container(
            height: 38,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: c.surfaceMuted,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: c.softBorder),
            ),
            child: Row(
              children: [
                if (supportsSystem)
                  Expanded(
                    child: _NetworkModeOption(
                      label: '系统代理',
                      selected: mode == NetworkMode.system,
                      loading: false,
                      onTap: () => _setMode(NetworkMode.system),
                    ),
                  ),
                if (supportsTun)
                  Expanded(
                    child: _NetworkModeOption(
                      label: '虚拟网卡',
                      selected: mode == NetworkMode.tun,
                      loading: _checkingAdmin,
                      onTap: () => _setMode(NetworkMode.tun),
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

// ── Mode option ───────────────────────────────────────────────────────────────

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
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: loading ? null : onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? c.cardBg : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: c.primary.withValues(alpha: 0.14),
                      blurRadius: 12,
                      offset: const Offset(0, 5),
                    ),
                  ]
                : null,
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
                    color: selected ? c.primary : c.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
        ),
      ),
    );
  }
}
