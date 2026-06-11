import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

import 'app/app.dart';
import 'config/remote_config.dart';
import 'shared/config/app_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
