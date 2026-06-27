import 'dart:io';

import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../shared/theme/app_theme.dart';
import 'app_controller.dart';
import 'app_shell.dart';
import 'mobile_app_shell.dart';

bool get _isDesktop => Platform.isWindows || Platform.isMacOS || Platform.isLinux;

/// Root widget: owns the [AppController] and rebuilds [MaterialApp] when the
/// theme mode changes.
class LitchiApp extends StatefulWidget {
  const LitchiApp({super.key});

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
            title: '${AppConfig.appName} Client',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: _controller.themeMode,
            // Transparent so the rounded window shell shows through at the
            // clipped corners (§ rounded-window spec).
            home: Scaffold(
              backgroundColor: Colors.transparent,
              body: _isDesktop ? const AppShell() : const MobileAppShell(),
            ),
          );
        },
      ),
    );
  }
}
