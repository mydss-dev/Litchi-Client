import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/app_controller.dart';
import '../../l10n/l10n.dart';
import '../../shared/layout/app_layout.dart';
import '../../shared/layout/app_platform.dart';
import '../../shared/layout/app_shell_spec.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_radius.dart';
import '../../shared/theme/app_spacing.dart';
import '../../shared/theme/app_text_styles.dart';
import '../../shared/widgets/app_select.dart';
import 'change_password_page.dart';
import 'forgot_password_page.dart';
import 'login_page.dart';
import 'register_page.dart';
import 'widgets/auth_brand_panel.dart';

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
    final platform = AppPlatform.current;
    final desktopPresentation =
        AppShellSpec.navigationFor(platform) == AppNavigationMode.sidebar;

    return ColoredBox(
      color: c.appBg,
      child: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final twoPane =
                desktopPresentation &&
                constraints.maxWidth >=
                    AppLayoutMetrics.desktopAuthMinimumWindow.width;

            if (twoPane) {
              final height = constraints.hasBoundedHeight
                  ? (constraints.maxHeight - AppSpacing.xl * 2)
                        .clamp(0.0, double.infinity)
                  : AppLayoutMetrics.desktopAuthLoginHeight;
              return Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: SizedBox(
                  height: height,
                  child: _DesktopAuthLayout(spec: spec, screen: screen),
                ),
              );
            }

            return ScrollConfiguration(
              behavior: ScrollConfiguration.of(context).copyWith(
                scrollbars: desktopPresentation,
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.hasBoundedHeight
                        ? (constraints.maxHeight - AppSpacing.lg * 2)
                              .clamp(0.0, double.infinity)
                        : 0,
                  ),
                  child: _CompactAuthLayout(
                    spec: spec,
                    screen: screen,
                    showPreferences: desktopPresentation,
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

class _DesktopAuthLayout extends StatelessWidget {
  const _DesktopAuthLayout({required this.spec, required this.screen});

  final _AuthSpec spec;
  final AuthScreen screen;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Expanded(
          flex: AppLayoutMetrics.desktopAuthBrandFlex,
          child: AuthBrandPanel(),
        ),
        const SizedBox(width: AppSpacing.xl),
        Expanded(
          flex: AppLayoutMetrics.desktopAuthFormFlex,
          child: LayoutBuilder(
            builder: (context, formConstraints) {
              return ScrollConfiguration(
                behavior: ScrollConfiguration.of(
                  context,
                ).copyWith(scrollbars: true),
                child: SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: formConstraints.maxHeight,
                    ),
                    child: _AuthFormSurface(
                      spec: spec,
                      screen: screen,
                      showPreferences: true,
                      card: false,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CompactAuthLayout extends StatelessWidget {
  const _CompactAuthLayout({
    required this.spec,
    required this.screen,
    required this.showPreferences,
  });

  final _AuthSpec spec;
  final AuthScreen screen;
  final bool showPreferences;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: AppLayoutMetrics.desktopAuthFormMaxWidth,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AuthBrandPanel(compact: true),
            const SizedBox(height: AppSpacing.lg),
            _AuthFormSurface(
              spec: spec,
              screen: screen,
              showPreferences: showPreferences,
              card: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthFormSurface extends StatelessWidget {
  const _AuthFormSurface({
    required this.spec,
    required this.screen,
    required this.showPreferences,
    required this.card,
  });

  final _AuthSpec spec;
  final AuthScreen screen;
  final bool showPreferences;
  final bool card;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final body = ConstrainedBox(
      constraints: const BoxConstraints(
        maxWidth: AppLayoutMetrics.desktopAuthFormMaxWidth,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            spec.title,
            style: AppTextStyles.pageTitle.copyWith(
              color: c.textPrimary,
              fontSize: card ? 24 : 28,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            spec.subtitle,
            style: AppTextStyles.body.copyWith(color: c.textMuted),
          ),
          const SizedBox(height: AppSpacing.xl),
          KeyedSubtree(key: ValueKey(screen), child: spec.child),
          if (showPreferences && screen == AuthScreen.login) ...[
            const SizedBox(height: AppSpacing.xl),
            const _DesktopAuthPreferences(),
          ],
        ],
      ),
    );

    final aligned = Align(alignment: Alignment.center, child: body);
    if (!card) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: aligned,
      );
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: c.cardBg,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: c.softBorder),
      ),
      child: aligned,
    );
  }
}

class _DesktopAuthPreferences extends StatelessWidget {
  const _DesktopAuthPreferences();

  @override
  Widget build(BuildContext context) {
    final ctrl = AppScope.of(context);
    final c = AppColors.of(context);
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.sm,
      children: [
        _PreferenceSelect<AppLocalePreference>(
          icon: LucideIcons.languages,
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
          minWidth: 118,
        ),
        _PreferenceSelect<ThemeMode>(
          icon: Theme.of(context).brightness == Brightness.dark
              ? LucideIcons.moon
              : LucideIcons.sun,
          value: ctrl.themeMode,
          items: const [ThemeMode.system, ThemeMode.light, ThemeMode.dark],
          labelOf: (value) => switch (value) {
            ThemeMode.system => context.l10n.followSystem,
            ThemeMode.light => context.l10n.lightMode,
            ThemeMode.dark => context.l10n.darkMode,
          },
          onChanged: ctrl.setThemeMode,
          minWidth: 110,
        ),
      ],
    );
  }
}

class _PreferenceSelect<T> extends StatelessWidget {
  const _PreferenceSelect({
    required this.icon,
    required this.value,
    required this.items,
    required this.labelOf,
    required this.onChanged,
    required this.minWidth,
  });

  final IconData icon;
  final T value;
  final List<T> items;
  final String Function(T value) labelOf;
  final ValueChanged<T> onChanged;
  final double minWidth;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: c.iconMuted),
        const SizedBox(width: AppSpacing.sm),
        AppSelect<T>(
          value: value,
          items: items,
          labelOf: labelOf,
          onChanged: onChanged,
          minWidth: minWidth,
        ),
      ],
    );
  }
}
