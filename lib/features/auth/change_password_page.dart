import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/app_controller.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_text_styles.dart';
import '../../shared/widgets/app_toast.dart';
import 'widgets/auth_form_parts.dart';
import 'widgets/auth_input.dart';
import 'widgets/auth_primary_button.dart';

/// Change-password form (§19).
class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _oldCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _oldCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final controller = AppScope.of(context);
    final old = _oldCtrl.text;
    final newPwd = _newCtrl.text;
    final confirm = _confirmCtrl.text;

    if (old.isEmpty || newPwd.isEmpty || confirm.isEmpty) {
      AppToast.show(context, '请填写所有密码字段', type: AppToastType.warning);
      return;
    }
    if (newPwd != confirm) {
      AppToast.show(context, '新密码两次输入不一致', type: AppToastType.error);
      return;
    }

    setState(() => _loading = true);
    try {
      await controller.changePasswordApi(
        oldPassword: old,
        newPassword: newPwd,
        passwordConfirmation: confirm,
      );
      if (mounted) {
        AppToast.show(context, '密码修改成功', type: AppToastType.success);
        await Future.delayed(const Duration(milliseconds: 600));
        if (mounted) controller.goToAuthScreen(AuthScreen.login);
      }
    } catch (e) {
      if (mounted) {
        AppToast.show(context, e.toString(), type: AppToastType.error);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final controller = AppScope.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 42, vertical: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('修改密码',
              style: AppTextStyles.authTitle.copyWith(color: c.textPrimary)),
          const SizedBox(height: 8),
          Text('更新你的账户密码',
              style:
                  AppTextStyles.authSubtitle.copyWith(color: c.textSecondary)),
          const SizedBox(height: 24),
          AuthInput(
            icon: LucideIcons.lock,
            hintText: '请输入当前密码',
            controller: _oldCtrl,
            obscure: true,
            showRevealToggle: true,
            onSubmitted: (_) => FocusScope.of(context).nextFocus(),
          ),
          const SizedBox(height: 14),
          AuthInput(
            icon: LucideIcons.lock,
            hintText: '请输入新密码',
            controller: _newCtrl,
            obscure: true,
            showRevealToggle: true,
            onSubmitted: (_) => FocusScope.of(context).nextFocus(),
          ),
          const SizedBox(height: 14),
          AuthInput(
            icon: LucideIcons.lock,
            hintText: '请再次输入新密码',
            controller: _confirmCtrl,
            obscure: true,
            showRevealToggle: true,
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Icon(LucideIcons.shieldCheck, size: 14, color: c.textSecondary),
              const SizedBox(width: 6),
              Text('建议使用 8 位以上字母、数字组合',
                  style: AppTextStyles.caption
                      .copyWith(color: c.textSecondary, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 24),
          AuthPrimaryButton(
            label: '保存修改',
            isLoading: _loading,
            onPressed: _submit,
          ),
          const SizedBox(height: 20),
          Center(
            child: AuthLinkText(
              text: '返回登录',
              onTap: () => controller.goToAuthScreen(AuthScreen.login),
            ),
          ),
        ],
      ),
    );
  }
}
