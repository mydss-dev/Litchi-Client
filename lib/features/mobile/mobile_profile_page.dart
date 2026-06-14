import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/app_controller.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_radius.dart';
import '../../shared/theme/app_shadows.dart';
import '../../shared/theme/app_text_styles.dart';
import '../../shared/widgets/app_bottom_sheet.dart';
import '../../shared/widgets/app_switch.dart';
import '../../shared/widgets/app_toast.dart';

class MobileProfilePage extends StatefulWidget {
  const MobileProfilePage({super.key});

  @override
  State<MobileProfilePage> createState() => _MobileProfilePageState();
}

class _MobileProfilePageState extends State<MobileProfilePage> {
  bool _updating = false;

  Future<void> _updateSettings({
    bool? remindExpire,
    bool? remindTraffic,
    bool? autoRenewal,
  }) async {
    if (_updating) return;
    final ctrl = AppScope.of(context);
    _updating = true;
    final error = await ctrl.updateUserSettings(
      remindExpire: remindExpire ?? ctrl.user.remindExpire,
      remindTraffic: remindTraffic ?? ctrl.user.remindTraffic,
      autoRenewal: autoRenewal ?? ctrl.user.autoRenewal,
    );
    if (!mounted) return;
    _updating = false;
    AppToast.show(
      context,
      error ?? '设置已更新',
      type: error == null ? AppToastType.success : AppToastType.error,
    );
  }

  void _showAccountSheet() {
    final ctrl = AppScope.of(context);
    showAppBottomSheet<void>(
      context: context,
      builder: (_) => AnimatedBuilder(
        animation: ctrl,
        builder: (context, _) => _AccountManageSheet(
          remindExpire: ctrl.user.remindExpire,
          remindTraffic: ctrl.user.remindTraffic,
          autoRenewal: ctrl.user.autoRenewal,
          onExpireChanged: (value) => _updateSettings(remindExpire: value),
          onTrafficChanged: (value) => _updateSettings(remindTraffic: value),
          onAutoRenewalChanged: (value) => _updateSettings(autoRenewal: value),
          onChangePassword: () {
            Navigator.of(context).pop();
            _showChangePasswordSheet();
          },
          onLogout: () {
            Navigator.of(context).pop();
            _confirmLogout();
          },
        ),
      ),
    );
  }

  Future<void> _handlePullRefresh() async {
    final ctrl = AppScope.of(context);
    await ctrl.refreshData();
    if (!mounted || ctrl.dataLoadError != null) return;
    AppToast.show(context, '已刷新', type: AppToastType.success);
  }

  void _showChangePasswordSheet() {
    showAppBottomSheet<void>(
      context: context,
      builder: (_) => const _ChangePasswordSheet(),
    );
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showAppBottomSheet<bool>(
      context: context,
      builder: (_) => const _LogoutSheet(),
    );
    if (confirmed != true || !mounted) return;
    AppScope.of(context).logout();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = AppScope.of(context);
    final user = ctrl.user;

    return RefreshIndicator(
      onRefresh: _handlePullRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        children: [
          Text('用户中心', style: AppTextStyles.pageTitle.copyWith(fontSize: 26)),
          const SizedBox(height: 14),
          _ProfileHeader(
            userName: user.name,
            plan: user.plan,
            expiry: user.expiry,
            avatar: user.avatarLetter,
            onManage: _showAccountSheet,
          ),
          const SizedBox(height: 14),
          _MenuTile(
            icon: LucideIcons.walletCards,
            title: '我的钱包',
            subtitle: '余额、佣金与账户充值',
            onTap: () => ctrl.goToPage(AppPage.wallet),
          ),
          _MenuTile(
            icon: LucideIcons.clipboardList,
            title: '订单记录',
            subtitle: '查看购买记录与支付状态',
            onTap: () => ctrl.goToPage(AppPage.orders),
          ),
          _MenuTile(
            icon: LucideIcons.messageSquare,
            title: '工单支持',
            subtitle: '联系在线客服',
            onTap: () => ctrl.goToPage(AppPage.tickets),
          ),
          _MenuTile(
            icon: LucideIcons.settings,
            title: '系统设置',
            subtitle: '网络、代理与应用外观',
            onTap: () => ctrl.goToPage(AppPage.settings),
          ),
        ],
      ),
    );
  }
}

class _LogoutSheet extends StatelessWidget {
  const _LogoutSheet();

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return AppBottomSheet(
      title: '退出登录',
      subtitle: '当前登录状态和本地节点缓存将被清除',
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: c.danger.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Row(
            children: [
              Icon(LucideIcons.circleAlert, color: c.danger, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '确认退出当前账号？退出后需要重新登录。',
                  style: AppTextStyles.caption.copyWith(
                    color: c.danger,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 42,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('取消'),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SizedBox(
                height: 42,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: FilledButton.styleFrom(backgroundColor: c.danger),
                  child: const Text('确认退出'),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.userName,
    required this.plan,
    required this.expiry,
    required this.avatar,
    required this.onManage,
  });

  final String userName;
  final String plan;
  final String expiry;
  final String avatar;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.cardBg,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: c.softBorder),
        boxShadow: AppShadows.soft(c),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 25,
            backgroundColor: c.primarySoft,
            child: Text(
              avatar.isEmpty ? 'L' : avatar,
              style: AppTextStyles.bodyStrong.copyWith(color: c.primary),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  userName.isEmpty ? '--' : userName,
                  style: AppTextStyles.bodyStrong.copyWith(fontSize: 16),
                ),
                const SizedBox(height: 3),
                Text(
                  plan.isEmpty ? '暂无套餐' : plan,
                  style: AppTextStyles.caption.copyWith(color: c.textMuted),
                ),
                if (expiry.isNotEmpty)
                  Text(
                    '到期：$expiry',
                    style: AppTextStyles.caption.copyWith(color: c.textMuted),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: onManage,
            child: Container(
              height: 34,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: c.primarySoft,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    LucideIcons.slidersHorizontal,
                    color: c.primary,
                    size: 15,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '管理',
                    style: AppTextStyles.caption.copyWith(
                      color: c.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: c.cardBg,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: c.softBorder),
            boxShadow: AppShadows.soft(c),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: c.primarySoft,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(icon, color: c.primary, size: 19),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTextStyles.bodyStrong),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption.copyWith(color: c.textMuted),
                    ),
                  ],
                ),
              ),
              Icon(LucideIcons.chevronRight, color: c.iconMuted, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountManageSheet extends StatelessWidget {
  const _AccountManageSheet({
    required this.remindExpire,
    required this.remindTraffic,
    required this.autoRenewal,
    required this.onExpireChanged,
    required this.onTrafficChanged,
    required this.onAutoRenewalChanged,
    required this.onChangePassword,
    required this.onLogout,
  });

  final bool remindExpire;
  final bool remindTraffic;
  final bool autoRenewal;
  final ValueChanged<bool> onExpireChanged;
  final ValueChanged<bool> onTrafficChanged;
  final ValueChanged<bool> onAutoRenewalChanged;
  final VoidCallback onChangePassword;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return AppBottomSheet(
      title: '账号管理',
      children: [
        _SwitchRow(
          icon: LucideIcons.calendarClock,
          title: '到期提醒',
          subtitle: '接收账户到期提醒邮件',
          value: remindExpire,
          onChanged: onExpireChanged,
        ),
        _Divider(color: c.softBorder),
        _SwitchRow(
          icon: LucideIcons.gauge,
          title: '流量提醒',
          subtitle: '接收流量用尽提醒邮件',
          value: remindTraffic,
          onChanged: onTrafficChanged,
        ),
        _Divider(color: c.softBorder),
        _SwitchRow(
          icon: LucideIcons.refreshCw,
          title: '自动续费',
          subtitle: '到期前自动续费套餐',
          value: autoRenewal,
          onChanged: onAutoRenewalChanged,
        ),
        _Divider(color: c.softBorder),
        _ActionRow(
          icon: LucideIcons.lockKeyhole,
          title: '修改密码',
          subtitle: '更新登录密码',
          onTap: onChangePassword,
        ),
        _Divider(color: c.softBorder),
        _ActionRow(
          icon: LucideIcons.logOut,
          title: '退出登录',
          subtitle: '退出当前账号',
          danger: true,
          onTap: onLogout,
        ),
      ],
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, color: c.primary, size: 19),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.bodyStrong),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppTextStyles.caption.copyWith(color: c.textMuted),
                ),
              ],
            ),
          ),
          AppSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final color = danger ? c.danger : c.primary;
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: color, size: 19),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.bodyStrong.copyWith(
                      color: danger ? c.danger : c.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTextStyles.caption.copyWith(color: c.textMuted),
                  ),
                ],
              ),
            ),
            Icon(LucideIcons.chevronRight, color: c.iconMuted, size: 18),
          ],
        ),
      ),
    );
  }
}

class _ChangePasswordSheet extends StatefulWidget {
  const _ChangePasswordSheet();

  @override
  State<_ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<_ChangePasswordSheet> {
  final _oldCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _oldCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final oldPassword = _oldCtrl.text.trim();
    final newPassword = _newCtrl.text.trim();
    final confirm = _confirmCtrl.text.trim();
    if (oldPassword.isEmpty || newPassword.isEmpty || confirm.isEmpty) {
      AppToast.show(context, '请填写完整密码信息', type: AppToastType.warning);
      return;
    }
    if (newPassword != confirm) {
      AppToast.show(context, '两次输入的新密码不一致', type: AppToastType.warning);
      return;
    }
    if (newPassword.length < 8) {
      AppToast.show(context, '新密码至少 8 位', type: AppToastType.warning);
      return;
    }

    setState(() => _submitting = true);
    try {
      await AppScope.of(context).changePasswordApi(
        oldPassword: oldPassword,
        newPassword: newPassword,
        passwordConfirmation: confirm,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      AppToast.show(context, '密码已更新', type: AppToastType.success);
    } catch (e) {
      if (!mounted) return;
      AppToast.show(
        context,
        e.toString().replaceFirst('ApiException: ', ''),
        type: AppToastType.error,
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppBottomSheet(
      title: '修改密码',
      children: [
        _PasswordField(controller: _oldCtrl, label: '当前密码'),
        const SizedBox(height: 12),
        _PasswordField(controller: _newCtrl, label: '新密码'),
        const SizedBox(height: 12),
        _PasswordField(controller: _confirmCtrl, label: '确认新密码'),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 44,
          child: FilledButton.icon(
            onPressed: _submitting ? null : _submit,
            icon: _submitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(LucideIcons.lockKeyhole, size: 17),
            label: Text(_submitting ? '更新中...' : '确认修改'),
          ),
        ),
      ],
    );
  }
}

class _PasswordField extends StatelessWidget {
  const _PasswordField({required this.controller, required this.label});

  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: c.textMuted,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: true,
          style: AppTextStyles.input.copyWith(color: c.textPrimary),
          decoration: InputDecoration(
            hintText: '请输入$label',
            hintStyle: AppTextStyles.input.copyWith(color: c.textMuted),
            filled: true,
            fillColor: c.surfaceMuted,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: BorderSide(color: c.softBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: BorderSide(color: c.primary),
            ),
          ),
        ),
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Divider(height: 1, color: color);
  }
}
