import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/app_controller.dart';
import '../../l10n/l10n.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_spacing.dart';
import '../../shared/theme/app_text_styles.dart';
import '../../shared/widgets/app_toast.dart';
import 'widgets/auth_form_parts.dart';
import 'widgets/auth_input.dart';
import 'widgets/auth_primary_button.dart';

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
      AppToast.show(
        context,
        context.l10n.passwordFieldsRequired,
        type: AppToastType.warning,
      );
      return;
    }
    if (newPwd != confirm) {
      AppToast.show(
        context,
        context.l10n.passwordsMismatch,
        type: AppToastType.error,
      );
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
        AppToast.show(
          context,
          context.l10n.passwordChanged,
          type: AppToastType.success,
        );
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
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AuthInput(
          icon: LucideIcons.lock,
          hintText: l10n.currentPasswordHint,
          controller: _oldCtrl,
          obscure: true,
          showRevealToggle: true,
          textInputAction: TextInputAction.next,
          onSubmitted: (_) => FocusScope.of(context).nextFocus(),
        ),
        const SizedBox(height: AppSpacing.lg),
        AuthInput(
          icon: LucideIcons.lock,
          hintText: l10n.newPasswordHint,
          controller: _newCtrl,
          obscure: true,
          showRevealToggle: true,
          textInputAction: TextInputAction.next,
          onSubmitted: (_) => FocusScope.of(context).nextFocus(),
        ),
        const SizedBox(height: AppSpacing.lg),
        AuthInput(
          icon: LucideIcons.lock,
          hintText: l10n.confirmPasswordHint,
          controller: _confirmCtrl,
          obscure: true,
          showRevealToggle: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(
                LucideIcons.shieldCheck,
                size: 14,
                color: c.textSecondary,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                l10n.passwordAdvice,
                style: AppTextStyles.caption.copyWith(color: c.textSecondary),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xxl),
        AuthPrimaryButton(
          label: l10n.saveChanges,
          isLoading: _loading,
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
}
