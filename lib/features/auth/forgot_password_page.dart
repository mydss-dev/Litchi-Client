import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/app_controller.dart';
import '../../l10n/l10n.dart';
import '../../shared/theme/app_spacing.dart';
import '../../shared/widgets/app_button.dart';
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
      AppToast.show(
        context,
        context.l10n.invalidEmail,
        type: AppToastType.warning,
      );
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
        AppToast.show(
          context,
          context.l10n.verificationCodeSent,
          type: AppToastType.success,
        );
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
      AppToast.show(
        context,
        context.l10n.allFieldsRequired,
        type: AppToastType.warning,
      );
      return;
    }
    if (password != confirm) {
      AppToast.show(
        context,
        context.l10n.passwordsMismatch,
        type: AppToastType.error,
      );
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
        AppToast.show(
          context,
          context.l10n.passwordResetSuccess,
          type: AppToastType.success,
        );
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
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AuthInput(
          icon: LucideIcons.mail,
          label: l10n.email,
          requiredMark: true,
          hintText: l10n.registeredEmailHint,
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          onSubmitted: (_) => FocusScope.of(context).nextFocus(),
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: AuthInput(
                icon: LucideIcons.keyRound,
                label: l10n.verificationCode,
                requiredMark: true,
                hintText: l10n.verificationCodeHint,
                controller: _codeCtrl,
                textInputAction: TextInputAction.next,
                onSubmitted: (_) => FocusScope.of(context).nextFocus(),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            SizedBox(
              width: 118,
              child: AppButton(
                label: _sendCodeLabel(l10n),
                onPressed: !_sending && _countdown == 0 ? _sendCode : null,
                loading: _sending,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        AuthInput(
          icon: LucideIcons.lock,
          label: l10n.newPassword,
          requiredMark: true,
          hintText: l10n.newPasswordHint,
          controller: _passwordCtrl,
          obscure: true,
          showRevealToggle: true,
          textInputAction: TextInputAction.next,
          onSubmitted: (_) => FocusScope.of(context).nextFocus(),
        ),
        const SizedBox(height: AppSpacing.lg),
        AuthInput(
          icon: LucideIcons.lock,
          label: l10n.confirmPassword,
          requiredMark: true,
          hintText: l10n.confirmPasswordHint,
          controller: _confirmCtrl,
          obscure: true,
          showRevealToggle: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: AppSpacing.xxl),
        AuthPrimaryButton(
          label: l10n.resetPassword,
          isLoading: _submitting,
          onPressed: _submit,
        ),
        const SizedBox(height: AppSpacing.lg),
        Center(
          child: AuthLinkText(
            text: l10n.backToLogin,
            onTap: () => controller.goToAuthScreen(AuthScreen.login),
          ),
        ),
      ],
    );
  }

  String _sendCodeLabel(AppLocalizations l10n) {
    if (_sending) return l10n.sending;
    if (_countdown > 0) return '${_countdown}s';
    return _codeSent ? l10n.resend : l10n.sendVerificationCode;
  }
}
