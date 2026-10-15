import 'dart:async';
import 'dart:convert';
// dart:ffi also declares a C `Size`; keep it out of this file's namespace.
import 'dart:ffi' hide Size;
import 'dart:io';

import 'package:ffi/ffi.dart';
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
/// (V3WindowBootstrap skips them), and coordinates outside any sane desktop —
/// or frames with no meaningful visible chunk left on any connected monitor
/// (F15) — fall back to the centered default rather than an off-screen window.
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
  // A frame closed on a monitor that has since been disconnected would
  // otherwise restore fully off-screen with no way to reach it (F15): keep
  // only frames that still own a visible chunk of the current desktop.
  if (!_restoredFrameVisible(rect)) return null;
  return rect;
}

/// True when [rect] (logical pixels) would keep a visible 100x100-logical-pixel
/// chunk on at least one currently connected monitor (F15).
///
/// dart:ui cannot answer this portably in the current engine: the
/// [PlatformDispatcher.displays] entries carry no display position at all
/// (id, size, refresh rate only, and the engine docs note Windows desktops
/// report a placeholder). The authoritative desktop layout lives in Win32, so
/// on Windows this asks user32; other desktop platforms keep the lax
/// coordinate guards above.
bool _restoredFrameVisible(Rect rect) {
  if (!Platform.isWindows) return true;
  try {
    // Saved frames are logical (window_manager space); monitors are physical.
    // The implicit view sits on a real monitor by now, so its DPR converts
    // with the setup's dominant scale; mixed-DPI setups skew the probe a
    // little, which the 100px floor tolerates — and a wrongly rejected frame
    // only re-centers once, then the bounds poll re-saves the applied frame.
    final view = WidgetsBinding.instance.platformDispatcher.implicitView;
    final dpr = view?.devicePixelRatio ?? 1.0;
    final minVisible = (100 * dpr).round();
    // The largest-overlap monitor governs the verdict: if even it holds less
    // than the minimum chunk, no other monitor holds more.
    final probe = _Win32Displays.frameVisible(rect, dpr, minVisible);
    return probe ?? true; // unverifiable -> keep the saved frame
  } catch (_) {
    // Restore is a convenience; a failing probe must never break startup.
    return true;
  }
}

/// Minimal user32 surface for the window-placement sanity probe above.
///
/// Mirrors the Win32 FFI conventions of lib/shared/services/windows_*.dart
/// (package:ffi is a direct dependency there and here).
final class _Win32Displays {
  _Win32Displays._();

  static final DynamicLibrary _user32 = DynamicLibrary.open('user32.dll');

  static final _monitorFromRect = _user32
      .lookupFunction<
        Pointer<Void> Function(Pointer<_Win32Rect>, Uint32),
        Pointer<Void> Function(Pointer<_Win32Rect>, int)
      >('MonitorFromRect');

  static final _getMonitorInfoW = _user32
      .lookupFunction<
        Int32 Function(Pointer<Void>, Pointer<_MonitorInfo>),
        int Function(Pointer<Void>, Pointer<_MonitorInfo>)
      >('GetMonitorInfoW');

  /// MONITOR_DEFAULTTONULL: return NULL when the rect touches no monitor.
  static const int _defaultToNull = 0;

  /// True when at least [minVisible] physical pixels in both axes of
  /// [logical] (a window frame in logical coordinates) rest on a connected
  /// monitor. Returns null when the probe could not run (the caller keeps
  /// the frame in that case).
  static bool? frameVisible(Rect logical, double dpr, int minVisible) {
    final frame = calloc<_Win32Rect>()
      ..ref.left = (logical.left * dpr).round()
      ..ref.top = (logical.top * dpr).round()
      ..ref.right = (logical.right * dpr).round()
      ..ref.bottom = (logical.bottom * dpr).round();
    final info = calloc<_MonitorInfo>()..ref.cbSize = sizeOf<_MonitorInfo>();
    try {
      final monitor = _monitorFromRect(frame, _defaultToNull);
      if (monitor == nullptr) return false; // fully off the visible desktop
      if (_getMonitorInfoW(monitor, info) == 0) return null; // cannot verify
      final f = frame.ref;
      final m = info.ref.rcMonitor;
      return _overlap(f.left, f.right, m.left, m.right) >= minVisible &&
          _overlap(f.top, f.bottom, m.top, m.bottom) >= minVisible;
    } finally {
      calloc.free(frame);
      calloc.free(info);
    }
  }

  /// Size of the overlap of [aStart]..[aEnd] and [bStart]..[bEnd] on one axis.
  static int _overlap(int aStart, int aEnd, int bStart, int bEnd) {
    final start = aStart > bStart ? aStart : bStart;
    final end = aEnd < bEnd ? aEnd : bEnd;
    return end > start ? end - start : 0;
  }
}

final class _Win32Rect extends Struct {
  @Int32()
  external int left;
  @Int32()
  external int top;
  @Int32()
  external int right;
  @Int32()
  external int bottom;
}

/// Win32 MONITORINFO: cbSize, rcMonitor, rcWork, dwFlags (40 bytes).
final class _MonitorInfo extends Struct {
  @Uint32()
  external int cbSize;
  external _Win32Rect rcMonitor;
  external _Win32Rect rcWork;
  @Uint32()
  external int dwFlags;
}
