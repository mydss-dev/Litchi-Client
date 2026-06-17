import 'dart:io' show Platform;

import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../shared/config/app_config.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_shadows.dart';
import '../../shared/theme/app_text_styles.dart';
import 'change_password_page.dart';
import 'forgot_password_page.dart';
import 'login_page.dart';
import 'register_page.dart';
import '../../shared/widgets/brand_logo.dart';

bool get _isDesktop =>
    Platform.isWindows || Platform.isMacOS || Platform.isLinux;

class AuthFlow extends StatelessWidget {
  const AuthFlow({super.key});

  @override
  Widget build(BuildContext context) {
    final screen = AppScope.of(context).authScreen;

    final spec = switch (screen) {
      AuthScreen.login => const _AuthSpec(
        title: '登录账户',
        subtitle: '请输入您的凭据继续',
        child: LoginPage(),
      ),
      AuthScreen.register => const _AuthSpec(
        title: '创建账户',
        subtitle: '开始连接全世界',
        child: RegisterPage(),
      ),
      AuthScreen.changePassword => const _AuthSpec(
        title: '修改密码',
        subtitle: '更新登录密码，保护账户安全',
        child: ChangePasswordPage(),
      ),
      AuthScreen.forgotPassword => const _AuthSpec(
        title: '忘记密码',
        subtitle: '我们将向您的邮箱发送验证码',
        child: ForgotPasswordPage(),
      ),
    };

    return _AuthArea(spec: spec, screen: screen);
  }
}

class _AuthSpec {
  const _AuthSpec({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;
}

class _AuthArea extends StatelessWidget {
  const _AuthArea({required this.spec, required this.screen});

  final _AuthSpec spec;
  final AuthScreen screen;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      color: c.appBg,
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final availableHeight = constraints.hasBoundedHeight
                ? (constraints.maxHeight - 44).clamp(0.0, double.infinity)
                : 0.0;
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: availableHeight),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: Container(
                      decoration: BoxDecoration(
                        color: c.cardBg,
                        borderRadius: BorderRadius.circular(20),
                        // On desktop the window already draws its own rounded
                        // 1px frame; a second card border nested inside it reads
                        // as a double frame, so drop it there (kept on mobile,
                        // which has no window chrome).
                        border: _isDesktop
                            ? null
                            : Border.all(color: c.softBorder),
                        boxShadow: AppShadows.card(c),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const _AuthBrandHeader(),
                            const SizedBox(height: 16),
                            Text(
                              spec.title,
                              textAlign: TextAlign.center,
                              style: AppTextStyles.pageTitle.copyWith(
                                color: c.textPrimary,
                                fontSize: 23,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              spec.subtitle,
                              textAlign: TextAlign.center,
                              style: AppTextStyles.body.copyWith(
                                color: c.textMuted,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 20),
                            spec.child,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _AuthBrandHeader extends StatelessWidget {
  const _AuthBrandHeader();

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const BrandLogo(size: 32, radius: 10),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppConfig.appName,
              style: AppTextStyles.bodyStrong.copyWith(
                color: c.textPrimary,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              AppConfig.appSubtitle,
              style: AppTextStyles.caption.copyWith(color: c.textMuted),
            ),
          ],
        ),
      ],
    );
  }
}
