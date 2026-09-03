import 'dart:async';
import 'dart:io';

import 'clash_api_client.dart';
import 'core_state.dart';
import 'sing_box_config.dart';
import 'sing_box_ffi.dart';
import 'windows_core_process_manager.dart';
import 'windows_tun_service_manager.dart';

/// Manages the sing-box desktop runtime.
///
/// Windows keeps the main sing-box process unprivileged and isolated from the
/// Flutter host. TUN is a separate persistent privileged service that forwards
/// packets into this main core, so enabling/disabling TUN never restarts node,
/// DNS, selector or Clash API state. macOS/Linux keep the C ABI bridge.
final class SingBoxCoreManager {
  CoreState _state = CoreState.stopped;
  String _lastError = '';
  SingBoxFfi? _core;
  final WindowsCoreProcessManager _windows = WindowsCoreProcessManager();
  final WindowsTunServiceManager _windowsTun = WindowsTunServiceManager();
  StreamSubscription<String>? _windowsLogSub;
  StreamSubscription<String>? _windowsExitSub;

  final _stateController = StreamController<CoreState>.broadcast();
  final _logController = StreamController<String>.broadcast();

  CoreState get state => _state;
  String get lastError => _lastError;
  bool get _backendRunning =>
      Platform.isWindows ? _windows.isRunning : (_core?.isRunning ?? false);
  bool get isRunning => _state == CoreState.running && _backendRunning;
  bool get windowsTunRunning => Platform.isWindows && _windowsTun.isRunning;
  Stream<CoreState> get stateStream => _stateController.stream;
  Stream<String> get logStream => _logController.stream;
  Stream<String> get windowsTunExitStream => _windowsTun.exitStream;

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

  Future<void> cleanupWindowsTunOnStartup() async {
    if (Platform.isWindows) await _windowsTun.cleanupOnStartup();
  }

  Future<void> start(
    String configPath, {
    int apiPort = SingBoxConfig.defaultApiPort,
    bool elevateMacTun = false,
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
        await _windowsTun.stop();
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

  Future<bool> startWindowsTun({
    required int mainProxyPort,
    int mtu = 1500,
    bool strictRoute = false,
    String stack = 'system',
  }) async {
    if (!Platform.isWindows || !isRunning) {
      _lastError = 'Windows TUN 启动前主核心必须处于运行状态';
      return false;
    }
    final started = await _windowsTun.start(
      mainProxyPort: mainProxyPort,
      mtu: mtu,
      strictRoute: strictRoute,
      stack: stack,
    );
    if (!started) {
      _lastError = _windowsTun.lastError.isEmpty
          ? 'Windows TUN 服务启动失败'
          : _windowsTun.lastError;
      _emitLog(_lastError);
      return false;
    }
    _emitLog('── Windows TUN 服务运行中 ──');
    return true;
  }

  Future<bool> stopWindowsTun() async {
    if (!Platform.isWindows) return true;
    final hadTun = _windowsTun.isRunning;
    final stopped = await _windowsTun.stop();
    if (!stopped) {
      _lastError = _windowsTun.lastError.isEmpty
          ? 'Windows TUN 服务停止失败'
          : _windowsTun.lastError;
      _emitLog(_lastError);
      return false;
    }
    if (hadTun) _emitLog('── Windows TUN 服务已停止 ──');
    return true;
  }

  Future<void> stop() async {
    _lastError = '';
    if (Platform.isWindows) {
      // Never tear down the main SOCKS core while the privileged TUN is still
      // routing into it; otherwise Windows is left with a live black-hole TUN.
      await _windowsTun.stop();
    }
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
    _windowsTun.dispose();
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
