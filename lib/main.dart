import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

import 'app/app.dart';
import 'config/app_launch_options.dart';
import 'config/app_identity.dart';
import 'config/remote_config.dart';
import 'config/app_config.dart';
import 'shared/services/app_paths.dart';
import 'shared/services/brand_asset_cache.dart';
import 'shared/services/secure_logger.dart';
import 'v3/app/v3_window_bootstrap.dart';

bool get _isDesktop =>
    Platform.isWindows || Platform.isMacOS || Platform.isLinux;

int get _instanceLockPort => AppIdentity.instanceLockPort;
String get _instancePing => AppIdentity.instancePing;
String get _instancePong => AppIdentity.instancePong;

// Held open for the process lifetime — binding this port prevents a second
// instance from starting. Automatically released when the process exits.
ServerSocket? _instanceLock;

void _writeCrashLog(String message) {
  try {
    final file = File(
      '${AppPaths.dataDirectory}${Platform.pathSeparator}crash.log',
    );
    file.parent.createSync(recursive: true);
    // Keep the log from growing without bound.
    if (file.existsSync() && file.lengthSync() > 512 * 1024) {
      file.writeAsStringSync('');
    }
    final ts = DateTime.now().toLocal().toString().substring(0, 19);
    final safeMessage = SecureLogRedactor.redact(message);
    file.writeAsStringSync('[$ts] $safeMessage\n\n', mode: FileMode.append);
  } catch (_) {
    // intentional: best-effort crash log, failure is safe to ignore
  }
}

Stream<String> _socketLines(Socket socket) => socket
    .map<List<int>>((chunk) => chunk)
    .transform(utf8.decoder)
    .transform(const LineSplitter());

Future<bool> _focusExistingInstance() async {
  Socket? socket;
  try {
    socket = await Socket.connect(
      InternetAddress.loopbackIPv4,
      _instanceLockPort,
      timeout: const Duration(seconds: 2),
    );
    socket.writeln(_instancePing);
    await socket.flush();
    final response = await _socketLines(
      socket,
    ).first.timeout(const Duration(seconds: 1), onTimeout: () => '');
    return response.trim() == _instancePong;
  } catch (_) {
    // intentional: instance check, treat as not found
    return false;
  } finally {
    socket?.destroy();
  }
}

Future<void> main(List<String> arguments) {
  final launchOptions = AppLaunchOptions.parse(arguments);
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    _writeCrashLog(
      'FlutterError: ${details.exceptionAsString()}\n${details.stack}',
    );
  };
  return runZonedGuarded(() => _boot(launchOptions), (error, stack) {
        _writeCrashLog('Uncaught: $error\n$stack');
      }) ??
      Future.value();
}

Future<void> _boot(AppLaunchOptions launchOptions) async {
  WidgetsFlutterBinding.ensureInitialized();

  // Single source of truth for the version: the installed package metadata
  // (pubspec version), not a dart-define default. Keeps the update check honest.
  try {
    final info = await PackageInfo.fromPlatform();
    AppConfig.setVersion(info.version);
  } catch (e) {
    SecureLogger.debug('PackageInfo.fromPlatform failed', e);
  }

  if (_isDesktop) {
    // Single-instance enforcement: bind a loopback port as a mutex.
    // If the port is already taken, only treat it as another client instance
    // after a tiny authenticated handshake. This avoids silently exiting when
    // some unrelated local process happens to occupy the same port.
    try {
      _instanceLock = await ServerSocket.bind(
        InternetAddress.loopbackIPv4,
        _instanceLockPort,
        shared: false,
      );
    } catch (_) {
      // intentional: port already in use, falls through to focus existing
      if (await _focusExistingInstance()) exit(0);
      _writeCrashLog(
        'Single-instance lock port $_instanceLockPort is occupied by another process.',
      );
      exit(1);
    }

    await windowManager.ensureInitialized();

    // Any later instance that pings the lock port asks us to show ourselves.
    _instanceLock!.listen((client) async {
      try {
        final line = await _socketLines(
          client,
        ).first.timeout(const Duration(seconds: 1), onTimeout: () => '');
        if (line.trim() == _instancePing) {
          client.writeln(_instancePong);
          await client.flush();
          unawaited(windowManager.show());
          unawaited(windowManager.focus());
        }
      } catch (_) {
        // intentional: best-effort window focus, failure is safe to ignore
      } finally {
        client.destroy();
      }
    });
  }

  // Load remote config from cache before the window appears so the first
  // frame already has the correct branding / API base URL.
  final prefs = await SharedPreferences.getInstance();
  await RemoteConfigService.initialize(prefs);

  await BrandAssetCache.initialize();

  if (!_isDesktop) {
    runApp(const LitchiApp());
    return;
  }

  // macOS keeps its native window (traffic lights, native rounded corners +
  // shadow); only the hidden title bar lets content run full-height. Windows /
  // Linux uses a transparent Flutter clip. Windows stays opaque and lets the
  // native runner shape the window, avoiding black transparent corner pixels.
  // One size for the window's whole life: the native runner surface, the
  // first Dart frame and the workspace all agree on 900x700, so no launch
  // resize is ever visible. Growing 400x560 -> 900x700 after the first frame
  // painted a jump on every start; shrinking a large surface is what risks
  // the duplicated-frame ghost on Windows with DPI scale, and this
  // choreography never shrinks.
  final windowOptions = WindowOptions(
    size: const Size(900, 700),
    // The 900x700 acceptance floor is also the minimum: the desktop rail plus
    // the page breakpoints are tuned to the pane this leaves.
    minimumSize: const Size(900, 700),
    center: true,
    backgroundColor: Platform.isLinux ? Colors.transparent : null,
    titleBarStyle: TitleBarStyle.hidden,
    title: AppConfig.appName,
  );

  // Last session's frame, restored before the window shows so returning
  // users never see a centered default jump to their saved spot.
  final savedWindowBounds = _loadSavedWindowBounds(prefs);

  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    // Keep the native resize frame: drag borders, Snap and the Win11 DWM
    // treatment hang off WS_THICKFRAME. The 900x700 minimum above is the
    // actual size contract; setResizable(false) stripped the borders while
    // the window stayed maximizable, contradicting it.
    await windowManager.setResizable(true);
    await windowManager.setMaximizable(true);
    if (savedWindowBounds != null) {
      try {
        await windowManager.setBounds(savedWindowBounds);
      } catch (_) {
        // Restore is a convenience; the centered default is always valid.
      }
    }
    if (Platform.isLinux) {
      await windowManager.setBackgroundColor(Colors.transparent);
      await windowManager.setAsFrameless();
    } else if (Platform.isWindows) {
      // Use a hidden title bar while retaining the native window frame.
      // setAsFrameless(). This leaves the standard Win32/DWM frame available
      // for official Windows 11 corners and shadows.
      await windowManager.setHasShadow(true);
    }
    if (!launchOptions.silent) {
      await windowManager.show();
      await windowManager.focus();
    }
  });

  runApp(LitchiApp(launchSilently: launchOptions.silent));
}

/// Last session's window frame as "left,top,width,height", or null when
/// absent or implausible. Maximised sessions never save their oversized rect
/// (V3WindowBootstrap skips them), and coordinates outside any sane desktop
/// fall back to the centered default rather than an off-screen window.
Rect? _loadSavedWindowBounds(SharedPreferences prefs) {
  final raw = prefs.getString(kV3WindowBoundsPref);
  if (raw == null) return null;
  final parts = raw.split(',');
  if (parts.length != 4) return null;
  final values = parts.map(double.tryParse).toList();
  if (values.any((v) => v == null)) return null;
  final rect = Rect.fromLTWH(values[0]!, values[1]!, values[2]!, values[3]!);
  if (rect.width < 900 || rect.height < 700) return null;
  if (rect.left < -200 || rect.top < -200) return null;
  if (rect.left > 20000 || rect.top > 20000) return null;
  return rect;
}
