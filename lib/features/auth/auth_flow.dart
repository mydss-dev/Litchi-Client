import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../shared/theme/app_colors.dart';
import 'change_password_page.dart';
import 'forgot_password_page.dart';
import 'login_page.dart';
import 'register_page.dart';
import 'widgets/auth_visual_area.dart';

class AuthFlow extends StatelessWidget {
  const AuthFlow({super.key});

  static const int _visualFlex = 40;
  static const int _formFlex = 60;
  static const double _mobileBreakpoint = 700;

  @override
  Widget build(BuildContext context) {
    final screen = AppScope.of(context).authScreen;
    final width = MediaQuery.sizeOf(context).width;
    final isCompact = width < _mobileBreakpoint;

    final (visualTitle, visualSubtitle, form) = switch (screen) {
      AuthScreen.login => ('欢迎登录', '登录后即可管理订阅、查看与连接状态', const LoginPage()),
      AuthScreen.register => ('欢迎注册', '创建账户，开启安全快速的网络连接', const RegisterPage()),
      AuthScreen.changePassword => (
        '修改密码',
        '更新你的账户密码，提升账号安全性',
        const ChangePasswordPage(),
      ),
      AuthScreen.forgotPassword => (
        '找回密码',
        '通过邮件验证码重置你的账户密码',
        const ForgotPasswordPage(),
      ),
    };

    if (isCompact) {
      return _CompactAuthArea(
        title: visualTitle,
        subtitle: visualSubtitle,
        child: form,
      );
    }

    return Row(
      children: [
        Expanded(
          flex: _visualFlex,
          child: AuthVisualArea(title: visualTitle, subtitle: visualSubtitle),
        ),
        Expanded(
          flex: _formFlex,
          child: _FormArea(child: form),
        ),
      ],
    );
  }
}

class _CompactAuthArea extends StatelessWidget {
  const _CompactAuthArea({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      color: c.appBg,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 28, 22, 28),
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: c.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: c.textMuted,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 24),
            DecoratedBox(
              decoration: BoxDecoration(
                color: c.cardBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: c.softBorder),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 20, 18, 22),
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// White right-hand area that vertically centers the form and caps its width
/// so inputs stay a comfortable size on the wide full-bleed panel.
class _FormArea extends StatelessWidget {
  const _FormArea({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      color: c.cardBg,
      alignment: Alignment.center,
      child: SafeArea(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: child,
          ),
        ),
      ),
    );
  }
}
