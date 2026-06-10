import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'app/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  // Frameless window. Default 900×700 (1:1 with the design); can't be shrunk
  // or edge-dragged smaller, but the title-bar maximize button works (matches
  // the design's — □ ✕ controls).
  const windowOptions = WindowOptions(
    size: Size(900, 700),
    minimumSize: Size(900, 700),
    center: true,
    backgroundColor: Colors.transparent,
    titleBarStyle: TitleBarStyle.hidden,
    title: 'Litchi Client',
  );

  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.setResizable(false);
    await windowManager.setMaximizable(true);
    // Transparent background so the rounded shell shows desktop at the corners.
    await windowManager.setBackgroundColor(Colors.transparent);
    // Remove the native window frame entirely — otherwise the left/right resize
    // borders show a dark line through the transparent background.
    await windowManager.setAsFrameless();
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(const LitchiApp());
}
