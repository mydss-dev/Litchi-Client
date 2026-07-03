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
            // Navigator. Windows uses DWM to clip the final HWND, including all
            // dialogs, modal barriers, bottom sheets and toasts.
            builder: (context, child) {
              final content = child ?? const SizedBox.shrink();
              if (!Platform.isLinux) return content;
              return DesktopRouteClip(child: content);
            },
            // Transparent so the rounded window shell shows through at the
            // clipped corners (§ rounded-window spec).
            //
            // A single responsive shell for every platform: it renders a
            // sidebar layout on wide windows and a bottom-nav layout on narrow
            // ones, chosen by width rather than by platform.
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
/// against its transparent host window. Windows delegates this to native DWM.
class DesktopRouteClip extends StatefulWidget {
  const DesktopRouteClip({super.key, required this.child});

  final Widget child;

  @override
  State<DesktopRouteClip> createState() => _DesktopRouteClipState();
}

class _DesktopRouteClipState extends State<DesktopRouteClip>
    with WindowListener {
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
