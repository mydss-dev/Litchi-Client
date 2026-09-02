import 'dart:io';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../config/app_config.dart';
import '../l10n/generated/app_localizations.dart';
import '../shared/theme/app_radius.dart';
import '../shared/theme/app_theme.dart';
import 'app_controller.dart';
import 'app_shell.dart';

/// Root widget: owns the [AppController] and rebuilds [MaterialApp] when the
/// theme mode changes.
class LitchiApp extends StatefulWidget {
  const LitchiApp({super.key, this.launchSilently = false});

  final bool launchSilently;

  @override
  State<LitchiApp> createState() => _LitchiAppState();
}

class _LitchiAppState extends State<LitchiApp> {
  final AppController _controller = AppController();

  @override
  void initState() {
    super.initState();
    _controller.init(); // restores token + server URL; notifies when done
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      controller: _controller,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return MaterialApp(
            title: AppConfig.appName,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: _controller.themeMode,
            locale: _controller.locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            // Linux needs a Flutter-owned transparent shape around the entire
            // Navigator. Windows and macOS use their official system shapes.
            builder: (context, child) {
              Widget content = child ?? const SizedBox.shrink();
              if (Platform.isLinux) content = LinuxWindowClip(child: content);
              // The desktop shell is a non-resizable window with a fixed 420px
              // width whose height auto-fits the current page's content. The
              // Windows engine ties MediaQuery.textScaler to the
              // display DPI (125% → 1.25, 150% → 1.5), which inflates every
              // logical text size and clips the home screen on high-DPI machines
              // — the Win10/Win11 mismatch. Pin text scaling to 1.0 so the
              // layout renders identically across machines; DPI still sharpens
              // rendering via devicePixelRatio.
              if (Platform.isWindows ||
                  Platform.isMacOS ||
                  Platform.isLinux) {
                content = MediaQuery.withClampedTextScaling(
                  minScaleFactor: 1.0,
                  maxScaleFactor: 1.0,
                  child: content,
                );
              }
              return content;
            },
            // Transparent so the rounded window shell shows through at the
            // clipped corners (§ rounded-window spec).
            //
            // A single fixed-size shell for every platform: it renders the
            // bottom-nav layout regardless of window width.
            home: Scaffold(
              backgroundColor: Platform.isWindows ? null : Colors.transparent,
              body: AppShell(launchSilently: widget.launchSilently),
            ),
          );
        },
      ),
    );
  }
}

/// Clips the complete Navigator rather than only its home route.
///
/// Modal routes render above [AppShell], so Linux clips the entire Navigator
/// against its transparent host window.
class LinuxWindowClip extends StatefulWidget {
  const LinuxWindowClip({super.key, required this.child});

  final Widget child;

  @override
  State<LinuxWindowClip> createState() => _LinuxWindowClipState();
}

class _LinuxWindowClipState extends State<LinuxWindowClip> with WindowListener {
  bool _maximized = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _readWindowState();
  }

  Future<void> _readWindowState() async {
    try {
      final maximized = await windowManager.isMaximized();
      if (mounted && maximized != _maximized) {
        setState(() => _maximized = maximized);
      }
    } catch (_) {
      // The native plugin is unavailable in widget tests.
    }
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowMaximize() {
    if (!_maximized) setState(() => _maximized = true);
  }

  @override
  void onWindowUnmaximize() {
    if (_maximized) setState(() => _maximized = false);
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(_maximized ? 0 : AppRadius.window),
      clipBehavior: Clip.antiAlias,
      child: widget.child,
    );
  }
}
