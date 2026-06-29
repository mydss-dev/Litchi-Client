import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

import 'app/app.dart';
import 'config/remote_config.dart';
import 'config/app_config.dart';
import 'shared/services/brand_asset_cache.dart';
import 'shared/services/secure_logger.dart';

bool get _isDesktop => Platform.isWindows || Platform.isMacOS || Platform.isLinux;

const int _instanceLockPort = 54891;
const String _instancePing = 'LITCHI_FOCUS_V1';
const String _instancePong = 'LITCHI_FOCUS_OK_V1';

// Held open for the process lifetime — binding this port prevents a second
// instance from starting. Automatically released when the process exits.
ServerSocket? _instanceLock;

void _writeCrashLog(String message) {
  try {
    final base = Platform.environment['LOCALAPPDATA'] ??
        Platform.environment['APPDATA'] ??
        Directory.systemTemp.path;
    final file = File(
      '$base${Platform.pathSeparator}Litchi${Platform.pathSeparator}crash.log',
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
    final response = await _socketLines(socket)
        .first
        .timeout(const Duration(seconds: 1), onTimeout: () => '');
    return response.trim() == _instancePong;
  } catch (_) {
    // intentional: instance check, treat as not found
    return false;
  } finally {
    socket?.destroy();
  }
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
  } catch (e) {
    SecureLogger.debug('PackageInfo.fromPlatform failed', e);
  }

  if (_isDesktop) {
    // Single-instance enforcement: bind a loopback port as a mutex.
    // If the port is already taken, only treat it as another Litchi instance
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
        'Single-instance lock port $_instanceLockPort is occupied by a non-Litchi process.',
      );
      exit(1);
    }

    await windowManager.ensureInitialized();

    // Any later instance that pings the lock port asks us to show ourselves.
    _instanceLock!.listen((client) async {
      try {
        final line = await _socketLines(client)
            .first
            .timeout(const Duration(seconds: 1), onTimeout: () => '');
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

  assert(() {
    final hasApiBase = AppConfig.effectiveApiBases
        .map((e) => e.trim())
        .any((e) => e.startsWith('https://'));
    if (!hasApiBase && !RemoteConfigService.isConfigured) {
      SecureLogger.debug(
        '开发配置缺失：请通过 --dart-define=API_BASE=https://your-panel.com '
        '或 --dart-define=REMOTE_CONFIG_URL=https://your-oss/config.json '
        '+ --dart-define=REMOTE_CONFIG_PUBLIC_KEY=xxx 启动，否则客户端会是空壳。',
      );
    }
    return true;
  }());

  await BrandAssetCache.initialize();

  if (!_isDesktop) {
    runApp(const LitchiApp());
    return;
  }

  // macOS keeps its native window (traffic lights, native rounded corners +
  // shadow); only the hidden title bar lets content run full-height. Windows /
  // Linux go fully frameless + transparent and draw custom window controls.
  final windowOptions = WindowOptions(
    size: const Size(900, 700),
    // Small floor so the shell can shrink the window to a compact card-sized
    // login window (see _AppShellState._syncWindowSize). User resize stays off
    // via setResizable(false); this only gates programmatic setSize.
    minimumSize: const Size(380, 480),
    center: true,
    backgroundColor: Platform.isMacOS ? null : Colors.transparent,
    titleBarStyle: TitleBarStyle.hidden,
    title: AppConfig.appName,
  );

  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.setResizable(false);
    await windowManager.setMaximizable(true);
    if (!Platform.isMacOS) {
      await windowManager.setBackgroundColor(Colors.transparent);
      await windowManager.setAsFrameless();
    }
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(const LitchiApp());
}
