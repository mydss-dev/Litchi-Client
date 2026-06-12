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

    final isMobile = MediaQuery.sizeOf(context).width < _mobileBreakpoint;

    if (isMobile) {
      return _FormArea(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
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

class _FormArea extends StatelessWidget {
  const _FormArea({
    required this.child,
    this.padding = EdgeInsets.zero,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      color: c.cardBg,
      alignment: Alignment.center,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: padding,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: child,
          ),
        ),
      ),
    );
  }
}
