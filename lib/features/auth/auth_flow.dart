import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../shared/theme/app_colors.dart';
import 'change_password_page.dart';
import 'forgot_password_page.dart';
import 'login_page.dart';
import 'register_page.dart';
import 'widgets/auth_visual_area.dart';

/// Full-bleed auth layout: the left gradient visual area and the right form
/// area fill the entire window (below the overlaid window controls). No
/// floating card, no outer margins (§16.2 — the panel is the body itself).
class AuthFlow extends StatelessWidget {
  const AuthFlow({super.key});

  // Left visual : right form ≈ 40 : 60.
  static const int _visualFlex = 40;
  static const int _formFlex = 60;

  @override
  Widget build(BuildContext context) {
    final screen = AppScope.of(context).authScreen;

    final (visualTitle, visualSubtitle, form) = switch (screen) {
      AuthScreen.login => (
          '欢迎登录',
          '登录后即可管理订阅、查看与连接状态',
          const LoginPage(),
        ),
      AuthScreen.register => (
          '欢迎注册',
          '创建账户，开启安全快速的网络连接',
          const RegisterPage(),
        ),
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
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: child,
      ),
    );
  }
}
