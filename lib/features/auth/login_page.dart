import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/app_controller.dart';
import '../../l10n/l10n.dart';
import '../../shared/services/credentials_storage.dart';
import '../../shared/widgets/app_toast.dart';
import 'widgets/auth_form_parts.dart';
import 'widgets/auth_input.dart';
import 'widgets/auth_primary_button.dart';

/// Login form occupying the right form area (§17).
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _remember = true;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadSaved();
    WidgetsBinding.instance.addPostFrameCallback((_) => _showStartupMessage());
  }

  Future<void> _loadSaved() async {
    final saved = await CredentialsStorage.load();
    if (saved != null && mounted) {
      if (_looksLikeJwt(saved.password)) {
        await CredentialsStorage.clearPassword();
        if (!mounted) return;
        setState(() {
          _emailCtrl.text = saved.email;
          _passwordCtrl.clear();
          _remember = true;
        });
        return;
      }
      setState(() {
        _emailCtrl.text = saved.email;
        _passwordCtrl.text = saved.password;
        _remember = true;
      });
    }
  }

  bool _looksLikeJwt(String value) {
    final parts = value.split('.');
    return value.startsWith('eyJ') && parts.length == 3;
  }

  void _showStartupMessage() {
    if (!mounted) return;
    final ctrl = AppScope.of(context);
    final msg = ctrl.startupMessage;
    if (msg != null) {
      ctrl.clearStartupMessage();
      AppToast.show(context, msg, type: AppToastType.warning);
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final controller = AppScope.of(context);
    final overlay = Overlay.of(context, rootOverlay: true);
    final l10n = context.l10n;
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;

    if (email.isEmpty || password.isEmpty) {
      AppToast.show(
        context,
        l10n.requiredCredentials,
        type: AppToastType.warning,
      );
      return;
    }

    setState(() => _loading = true);
    try {
      await controller.loginWithCredentials(
        email,
        password,
        onAuthenticated: (_) async {
          if (_remember) {
            await CredentialsStorage.save(email: email, password: password);
          } else {
            await CredentialsStorage.clear();
          }
        },
      );

      AppToast.showInOverlay(
        overlay,
        l10n.loginSuccess,
        type: AppToastType.success,
      );
    } catch (e) {
      if (mounted) {
        final message = e.toString().replaceFirst('ApiException: ', '');
        AppToast.show(context, message, type: AppToastType.error);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AuthInput(
          icon: LucideIcons.mail,
          label: l10n.email,
          requiredMark: true,
          hintText: l10n.emailOrUsernameHint,
          controller: _emailCtrl,
          onSubmitted: (_) => FocusScope.of(context).nextFocus(),
        ),
        const SizedBox(height: 16),
        AuthInput(
          icon: LucideIcons.lock,
          label: l10n.password,
          requiredMark: true,
          hintText: l10n.passwordHint,
          controller: _passwordCtrl,
          obscure: true,
          showRevealToggle: true,
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            AuthCheckboxRow(
              value: _remember,
              label: l10n.rememberCredentials,
              onChanged: (v) => setState(() => _remember = v),
            ),
            AuthLinkText(
              text: l10n.forgotPasswordAction,
              onTap: () => controller.goToAuthScreen(AuthScreen.forgotPassword),
            ),
          ],
        ),
        const SizedBox(height: 24),
        AuthPrimaryButton(
          label: l10n.login,
          isLoading: _loading,
          onPressed: _submit,
        ),
        if (controller.registerConfig.registerOpen) ...[
          const SizedBox(height: 20),
          AuthBottomJump(
            leadingText: l10n.noAccount,
            actionText: l10n.registerAccount,
            onTap: () => controller.goToAuthScreen(AuthScreen.register),
          ),
        ],
      ],
    );
  }
}
