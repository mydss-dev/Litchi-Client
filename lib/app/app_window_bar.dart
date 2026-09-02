import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:window_manager/window_manager.dart';

import '../config/app_config.dart';
import '../l10n/l10n.dart';
import '../shared/theme/app_colors.dart';
import '../shared/theme/app_radius.dart';
import '../shared/theme/app_shadows.dart';
import '../shared/theme/app_text_styles.dart';
import '../shared/widgets/brand_logo.dart';
import 'app_controller.dart';

/// Compact branded title bar with native-like window controls.
///
/// The whole brand area remains draggable and supports double-click maximize.
class WindowControlsBar extends StatefulWidget {
  const WindowControlsBar({super.key, this.height = 46, this.leading});

  final double height;

  /// Optional widget (e.g. a drawer hamburger button) shown before the brand.
  final Widget? leading;

  @override
  State<WindowControlsBar> createState() => _WindowControlsBarState();
}

class _WindowControlsBarState extends State<WindowControlsBar>
    with WindowListener {
  bool _maximized = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _sync();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  Future<void> _sync() async {
    final m = await windowManager.isMaximized();
    if (mounted) setState(() => _maximized = m);
  }

  @override
  void onWindowMaximize() => setState(() => _maximized = true);

  @override
  void onWindowUnmaximize() => setState(() => _maximized = false);

  Future<void> _toggleMaximize() async {
    if (await windowManager.isMaximized()) {
      unawaited(windowManager.unmaximize());
    } else {
      unawaited(windowManager.maximize());
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: Row(
        children: [
          ?widget.leading,
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onPanStart: (_) => windowManager.startDragging(),
              onDoubleTap: _toggleMaximize,
              child: const Padding(
                padding: EdgeInsets.only(left: 18),
                child: BrandTitle(),
              ),
            ),
          ),
          _WindowButton(
            icon: LucideIcons.minus,
            onTap: () => windowManager.minimize(),
          ),
          _WindowButton(
            icon: _maximized ? LucideIcons.copy : LucideIcons.square,
            iconSize: _maximized ? 12 : 13,
            onTap: _toggleMaximize,
          ),
          _WindowButton(
            icon: LucideIcons.x,
            isClose: true,
            onTap: () => windowManager.close(),
          ),
          const SizedBox(width: 12),
        ],
      ),
    );
  }
}

class MacTitleBar extends StatelessWidget {
  const MacTitleBar({super.key, this.leading});

  /// Optional widget (e.g. a drawer hamburger button) shown before the brand.
  final Widget? leading;

  Future<void> _toggleMaximize() async {
    if (await windowManager.isMaximized()) {
      await windowManager.unmaximize();
    } else {
      await windowManager.maximize();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onPanStart: (_) => windowManager.startDragging(),
      onDoubleTap: _toggleMaximize,
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: c.appBg,
          border: Border(
            bottom: BorderSide(color: c.softBorder.withValues(alpha: 0.72)),
          ),
        ),
        child: Row(
          children: [
            ?leading,
            const Expanded(
              child: Center(child: IgnorePointer(child: BrandTitle())),
            ),
            // Balance the leading button's width so the brand stays centred.
            if (leading != null) const SizedBox(width: 42),
          ],
        ),
      ),
    );
  }
}

class MobileTitleBar extends StatelessWidget {
  const MobileTitleBar({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return SizedBox(
      height: 56,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: c.cardGradient,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: c.softBorder),
            boxShadow: AppShadows.soft(c),
          ),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Expanded(child: BrandTitle()),
                _TitleActionsGroup(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class BrandTitle extends StatelessWidget {
  const BrandTitle({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const BrandLogo(size: 24, radius: 7),
        const SizedBox(width: 7),
        Flexible(
          child: Text(
            AppConfig.appName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.sectionTitle.copyWith(
              color: AppColors.of(context).primary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _ThemeTitleAction extends StatelessWidget {
  const _ThemeTitleAction();

  @override
  Widget build(BuildContext context) {
    final ctrl = AppScope.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Tooltip(
      message: dark ? context.l10n.lightMode : context.l10n.darkMode,
      child: _TitleActionSurface(
        icon: dark ? LucideIcons.sun : LucideIcons.moon,
        onTap: () => ctrl.setThemeMode(dark ? ThemeMode.light : ThemeMode.dark),
      ),
    );
  }
}

class _LanguageTitleAction extends StatelessWidget {
  const _LanguageTitleAction();

  @override
  Widget build(BuildContext context) {
    final ctrl = AppScope.of(context);
    final c = AppColors.of(context);
    final l10n = context.l10n;
    return PopupMenuButton<AppLocalePreference>(
      initialValue: ctrl.language,
      tooltip: l10n.language,
      position: PopupMenuPosition.under,
      color: c.cardBg,
      surfaceTintColor: Colors.transparent,
      onSelected: ctrl.setLanguage,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(color: c.softBorder),
      ),
      itemBuilder: (context) => [
        for (final language in AppLocalePreference.values)
          PopupMenuItem(
            value: language,
            child: Row(
              children: [
                Expanded(
                  child: Text(switch (language) {
                    AppLocalePreference.system => l10n.followSystem,
                    AppLocalePreference.simplifiedChinese =>
                      l10n.simplifiedChinese,
                    AppLocalePreference.traditionalChinese =>
                      l10n.traditionalChinese,
                    AppLocalePreference.english => l10n.english,
                  }),
                ),
                if (ctrl.language == language)
                  Icon(LucideIcons.check, size: 16, color: c.primary),
              ],
            ),
          ),
      ],
      child: const _TitleActionSurface(icon: LucideIcons.languages),
    );
  }
}

class _TitleActionsGroup extends StatelessWidget {
  const _TitleActionsGroup();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ThemeTitleAction(),
        SizedBox(width: 6),
        _LanguageTitleAction(),
      ],
    );
  }
}

class _TitleActionSurface extends StatelessWidget {
  const _TitleActionSurface({required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Center(
            child: Ink(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: c.surfaceMuted,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(icon, size: 17, color: c.iconDefault),
            ),
          ),
        ),
      ),
    );
  }
}

class _WindowButton extends StatefulWidget {
  const _WindowButton({
    required this.icon,
    required this.onTap,
    this.isClose = false,
    this.iconSize = 14,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool isClose;
  final double iconSize;

  @override
  State<_WindowButton> createState() => _WindowButtonState();
}

class _WindowButtonState extends State<_WindowButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final Color bg;
    final Color iconColor;
    if (_hover) {
      bg = widget.isClose ? c.dangerSoft : c.surfaceMuted;
      iconColor = widget.isClose ? c.danger : c.textPrimary;
    } else {
      bg = Colors.transparent;
      iconColor = c.iconDefault;
    }

    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(AppRadius.xs),
            ),
            child: Icon(widget.icon, size: widget.iconSize, color: iconColor),
          ),
        ),
      ),
    );
  }
}
