import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/app_controller.dart';
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
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;

    if (email.isEmpty || password.isEmpty) {
      AppToast.show(context, '请填写邮箱和密码', type: AppToastType.warning);
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

      AppToast.showInOverlay(overlay, '登录成功，欢迎回来！', type: AppToastType.success);
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AuthInput(
          icon: LucideIcons.mail,
          label: '邮箱',
          requiredMark: true,
          hintText: '请输入邮箱或用户名',
          controller: _emailCtrl,
          onSubmitted: (_) => FocusScope.of(context).nextFocus(),
        ),
        const SizedBox(height: 16),
        AuthInput(
          icon: LucideIcons.lock,
          label: '密码',
          requiredMark: true,
          hintText: '请输入密码',
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
              label: '记住账号密码',
              onChanged: (v) => setState(() => _remember = v),
            ),
            AuthLinkText(
              text: '忘记密码？',
              onTap: () => controller.goToAuthScreen(AuthScreen.forgotPassword),
            ),
          ],
        ),
        const SizedBox(height: 24),
        AuthPrimaryButton(label: '登录', isLoading: _loading, onPressed: _submit),
        if (controller.registerConfig.registerOpen) ...[
          const SizedBox(height: 20),
          AuthBottomJump(
            leadingText: '还没有账号？',
            actionText: '注册账号',
            onTap: () => controller.goToAuthScreen(AuthScreen.register),
          ),
        ],
      ],
    );
  }
}
