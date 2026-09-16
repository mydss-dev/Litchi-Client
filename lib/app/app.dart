import 'dart:io';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../config/app_config.dart';
import '../l10n/generated/app_localizations.dart';
import '../shared/theme/app_radius.dart';
import '../v3/app/v3_shell.dart';
import '../v3/app/v3_window_bootstrap.dart';
import '../v3/theme/v3_palette.dart';
import 'app_controller.dart';

/// Root widget for Litchi V3.
///
/// Business state remains in [AppController], while every rendered product
/// surface comes from the isolated V3 visual layer under `lib/v3/`.
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
    _controller.init();
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
            theme: V3Theme.light(),
            darkTheme: V3Theme.dark(),
            themeMode: _controller.themeMode,
            locale: _controller.locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) {
              Widget content = child ?? const SizedBox.shrink();
              if (Platform.isLinux) content = LinuxWindowClip(child: content);
              if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
                content = MediaQuery.withClampedTextScaling(
                  minScaleFactor: 1.0,
                  maxScaleFactor: 1.0,
                  child: content,
                );
              }
              return content;
            },
            home: Scaffold(
              backgroundColor: Platform.isWindows ? null : Colors.transparent,
              body: V3WindowBootstrap(
                child: V3Shell(launchSilently: widget.launchSilently),
              ),
            ),
          );
        },
      ),
    );
  }
}

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
      // Native plugin can be unavailable in widget tests.
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
