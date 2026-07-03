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

  assert(() {
    final hasApiBase = AppConfig.effectiveApiBases
        .map((e) => e.trim())
        .any((e) => e.startsWith('https://'));
    if (!hasApiBase && !RemoteConfigService.isConfigured) {
      SecureLogger.debug(
        '开发配置缺失：请设置 API_BASE 或完整远程配置。'
        '示例：--dart-define=API_BASE=https://your-panel.com；'
        '如使用远程配置，需要同时设置 REMOTE_CONFIG_URL 和 '
        'REMOTE_CONFIG_PUBLIC_KEY。否则客户端会是连不上的空壳。',
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
  // Linux uses a transparent Flutter clip. Windows stays opaque and lets the
  // native runner shape the window, avoiding black transparent corner pixels.
  final windowOptions = WindowOptions(
    // Match the first logged-out frame. Starting large and shrinking after
    // Flutter paints can leave a duplicated surface on Windows with DPI scale.
    size: const Size(400, 560),
    // Small floor so the shell can shrink the window to a compact card-sized
    // login window (see _AppShellState._syncWindowSize). User resize stays off
    // via setResizable(false); this only gates programmatic setSize.
    minimumSize: const Size(380, 480),
    center: true,
    backgroundColor: Platform.isLinux
        ? Colors.transparent
        : Platform.isWindows
        ? const Color(0xFFF7F9FC)
        : null,
    titleBarStyle: TitleBarStyle.hidden,
    title: AppConfig.appName,
  );

  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.setResizable(false);
    await windowManager.setMaximizable(true);
    if (Platform.isLinux) {
      await windowManager.setBackgroundColor(Colors.transparent);
      await windowManager.setAsFrameless();
    } else if (Platform.isWindows) {
      await windowManager.setAsFrameless();
      // The opaque native runner owns one exact 18-DIP window region on
      // Windows 10 and 11. DWM remains responsible only for the outer shadow.
      await windowManager.setHasShadow(true);
    }
    if (!launchOptions.silent) {
      await windowManager.show();
      await windowManager.focus();
    }
  });

  runApp(LitchiApp(launchSilently: launchOptions.silent));
}
