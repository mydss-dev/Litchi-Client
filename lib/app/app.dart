import 'dart:io';

import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../l10n/generated/app_localizations.dart';
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
