import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

import 'app/app.dart';
import 'config/remote_config.dart';
import 'shared/config/app_config.dart';

bool get _isDesktop => Platform.isWindows || Platform.isMacOS || Platform.isLinux;

// Held open for the process lifetime — binding this port prevents a second
// instance from starting. Automatically released when the process exits.
ServerSocket? _instanceLock;

void _writeCrashLog(String message) {
  try {
    final base = Platform.environment['LOCALAPPDATA'] ??
        Platform.environment['APPDATA'] ??
        Directory.systemTemp.path;
    final file = File('$base${Platform.pathSeparator}Litchi${Platform.pathSeparator}crash.log');
    file.parent.createSync(recursive: true);
    final ts = DateTime.now().toLocal().toString().substring(0, 19);
    file.writeAsStringSync('[$ts] $message\n\n', mode: FileMode.append);
  } catch (_) {}
}

Future<void> main() {
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    _writeCrashLog('FlutterError: ${details.exceptionAsString()}\n${details.stack}');
  };
  return runZonedGuarded(_boot, (error, stack) {
    _writeCrashLog('Uncaught: $error\n$stack');
  }) ?? Future.value();
}

Future<void> _boot() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Single source of truth for the version: the installed package metadata
  // (pubspec version), not a dart-define default. Keeps the update check honest.
  try {
    final info = await PackageInfo.fromPlatform();
    AppConfig.setVersion(info.version);
  } catch (_) {}

  if (_isDesktop) {
    // Single-instance enforcement: bind a loopback port as a mutex.
    // If the port is already taken, another instance is running — ping it so it
    // surfaces its window, then exit. This makes re-launching the desktop icon
    // (while we're hidden in the tray) bring the existing window to the front.
    try {
      _instanceLock = await ServerSocket.bind(
        InternetAddress.loopbackIPv4,
        54891,
        shared: false,
      );
    } catch (_) {
      try {
        final ping = await Socket.connect(
          InternetAddress.loopbackIPv4,
          54891,
          timeout: const Duration(seconds: 2),
        );
        ping.destroy();
      } catch (_) {}
      exit(0);
    }

    await windowManager.ensureInitialized();

    // Any later instance that pings the lock port asks us to show ourselves.
    _instanceLock!.listen((client) {
      client.destroy();
      unawaited(windowManager.show());
      unawaited(windowManager.focus());
    });
  }

  // Load remote config from cache before the window appears so the first
  // frame already has the correct branding / API base URL.
  final prefs = await SharedPreferences.getInstance();
  await RemoteConfigService.initialize(prefs);

  if (!_isDesktop) {
    runApp(const LitchiApp());
    return;
  }

  final windowOptions = WindowOptions(
    size: const Size(900, 700),
    minimumSize: const Size(900, 700),
    center: true,
    backgroundColor: Colors.transparent,
    titleBarStyle: TitleBarStyle.hidden,
    title: AppConfig.appName,
  );

  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.setResizable(false);
    await windowManager.setMaximizable(true);
    await windowManager.setBackgroundColor(Colors.transparent);
    await windowManager.setAsFrameless();
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(const LitchiApp());
}
