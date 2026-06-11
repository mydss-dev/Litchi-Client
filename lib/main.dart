import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

import 'app/app.dart';
import 'config/remote_config.dart';
import 'shared/config/app_config.dart';

// Held open for the process lifetime — binding this port prevents a second
// instance from starting. Automatically released when the process exits.
// ignore: unused_element
ServerSocket? _instanceLock;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Single-instance enforcement: bind a loopback port as a mutex.
  // If the port is already taken, another instance is running — exit early.
  try {
    _instanceLock = await ServerSocket.bind(
      InternetAddress.loopbackIPv4,
      54891,
      shared: false,
    );
  } catch (_) {
    exit(0);
  }

  await windowManager.ensureInitialized();

  // Load remote config from cache before the window appears so the first
  // frame already has the correct branding / API base URL.
  final prefs = await SharedPreferences.getInstance();
  await RemoteConfigService.initialize(prefs);

  final windowOptions = WindowOptions(
    size: const Size(900, 700),
    minimumSize: const Size(900, 700),
    center: true,
    backgroundColor: Colors.transparent,
    titleBarStyle: TitleBarStyle.hidden,
    title: '${AppConfig.appName} Client',
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
