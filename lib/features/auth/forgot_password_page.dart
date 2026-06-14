import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/app_controller.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_text_styles.dart';
import '../../shared/widgets/app_toast.dart';
import 'widgets/auth_form_parts.dart';
import 'widgets/auth_input.dart';
import 'widgets/auth_primary_button.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _emailCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _codeSent = false;
  bool _sending = false;
  bool _submitting = false;
  int _countdown = 0;
  Timer? _countdownTimer;

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _emailCtrl.dispose();
    _codeCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  void _startCountdown() {
    setState(() => _countdown = 60);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        _countdown--;
        if (_countdown <= 0) t.cancel();
      });
    });
  }

  Future<void> _sendCode() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      AppToast.show(context, '请输入邮箱地址', type: AppToastType.warning);
      return;
    }
    setState(() => _sending = true);
    try {
      await AppScope.of(
        context,
      ).api.sendEmailVerify(email, isForgetPassword: true);
      if (mounted) {
        setState(() => _codeSent = true);
        _startCountdown();
        AppToast.show(context, '验证码已发送，请查收邮件', type: AppToastType.success);
      }
    } catch (e) {
      if (mounted) {
        AppToast.show(context, e.toString(), type: AppToastType.error);
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _submit() async {
    final email = _emailCtrl.text.trim();
    final code = _codeCtrl.text.trim();
    final password = _passwordCtrl.text;
    final confirm = _confirmCtrl.text;

    if (code.isEmpty || password.isEmpty || confirm.isEmpty) {
      AppToast.show(context, '请填写所有字段', type: AppToastType.warning);
      return;
    }
    if (password != confirm) {
      AppToast.show(context, '两次密码不一致', type: AppToastType.error);
      return;
    }

    setState(() => _submitting = true);
    try {
      await AppScope.of(context).api.resetPassword(
        email: email,
        emailCode: code,
        password: password,
        passwordConfirmation: confirm,
      );
      if (mounted) {
        AppToast.show(context, '密码重置成功，请重新登录', type: AppToastType.success);
        await Future.delayed(const Duration(milliseconds: 600));
        if (mounted) {
          AppScope.of(context).goToAuthScreen(AuthScreen.login);
        }
      }
    } catch (e) {
      if (mounted) {
        AppToast.show(context, e.toString(), type: AppToastType.error);
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AuthInput(
          icon: LucideIcons.mail,
          label: '邮箱',
          requiredMark: true,
          hintText: '请输入注册邮箱',
          controller: _emailCtrl,
          onSubmitted: (_) => FocusScope.of(context).nextFocus(),
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: AuthInput(
                icon: LucideIcons.keyRound,
                label: '验证码',
                requiredMark: true,
                hintText: '请输入验证码',
                controller: _codeCtrl,
                onSubmitted: (_) => FocusScope.of(context).nextFocus(),
              ),
            ),
            const SizedBox(width: 10),
            _SendCodeButton(
              codeSent: _codeSent,
              countdown: _countdown,
              sending: _sending,
              onTap: _sendCode,
            ),
          ],
        ),
        const SizedBox(height: 14),
        AuthInput(
          icon: LucideIcons.lock,
          label: '新密码',
          requiredMark: true,
          hintText: '请输入新密码',
          controller: _passwordCtrl,
          obscure: true,
          showRevealToggle: true,
          onSubmitted: (_) => FocusScope.of(context).nextFocus(),
        ),
        const SizedBox(height: 14),
        AuthInput(
          icon: LucideIcons.lock,
          label: '确认密码',
          requiredMark: true,
          hintText: '请再次输入新密码',
          controller: _confirmCtrl,
          obscure: true,
          showRevealToggle: true,
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: 24),
        AuthPrimaryButton(
          label: '重置密码',
          isLoading: _submitting,
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
    );
  }
}

class _SendCodeButton extends StatelessWidget {
  const _SendCodeButton({
    required this.codeSent,
    required this.countdown,
    required this.sending,
    required this.onTap,
  });

  final bool codeSent;
  final int countdown;
  final bool sending;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final canSend = !sending && countdown == 0;
    final label = sending
        ? '发送中'
        : countdown > 0
        ? '${countdown}s'
        : codeSent
        ? '重新发送'
        : '发送验证码';

    return MouseRegion(
      cursor: canSend ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: canSend ? onTap : null,
        child: Container(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: canSend ? c.primary : c.surfaceMuted,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: AppTextStyles.button.copyWith(
              color: canSend ? Colors.white : c.textMuted,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}
