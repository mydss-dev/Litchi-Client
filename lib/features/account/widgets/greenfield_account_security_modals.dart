import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/app_controller.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_text_styles.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_modal.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/app_toast.dart';

Future<void> showGreenfieldChangePasswordModal(BuildContext context) {
  return showAppAdaptiveModal<void>(
    context: context,
    builder: (_) => const _ChangePasswordModal(),
  );
}

Future<bool> showGreenfieldLogoutConfirmation(BuildContext context) async {
  final confirmed = await showAppAdaptiveModal<bool>(
    context: context,
    builder: (_) => const _LogoutModal(),
  );
  return confirmed == true;
}

class _ChangePasswordModal extends StatefulWidget {
  const _ChangePasswordModal();

  @override
  State<_ChangePasswordModal> createState() => _ChangePasswordModalState();
}

class _ChangePasswordModalState extends State<_ChangePasswordModal> {
  final _oldController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _oldController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final oldPassword = _oldController.text.trim();
    final newPassword = _newController.text.trim();
    final confirmation = _confirmController.text.trim();

    if (oldPassword.isEmpty || newPassword.isEmpty || confirmation.isEmpty) {
      AppToast.show(
        context,
        context.l10n.passwordFieldsRequired,
        type: AppToastType.warning,
      );
      return;
    }
    if (newPassword != confirmation) {
      AppToast.show(
        context,
        context.l10n.passwordsMismatch,
        type: AppToastType.warning,
      );
      return;
    }
    if (newPassword.length < 8) {
      AppToast.show(
        context,
        context.l10n.passwordTooShort,
        type: AppToastType.warning,
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      await AppScope.of(context).changePasswordApi(
        oldPassword: oldPassword,
        newPassword: newPassword,
        passwordConfirmation: confirmation,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      AppToast.show(
        context,
        context.l10n.passwordChanged,
        type: AppToastType.success,
      );
    } catch (error) {
      if (!mounted) return;
      AppToast.show(
        context,
        error.toString().replaceFirst('ApiException: ', ''),
        type: AppToastType.error,
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppAdaptiveModal(
      title: context.l10n.changePasswordTitle,
      subtitle: context.l10n.changePasswordSubtitle,
      maxWidth: 520,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTextField(
            controller: _oldController,
            label: context.l10n.currentPassword,
            hint: context.l10n.currentPasswordHint,
            obscureText: true,
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            controller: _newController,
            label: context.l10n.newPassword,
            hint: context.l10n.newPasswordHint,
            obscureText: true,
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            controller: _confirmController,
            label: context.l10n.confirmNewPassword,
            hint: context.l10n.confirmNewPasswordHint,
            obscureText: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: context.l10n.confirmChange,
            leadingIcon: LucideIcons.lockKeyhole,
            loading: _submitting,
            onPressed: _submitting ? null : _submit,
            expand: true,
          ),
        ],
      ),
    );
  }
}

class _LogoutModal extends StatelessWidget {
  const _LogoutModal();

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return AppAdaptiveModal(
      title: context.l10n.logout,
      subtitle: context.l10n.logoutDataNotice,
      maxWidth: 480,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppCard(
            color: c.danger.withValues(alpha: 0.08),
            borderColor: c.danger.withValues(alpha: 0.16),
            shadow: AppCardShadow.none,
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(LucideIcons.circleAlert, color: c.danger, size: 20),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    context.l10n.logoutConfirmMessage,
                    style: AppTextStyles.body.copyWith(color: c.textSecondary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: context.l10n.cancel,
                  variant: AppButtonVariant.outline,
                  onPressed: () => Navigator.of(context).pop(false),
                  expand: true,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: AppButton(
                  label: context.l10n.confirmLogout,
                  leadingIcon: LucideIcons.logOut,
                  variant: AppButtonVariant.danger,
                  onPressed: () => Navigator.of(context).pop(true),
                  expand: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
