import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/app_controller.dart';
import '../../l10n/l10n.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_shadows.dart';
import '../../shared/theme/app_text_styles.dart';
import '../../shared/widgets/app_select.dart';
import 'change_password_page.dart';
import 'forgot_password_page.dart';
import 'login_page.dart';
import 'register_page.dart';

bool get _isDesktop =>
    Platform.isWindows || Platform.isMacOS || Platform.isLinux;

class AuthFlow extends StatelessWidget {
  const AuthFlow({super.key, required this.screen});

  final AuthScreen screen;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final spec = switch (screen) {
      AuthScreen.login => _AuthSpec(
        title: l10n.loginTitle,
        subtitle: l10n.loginSubtitle,
        child: const LoginPage(),
      ),
      AuthScreen.register => _AuthSpec(
        title: l10n.registerTitle,
        subtitle: l10n.registerSubtitle,
        child: const RegisterPage(),
      ),
      AuthScreen.changePassword => _AuthSpec(
        title: l10n.changePasswordTitle,
        subtitle: l10n.changePasswordSubtitle,
        child: const ChangePasswordPage(),
      ),
      AuthScreen.forgotPassword => _AuthSpec(
        title: l10n.forgotPasswordTitle,
        subtitle: l10n.forgotPasswordSubtitle,
        child: const ForgotPasswordPage(),
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
      color: _isDesktop ? Colors.transparent : c.appBg,
      child: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final availableHeight = constraints.hasBoundedHeight
                ? (constraints.maxHeight - 44).clamp(0.0, double.infinity)
                : 0.0;
            return ScrollConfiguration(
              behavior: ScrollConfiguration.of(
                context,
              ).copyWith(scrollbars: false),
              child: SingleChildScrollView(
                physics: _isDesktop && screen == AuthScreen.login
                    ? const NeverScrollableScrollPhysics()
                    : null,
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: availableHeight),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 400),
                      child: Container(
                        decoration: _isDesktop
                            ? null
                            : BoxDecoration(
                                gradient: c.cardGradient,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: c.softBorder),
                                boxShadow: AppShadows.card(c),
                              ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
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
                              const SizedBox(height: 18),
                              KeyedSubtree(
                                key: ValueKey(screen),
                                child: spec.child,
                              ),
                              if (_isDesktop && screen == AuthScreen.login) ...[
                                const SizedBox(height: 16),
                                const _DesktopAuthPreferences(),
                              ],
                            ],
                          ),
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

class _DesktopAuthPreferences extends StatelessWidget {
  const _DesktopAuthPreferences();

  @override
  Widget build(BuildContext context) {
    final ctrl = AppScope.of(context);
    final c = AppColors.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(LucideIcons.languages, size: 15, color: c.iconMuted),
        const SizedBox(width: 6),
        AppSelect<AppLocalePreference>(
          value: ctrl.language,
          items: AppLocalePreference.values,
          labelOf: (value) => switch (value) {
            AppLocalePreference.system => context.l10n.followSystem,
            AppLocalePreference.simplifiedChinese =>
              context.l10n.simplifiedChinese,
            AppLocalePreference.traditionalChinese =>
              context.l10n.traditionalChinese,
            AppLocalePreference.english => context.l10n.english,
          },
          onChanged: ctrl.setLanguage,
          minWidth: 112,
        ),
        const SizedBox(width: 12),
        Icon(
          Theme.of(context).brightness == Brightness.dark
              ? LucideIcons.moon
              : LucideIcons.sun,
          size: 15,
          color: c.iconMuted,
        ),
        const SizedBox(width: 6),
        AppSelect<ThemeMode>(
          value: ctrl.themeMode,
          items: const [ThemeMode.system, ThemeMode.light, ThemeMode.dark],
          labelOf: (value) => switch (value) {
            ThemeMode.system => context.l10n.followSystem,
            ThemeMode.light => context.l10n.lightMode,
            ThemeMode.dark => context.l10n.darkMode,
          },
          onChanged: ctrl.setThemeMode,
          minWidth: 104,
        ),
      ],
    );
  }
}
