import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/app_controller.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_text_styles.dart';
import '../../shared/widgets/app_toast.dart';
import 'widgets/auth_form_parts.dart';
import 'widgets/auth_input.dart';
import 'widgets/auth_primary_button.dart';

/// Registration form (§18).
class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _inviteCtrl = TextEditingController();
  bool _agree = false;
  bool _loading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    _inviteCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final controller = AppScope.of(context);
    final overlay = Overlay.of(context, rootOverlay: true);
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    final confirm = _confirmCtrl.text;
    final invite = _inviteCtrl.text.trim();

    if (email.isEmpty || password.isEmpty) {
      AppToast.show(context, '请填写邮箱和密码', type: AppToastType.warning);
      return;
    }
    if (password != confirm) {
      AppToast.show(context, '两次密码不一致', type: AppToastType.error);
      return;
    }
    if (!_agree) {
      AppToast.show(context, '请先同意服务条款', type: AppToastType.warning);
      return;
    }

    setState(() => _loading = true);
    try {
      await controller.registerWithCredentials(
        email: email,
        password: password,
        passwordConfirmation: confirm,
        inviteCode: invite.isNotEmpty ? invite : null,
      );
      AppToast.showInOverlay(
        overlay,
        '注册成功，欢迎加入 Litchi！',
        type: AppToastType.success,
      );
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
      padding: const EdgeInsets.symmetric(horizontal: 42, vertical: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '注册',
            style: AppTextStyles.authTitle.copyWith(color: c.textPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            '创建你的 Litchi 账户',
            style: AppTextStyles.authSubtitle.copyWith(color: c.textSecondary),
          ),
          const SizedBox(height: 20),
          AuthInput(
            icon: LucideIcons.mail,
            hintText: '请输入邮箱地址',
            controller: _emailCtrl,
          ),
          const SizedBox(height: 12),
          AuthInput(
            icon: LucideIcons.lock,
            hintText: '请输入密码',
            controller: _passwordCtrl,
            obscure: true,
            showRevealToggle: true,
          ),
          const SizedBox(height: 12),
          AuthInput(
            icon: LucideIcons.lock,
            hintText: '请再次输入密码',
            controller: _confirmCtrl,
            obscure: true,
            showRevealToggle: true,
          ),
          const SizedBox(height: 12),
          AuthInput(
            icon: LucideIcons.ticket,
            hintText: '邀请码（可选）',
            controller: _inviteCtrl,
          ),
          const SizedBox(height: 16),
          AuthCheckboxRow(
            value: _agree,
            label: '',
            onChanged: (v) => setState(() => _agree = v),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '我已阅读并同意 ',
                  style: AppTextStyles.caption.copyWith(
                    color: c.textSecondary,
                    fontSize: 12,
                  ),
                ),
                Text(
                  '服务条款',
                  style: AppTextStyles.button.copyWith(color: c.primary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          AuthPrimaryButton(
            label: '注册',
            isLoading: _loading,
            onPressed: _submit,
          ),
          const SizedBox(height: 20),
          AuthBottomJump(
            leadingText: '已有账号？',
            actionText: '登录',
            onTap: () => controller.goToAuthScreen(AuthScreen.login),
          ),
        ],
      ),
    );
  }
}
