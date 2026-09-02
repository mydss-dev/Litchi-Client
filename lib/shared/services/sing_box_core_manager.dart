import 'dart:async';
import 'dart:io';

import 'clash_api_client.dart';
import 'core_state.dart';
import 'sing_box_config.dart';
import 'sing_box_ffi.dart';
import 'windows_core_process_manager.dart';

/// Manages the sing-box desktop runtime.
///
/// Windows intentionally uses an isolated `litchi-core.exe` process so TUN,
/// Wintun and the Go runtime can never crash the Flutter host. macOS/Linux keep
/// the existing in-process C ABI bridge.
final class SingBoxCoreManager {
  CoreState _state = CoreState.stopped;
  String _lastError = '';
  SingBoxFfi? _core;
  final WindowsCoreProcessManager _windows = WindowsCoreProcessManager();
  StreamSubscription<String>? _windowsLogSub;
  StreamSubscription<String>? _windowsExitSub;

  final _stateController = StreamController<CoreState>.broadcast();
  final _logController = StreamController<String>.broadcast();

  CoreState get state => _state;
  String get lastError => _lastError;
  bool get _backendRunning =>
      Platform.isWindows ? _windows.isRunning : (_core?.isRunning ?? false);
  bool get isRunning => _state == CoreState.running && _backendRunning;
  Stream<CoreState> get stateStream => _stateController.stream;
  Stream<String> get logStream => _logController.stream;

  static String? findLibrary() {
    if (Platform.isWindows) return WindowsCoreProcessManager.findExecutable();
    for (final path in SingBoxFfi.libraryCandidates()) {
      if (File(path).existsSync()) return path;
    }
    return null;
  }

  static Future<void> cleanupOnStartup() async {
    await SingBoxConfig.cleanupStaleConfigFiles();
  }

  Future<void> start(
    String configPath, {
    int apiPort = SingBoxConfig.defaultApiPort,
    bool elevateMacTun = false,
    bool elevateWindowsTun = false,
  }) async {
    if (_state == CoreState.starting || isRunning) return;
    _lastError = '';
    _setState(CoreState.starting);
    _emitLog('── sing-box 启动中 ──');

    final configFile = File(configPath);
    try {
      if (Platform.isWindows) {
        _ensureWindowsSubscriptions();
        final started = await _windows.start(
          configPath,
          elevate: elevateWindowsTun,
          apiPort: apiPort,
        );
        if (!started) {
          _fail(
            _windows.lastError.isEmpty
                ? 'Windows sing-box 独立核心启动失败'
                : _windows.lastError,
          );
          return;
        }
        final ready = await _waitForApi(apiPort);
        if (!ready) {
          final processError = _windows.lastError;
          await _windows.stop();
          _fail(
            processError.isEmpty
                ? 'sing-box 控制接口启动超时（端口 $apiPort）'
                : processError,
          );
          return;
        }
        _emitLog('── sing-box 运行中 (${await _windows.version()}) ──');
        _setState(CoreState.running);
        return;
      }

      final config = await configFile.readAsString();
      _core ??= SingBoxFfi.tryLoad();
      final core = _core;
      if (core == null) {
        _fail(SingBoxFfi.loadError);
        return;
      }
      if (elevateMacTun && Platform.isMacOS) {
        _emitLog('macOS TUN 正在使用进程内 sing-box；应用需要具备相应网络权限');
      }
      if (!core.checkConfig(config)) {
        _fail('sing-box 配置无效：${core.lastError()}');
        return;
      }
      if (!core.start(config)) {
        _fail(core.lastError().isEmpty ? 'sing-box 启动失败' : core.lastError());
        return;
      }
      final ready = await _waitForApi(apiPort);
      if (!ready) {
        final nativeError = core.lastError();
        core.stop();
        _fail(
          nativeError.isEmpty ? 'sing-box 控制接口启动超时（端口 $apiPort）' : nativeError,
        );
        return;
      }
      _emitLog('── sing-box 运行中 (${core.version()}) ──');
      _setState(CoreState.running);
    } catch (error) {
      if (Platform.isWindows) {
        await _windows.stop();
      } else {
        _core?.stop();
      }
      _fail('sing-box 启动异常：$error');
    } finally {
      try {
        if (await configFile.exists()) await configFile.delete();
      } catch (_) {
        // One-time configuration cleanup is best effort.
      }
    }
  }

  Future<void> stop() async {
    _lastError = '';
    final stopped = Platform.isWindows
        ? await _windows.stop()
        : (_core?.stop() ?? true);
    ClashApiClient.resetClient();
    if (!stopped) {
      _fail(
        Platform.isWindows
            ? (_windows.lastError.isEmpty
                  ? 'Windows sing-box 独立核心停止失败'
                  : _windows.lastError)
            : (_core?.lastError() ?? 'sing-box 停止失败'),
      );
      return;
    }
    _emitLog('── sing-box 已停止 ──');
    _setState(CoreState.stopped);
  }

  Future<String> version() async {
    if (Platform.isWindows) return _windows.version();
    _core ??= SingBoxFfi.tryLoad();
    return _core?.version() ?? '';
  }

  void dispose() {
    unawaited(_windowsLogSub?.cancel());
    unawaited(_windowsExitSub?.cancel());
    _windows.dispose();
    _core?.stop();
    if (!_stateController.isClosed) _stateController.close();
    if (!_logController.isClosed) _logController.close();
  }

  Future<bool> _waitForApi(int port) async {
    for (var attempt = 0; attempt < 40; attempt++) {
      if (!_backendRunning) return false;
      if (await ClashApiClient.isReady(apiPort: port)) return true;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    return false;
  }

  void _ensureWindowsSubscriptions() {
    _windowsLogSub ??= _windows.logStream.listen(_emitLog);
    _windowsExitSub ??= _windows.exitStream.listen((error) {
      if (_state != CoreState.running && _state != CoreState.starting) return;
      _lastError = error;
      _emitLog(error);
      _setState(CoreState.error);
    });
  }

  void _fail(String message) {
    _lastError = message;
    _emitLog(message);
    _setState(CoreState.error);
  }

  void _setState(CoreState value) {
    _state = value;
    if (!_stateController.isClosed) _stateController.add(value);
  }

  void _emitLog(String value) {
    if (!_logController.isClosed) _logController.add(value);
  }
}
