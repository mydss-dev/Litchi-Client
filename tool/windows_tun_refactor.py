from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    target = Path(path)
    text = target.read_text()
    if old not in text:
        raise SystemExit(f"anchor not found in {path}: {old[:120]!r}")
    target.write_text(text.replace(old, new, 1))


replace_once(
    "lib/shared/services/sing_box_config.dart",
    """            'mtu': 9000,
            'auto_route': true,
            'strict_route': true,
            // Windows uses the gvisor (userspace) stack: the `system` stack
            // drives wintun natively and segfaulted the process on connect.
            // gvisor needs no driver, so it cannot crash the host that way.
            'stack': Platform.isWindows ? 'gvisor' : 'system',
""",
    """            // Windows cloud/remote desktops are sensitive to jumbo MTUs and
            // aggressive route locking. Keep the adapter conventional there;
            // physical/macOS/Linux clients retain the existing larger MTU.
            'mtu': Platform.isWindows ? 1500 : 9000,
            'auto_route': true,
            'strict_route': !Platform.isWindows,
            'stack': 'system',
""",
)

replace_once(
    "lib/shared/services/sing_box_ffi.dart",
    """  static bool get isSupported =>
      Platform.isWindows || Platform.isMacOS || Platform.isLinux;
""",
    """  static bool get isSupported => Platform.isMacOS || Platform.isLinux;
""",
)
replace_once(
    "lib/shared/services/sing_box_ffi.dart",
    """    if (Platform.isWindows) {
      return [
        '$executableDirectory${separator}litchi_singbox.dll',
        '$executableDirectory${separator}core${separator}litchi_singbox.dll',
      ];
    }
""",
    "",
)

replace_once(
    "lib/app/core_controller.dart",
    """    // Windows uses the gvisor stack, which has no OS-visible TUN adapter for
    // the WFP kill switch to protect. Engaging it would block all traffic, so
    // the preference is stored but never touches WFP.
    if (Platform.isWindows) return true;
""",
    "",
)
replace_once(
    "lib/app/core_controller.dart",
    """        elevateMacTun: Platform.isMacOS && req.networkMode == NetworkMode.tun,
""",
    """        elevateMacTun: Platform.isMacOS && req.networkMode == NetworkMode.tun,
        elevateWindowsTun:
            Platform.isWindows && req.networkMode == NetworkMode.tun,
""",
)
replace_once(
    "lib/app/core_controller.dart",
    """        if (req.networkMode == NetworkMode.tun) {
          if (Platform.isWindows) {
            // gvisor stack: the TUN runs entirely in-process, so there is no
            // OS-visible adapter to wait for and no WFP-protectable alias. The
            // system stack (wintun) crashed natively on connect, so Windows now
            // uses gvisor instead.
            _activeTunInterfaces = const {};
          } else {
            final tunReady = await TunInterfaceVerifier.waitUntilReady(
              interfaceName: Platform.isMacOS
                  ? 'utun'
                  : AppIdentity.tunInterfaceAlias,
              matchPrefix: Platform.isMacOS,
              excludedNames: existingMacTunInterfaces,
            );
            if (!tunReady) {
              _coreError = CoreErrorMessageService.tunInterfaceUnavailable;
              await _core.stop();
              ClashApiClient.resetClient();
              await _releaseTunKillSwitch();
              _status = ConnectionStatus.error;
              return _coreError;
            }
            final currentTunInterfaces = Platform.isMacOS
                ? await TunInterfaceVerifier.matchingInterfaceNames(
                    interfaceName: 'utun',
                    matchPrefix: true,
                  )
                : <String>{AppIdentity.tunInterfaceAlias};
            _activeTunInterfaces = Platform.isMacOS
                ? currentTunInterfaces.difference(existingMacTunInterfaces)
                : currentTunInterfaces;
            if (_killSwitchEnabled) {
              final protected = await _engageTunKillSwitch();
              if (!protected) {
                _coreError = CoreErrorMessageService.tunKillSwitchUnavailable;
                await _core.stop();
                ClashApiClient.resetClient();
                await _releaseTunKillSwitch();
                _status = ConnectionStatus.error;
                return _coreError;
              }
            }
          }
        }
""",
    """        if (req.networkMode == NetworkMode.tun) {
          final tunReady = await TunInterfaceVerifier.waitUntilReady(
            interfaceName: Platform.isMacOS
                ? 'utun'
                : AppIdentity.tunInterfaceAlias,
            matchPrefix: Platform.isMacOS,
            excludedNames: existingMacTunInterfaces,
          );
          if (!tunReady) {
            _coreError = CoreErrorMessageService.tunInterfaceUnavailable;
            await _core.stop();
            ClashApiClient.resetClient();
            await _releaseTunKillSwitch();
            _status = ConnectionStatus.error;
            return _coreError;
          }
          final currentTunInterfaces = Platform.isMacOS
              ? await TunInterfaceVerifier.matchingInterfaceNames(
                  interfaceName: 'utun',
                  matchPrefix: true,
                )
              : <String>{AppIdentity.tunInterfaceAlias};
          _activeTunInterfaces = Platform.isMacOS
              ? currentTunInterfaces.difference(existingMacTunInterfaces)
              : currentTunInterfaces;
          if (_killSwitchEnabled) {
            final protected = await _engageTunKillSwitch();
            if (!protected) {
              _coreError = CoreErrorMessageService.tunKillSwitchUnavailable;
              await _core.stop();
              ClashApiClient.resetClient();
              await _releaseTunKillSwitch();
              _status = ConnectionStatus.error;
              return _coreError;
            }
          }
        }
""",
)

Path("lib/shared/services/windows_core_process_manager.dart").write_text(r'''import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'app_paths.dart';
import 'secure_logger.dart';

/// Runs the Windows sing-box core outside the Flutter process.
///
/// System-proxy mode uses a normal child process. TUN mode launches the same
/// binary with UAC elevation so Wintun and route changes never execute inside
/// the GUI process. A small authenticated localhost control endpoint provides
/// startup status and graceful shutdown. The core also watches the Flutter
/// parent PID and self-terminates if the GUI dies unexpectedly.
final class WindowsCoreProcessManager {
  final _logController = StreamController<String>.broadcast();
  final _exitController = StreamController<String>.broadcast();

  Process? _process;
  int? _pid;
  int? _controlPort;
  String _token = '';
  String _lastError = '';
  bool _running = false;
  bool _stopping = false;
  int _generation = 0;

  bool get isRunning => _running;
  String get lastError => _lastError;
  Stream<String> get logStream => _logController.stream;
  Stream<String> get exitStream => _exitController.stream;

  static String? findExecutable() {
    if (!Platform.isWindows) return null;
    final separator = Platform.pathSeparator;
    final executableDirectory = File(Platform.resolvedExecutable).parent.path;
    final candidates = [
      '$executableDirectory${separator}litchi-core.exe',
      '$executableDirectory${separator}core${separator}litchi-core.exe',
    ];
    for (final path in candidates) {
      if (File(path).existsSync()) return path;
    }
    return null;
  }

  Future<bool> start(
    String configPath, {
    required bool elevate,
    required int apiPort,
  }) async {
    if (!Platform.isWindows) {
      _lastError = 'Windows core process is only available on Windows';
      return false;
    }
    await stop();

    final executable = findExecutable();
    if (executable == null) {
      _lastError = '缺少 Windows 核心文件 litchi-core.exe';
      return false;
    }

    _lastError = '';
    _stopping = false;
    final generation = ++_generation;
    final controlPort = await _allocatePort();
    final token = _randomToken();
    final arguments = <String>[
      'run',
      '--config',
      configPath,
      '--working-directory',
      AppPaths.dataDirectory,
      '--control-port',
      '$controlPort',
      '--token',
      token,
      '--parent-pid',
      '$pid',
    ];

    _controlPort = controlPort;
    _token = token;

    try {
      if (elevate) {
        _pid = await _launchElevated(executable, arguments);
        _emitLog('Windows TUN 核心已通过 UAC 启动 (PID $_pid)');
      } else {
        final process = await Process.start(executable, arguments);
        _process = process;
        _pid = process.pid;
        _pipeProcessOutput(process);
        unawaited(
          process.exitCode.then(
            (code) => _handleProcessExit(generation, code),
          ),
        );
      }
    } catch (error) {
      _lastError = _friendlyLaunchError(error);
      _clearSession();
      return false;
    }

    final started = await _waitForStartup(generation);
    if (!started) {
      final failure = _lastError.isEmpty ? 'Windows 核心启动超时' : _lastError;
      await stop();
      _lastError = failure;
      return false;
    }

    _running = true;
    _emitLog(
      '── Windows sing-box 独立核心运行中 '
      '(PID $_pid, API $apiPort) ──',
    );
    unawaited(_monitor(generation));
    return true;
  }

  Future<bool> stop() async {
    if (!Platform.isWindows) return true;
    final hadSession =
        _running || _process != null || _controlPort != null || _pid != null;
    if (!hadSession) return true;

    _stopping = true;
    ++_generation;
    var graceful = false;
    try {
      graceful = await _sendStop();
      if (graceful) {
        graceful = await _waitForEndpointDown();
      }
    } catch (error) {
      SecureLogger.debug('Windows core graceful stop failed', error);
    }

    final process = _process;
    if (!graceful && process != null) {
      process.kill();
      try {
        await process.exitCode.timeout(const Duration(seconds: 2));
        graceful = true;
      } catch (_) {
        // Returning false lets the caller surface a failed stop.
      }
    }

    _running = false;
    _stopping = false;
    _clearSession();
    if (hadSession) _emitLog('── Windows sing-box 独立核心已停止 ──');
    return graceful;
  }

  Future<String> version() async {
    final executable = findExecutable();
    if (executable == null) return '';
    try {
      final result = await Process.run(executable, const ['version']);
      if (result.exitCode != 0) return '';
      return '${result.stdout}'.trim();
    } catch (_) {
      return '';
    }
  }

  void dispose() {
    unawaited(
      stop().whenComplete(() async {
        if (!_logController.isClosed) await _logController.close();
        if (!_exitController.isClosed) await _exitController.close();
      }),
    );
  }

  Future<bool> _waitForStartup(int generation) async {
    final deadline = DateTime.now().add(const Duration(seconds: 12));
    while (generation == _generation && DateTime.now().isBefore(deadline)) {
      final status = await _readStatus();
      final state = '${status?['state'] ?? ''}';
      if (state == 'running') return true;
      if (state == 'error') {
        _lastError = '${status?['error'] ?? 'Windows 核心启动失败'}'.trim();
        if (_lastError.isEmpty) _lastError = 'Windows 核心启动失败';
        return false;
      }
      if (_lastError.isNotEmpty && _process == null && _pid == null) {
        return false;
      }
      await Future<void>.delayed(const Duration(milliseconds: 120));
    }
    return false;
  }

  Future<void> _monitor(int generation) async {
    var missed = 0;
    while (_running && !_stopping && generation == _generation) {
      await Future<void>.delayed(const Duration(seconds: 1));
      if (!_running || _stopping || generation != _generation) return;
      final status = await _readStatus();
      if (status == null) {
        missed += 1;
        if (missed >= 3) {
          _reportUnexpectedExit(generation, 'Windows 核心进程意外退出');
          return;
        }
        continue;
      }
      missed = 0;
      final state = '${status['state'] ?? ''}';
      if (state == 'error') {
        final error = '${status['error'] ?? ''}'.trim();
        _reportUnexpectedExit(
          generation,
          error.isEmpty ? 'Windows 核心运行异常' : error,
        );
        return;
      }
    }
  }

  void _handleProcessExit(int generation, int exitCode) {
    if (_stopping || generation != _generation) return;
    if (!_running) {
      if (_lastError.isEmpty) {
        _lastError = 'Windows 核心进程启动失败 (exit $exitCode)';
      }
      _process = null;
      _pid = null;
      return;
    }
    _reportUnexpectedExit(
      generation,
      'Windows 核心进程意外退出 (exit $exitCode)',
    );
  }

  void _reportUnexpectedExit(int generation, String message) {
    if (_stopping || generation != _generation || !_running) return;
    _running = false;
    _lastError = message;
    _emitLog(message);
    if (!_exitController.isClosed) _exitController.add(message);
    _clearSession();
  }

  Future<Map<String, dynamic>?> _readStatus() async {
    final controlPort = _controlPort;
    final token = _token;
    if (controlPort == null || token.isEmpty) return null;
    final client = HttpClient()
      ..connectionTimeout = const Duration(milliseconds: 500);
    try {
      final request = await client
          .getUrl(Uri.parse('http://127.0.0.1:$controlPort/status'))
          .timeout(const Duration(milliseconds: 700));
      request.headers.set('X-Litchi-Token', token);
      final response = await request.close().timeout(
        const Duration(milliseconds: 700),
      );
      if (response.statusCode != HttpStatus.ok) return null;
      final body = await utf8.decoder.bind(response).join().timeout(
        const Duration(milliseconds: 700),
      );
      final decoded = jsonDecode(body);
      return decoded is Map
          ? decoded.map((key, value) => MapEntry('$key', value))
          : null;
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }

  Future<bool> _sendStop() async {
    final controlPort = _controlPort;
    final token = _token;
    if (controlPort == null || token.isEmpty) return false;
    final client = HttpClient()
      ..connectionTimeout = const Duration(milliseconds: 700);
    try {
      final request = await client
          .postUrl(Uri.parse('http://127.0.0.1:$controlPort/stop'))
          .timeout(const Duration(seconds: 1));
      request.headers.set('X-Litchi-Token', token);
      request.contentLength = 0;
      final response = await request.close().timeout(const Duration(seconds: 1));
      await response.drain<void>();
      return response.statusCode == HttpStatus.accepted ||
          response.statusCode == HttpStatus.ok;
    } catch (_) {
      return false;
    } finally {
      client.close(force: true);
    }
  }

  Future<bool> _waitForEndpointDown() async {
    final deadline = DateTime.now().add(const Duration(seconds: 4));
    while (DateTime.now().isBefore(deadline)) {
      if (await _readStatus() == null) return true;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    return false;
  }

  void _pipeProcessOutput(Process process) {
    process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(_emitLog);
    process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(_emitLog);
  }

  Future<int> _launchElevated(
    String executable,
    List<String> arguments,
  ) async {
    final argumentLine = arguments.map(_quoteWindowsArgument).join(' ');
    final exeBase64 = base64Encode(utf8.encode(executable));
    final argsBase64 = base64Encode(utf8.encode(argumentLine));
    final script = '''
\$exe = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('$exeBase64'))
\$arguments = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('$argsBase64'))
try {
  \$startInfo = [System.Diagnostics.ProcessStartInfo]::new()
  \$startInfo.FileName = \$exe
  \$startInfo.Arguments = \$arguments
  \$startInfo.UseShellExecute = \$true
  \$startInfo.Verb = 'runas'
  \$startInfo.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden
  \$process = [System.Diagnostics.Process]::Start(\$startInfo)
  if (\$null -eq \$process) { exit 1 }
  [Console]::Out.Write(\$process.Id)
  exit 0
} catch {
  \$exception = \$_.Exception
  while (\$null -ne \$exception) {
    if (\$exception -is [System.ComponentModel.Win32Exception] -and \$exception.NativeErrorCode -eq 1223) {
      exit 1223
    }
    \$exception = \$exception.InnerException
  }
  [Console]::Error.Write(\$_.Exception.Message)
  exit 1
}
''';
    final result = await Process.run('powershell.exe', [
      '-NoProfile',
      '-NonInteractive',
      '-ExecutionPolicy',
      'Bypass',
      '-Command',
      script,
    ]);
    if (result.exitCode == 1223) {
      throw StateError('已取消 Windows TUN 管理员授权');
    }
    if (result.exitCode != 0) {
      final detail = '${result.stderr}'.trim();
      throw StateError(
        detail.isEmpty ? '无法以管理员权限启动 Windows TUN 核心' : detail,
      );
    }
    final launchedPid = int.tryParse('${result.stdout}'.trim());
    if (launchedPid == null || launchedPid <= 0) {
      throw StateError('Windows TUN 核心未返回有效 PID');
    }
    return launchedPid;
  }

  static String _quoteWindowsArgument(String value) {
    if (value.isNotEmpty && !RegExp(r'[\s"]').hasMatch(value)) return value;
    final buffer = StringBuffer('"');
    var backslashes = 0;

    void writeBackslashes(int count) {
      for (var i = 0; i < count; i++) {
        buffer.write('\\');
      }
    }

    for (final codeUnit in value.codeUnits) {
      final character = String.fromCharCode(codeUnit);
      if (character == '\\') {
        backslashes += 1;
        continue;
      }
      if (character == '"') {
        writeBackslashes(backslashes * 2 + 1);
        buffer.write('"');
        backslashes = 0;
        continue;
      }
      writeBackslashes(backslashes);
      backslashes = 0;
      buffer.write(character);
    }
    writeBackslashes(backslashes * 2);
    buffer.write('"');
    return buffer.toString();
  }

  static Future<int> _allocatePort() async {
    final socket = await ServerSocket.bind(
      InternetAddress.loopbackIPv4,
      0,
      shared: false,
    );
    try {
      return socket.port;
    } finally {
      await socket.close();
    }
  }

  static String _randomToken() {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random.secure();
    return List.generate(48, (_) => chars[random.nextInt(chars.length)]).join();
  }

  String _friendlyLaunchError(Object error) {
    final text = '$error';
    if (text.contains('管理员授权')) {
      return text.replaceFirst('Bad state: ', '');
    }
    return 'Windows 核心启动失败：$text';
  }

  void _clearSession() {
    _process = null;
    _pid = null;
    _controlPort = null;
    _token = '';
  }

  void _emitLog(String line) {
    final value = line.trim();
    if (value.isEmpty || _logController.isClosed) return;
    _logController.add(value);
  }
}
''')

Path("lib/shared/services/sing_box_core_manager.dart").write_text(r'''import 'dart:async';
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
          nativeError.isEmpty
              ? 'sing-box 控制接口启动超时（端口 $apiPort）'
              : nativeError,
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
''')

Path("core/singbox/main.go").write_text(r'''package main

/*
#include <stdlib.h>
*/
import "C"

import (
	"fmt"
	"os"
	"unsafe"
)

func resultCode(err error) C.int {
	if err != nil {
		return -1
	}
	return 0
}

// capturePanic protects the C ABI used by macOS/Linux. Windows runs sing-box
// in litchi-core.exe, so TUN/native failures cannot terminate the Flutter GUI.
func capturePanic(code *C.int) {
	if r := recover(); r != nil {
		coreService.setError(fmt.Sprintf("panic: %v", r))
		*code = -1
	}
}

//export litchi_core_check_config
func litchi_core_check_config(config *C.char, workDir *C.char) (code C.int) {
	if config == nil {
		return resultCode(coreService.setError("config is required"))
	}
	defer capturePanic(&code)
	return resultCode(coreService.check(C.GoString(config), cString(workDir)))
}

//export litchi_core_start
func litchi_core_start(config *C.char, workDir *C.char) (code C.int) {
	if config == nil {
		return resultCode(coreService.setError("config is required"))
	}
	defer capturePanic(&code)
	return resultCode(coreService.start(C.GoString(config), cString(workDir)))
}

//export litchi_core_stop
func litchi_core_stop() C.int { return resultCode(coreService.stop()) }

//export litchi_core_is_running
func litchi_core_is_running() C.int {
	if coreService.isRunning() {
		return 1
	}
	return 0
}

//export litchi_core_version
func litchi_core_version() *C.char { return C.CString(coreService.version()) }

//export litchi_core_last_error
func litchi_core_last_error() *C.char { return C.CString(coreService.lastError()) }

//export litchi_core_free_string
func litchi_core_free_string(value *C.char) { C.free(unsafe.Pointer(value)) }

func cString(value *C.char) string {
	if value == nil {
		return ""
	}
	return C.GoString(value)
}

func main() {
	os.Exit(runCLI(os.Args[1:]))
}
''')

Path("core/singbox/cli.go").write_text(r'''package main

import (
	"context"
	"encoding/json"
	"flag"
	"fmt"
	"net"
	"net/http"
	"os"
	"os/signal"
	"strconv"
	"sync"
	"time"
)

type processStatus struct {
	State   string `json:"state"`
	Error   string `json:"error,omitempty"`
	Version string `json:"version"`
	PID     int    `json:"pid"`
}

type statusStore struct {
	mu    sync.RWMutex
	state string
	err   string
}

func (s *statusStore) set(state string, err error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.state = state
	if err == nil {
		s.err = ""
	} else {
		s.err = err.Error()
	}
}

func (s *statusStore) snapshot() processStatus {
	s.mu.RLock()
	defer s.mu.RUnlock()
	return processStatus{
		State:   s.state,
		Error:   s.err,
		Version: coreService.version(),
		PID:     os.Getpid(),
	}
}

func runCLI(args []string) int {
	if len(args) == 1 && args[0] == "version" {
		fmt.Println(coreService.version())
		return 0
	}
	if len(args) == 0 || args[0] != "run" {
		fmt.Fprintln(os.Stderr, "usage: litchi-core.exe run --config <path> --working-directory <path> --control-port <port> --token <token> --parent-pid <pid>")
		return 2
	}

	flags := flag.NewFlagSet("run", flag.ContinueOnError)
	configPath := flags.String("config", "", "sing-box config path")
	workingDirectory := flags.String("working-directory", "", "sing-box working directory")
	controlPort := flags.Int("control-port", 0, "localhost control port")
	token := flags.String("token", "", "control authentication token")
	parentPID := flags.Int("parent-pid", 0, "Flutter parent process ID")
	if err := flags.Parse(args[1:]); err != nil {
		return 2
	}
	if *configPath == "" || *controlPort <= 0 || *controlPort > 65535 || *token == "" {
		fmt.Fprintln(os.Stderr, "missing required run arguments")
		return 2
	}

	state := &statusStore{state: "starting"}
	stopCh := make(chan struct{})
	var stopOnce sync.Once
	requestStop := func() { stopOnce.Do(func() { close(stopCh) }) }

	mux := http.NewServeMux()
	authorized := func(w http.ResponseWriter, r *http.Request) bool {
		if r.Header.Get("X-Litchi-Token") == *token {
			return true
		}
		http.Error(w, "forbidden", http.StatusForbidden)
		return false
	}
	mux.HandleFunc("/status", func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodGet || !authorized(w, r) {
			return
		}
		w.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(w).Encode(state.snapshot())
	})
	mux.HandleFunc("/stop", func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost || !authorized(w, r) {
			return
		}
		w.WriteHeader(http.StatusAccepted)
		_, _ = w.Write([]byte("stopping"))
		requestStop()
	})

	listener, err := net.Listen("tcp", "127.0.0.1:"+strconv.Itoa(*controlPort))
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		return 1
	}
	server := &http.Server{Handler: mux, ReadHeaderTimeout: 2 * time.Second}
	go func() { _ = server.Serve(listener) }()

	if *parentPID > 0 {
		go func() {
			ticker := time.NewTicker(time.Second)
			defer ticker.Stop()
			for {
				select {
				case <-stopCh:
					return
				case <-ticker.C:
					if !parentProcessAlive(*parentPID) {
						requestStop()
						return
					}
				}
			}
		}()
	}

	interrupts := make(chan os.Signal, 1)
	signal.Notify(interrupts, os.Interrupt)
	defer signal.Stop(interrupts)
	go func() {
		select {
		case <-interrupts:
			requestStop()
		case <-stopCh:
		}
	}()

	content, err := os.ReadFile(*configPath)
	if err != nil {
		state.set("error", err)
		waitForErrorAcknowledgement(stopCh)
		shutdownControlServer(server)
		return 1
	}

	startResult := make(chan error, 1)
	go func() {
		defer func() {
			if recovered := recover(); recovered != nil {
				startResult <- fmt.Errorf("panic: %v", recovered)
			}
		}()
		startResult <- coreService.start(string(content), *workingDirectory)
	}()

	select {
	case <-stopCh:
		// If native TUN startup is wedged, returning from main terminates the
		// isolated process without ever endangering the Flutter GUI.
		shutdownControlServer(server)
		return 1
	case err = <-startResult:
	}
	if err != nil {
		state.set("error", err)
		waitForErrorAcknowledgement(stopCh)
		shutdownControlServer(server)
		return 1
	}
	state.set("running", nil)

	<-stopCh
	state.set("stopping", nil)
	stopErr := coreService.stop()
	if stopErr != nil {
		state.set("error", stopErr)
	} else {
		state.set("stopped", nil)
	}
	shutdownControlServer(server)
	if stopErr != nil {
		fmt.Fprintln(os.Stderr, stopErr)
		return 1
	}
	return 0
}

func waitForErrorAcknowledgement(stopCh <-chan struct{}) {
	select {
	case <-stopCh:
	case <-time.After(15 * time.Second):
	}
}

func shutdownControlServer(server *http.Server) {
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()
	_ = server.Shutdown(ctx)
}
''')

Path("core/singbox/parent_windows.go").write_text(r'''//go:build windows

package main

import "golang.org/x/sys/windows"

func parentProcessAlive(pid int) bool {
	if pid <= 0 {
		return false
	}
	handle, err := windows.OpenProcess(windows.SYNCHRONIZE, false, uint32(pid))
	if err != nil {
		return false
	}
	defer windows.CloseHandle(handle)
	status, err := windows.WaitForSingleObject(handle, 0)
	return err == nil && status == windows.WAIT_TIMEOUT
}
''')

Path("core/singbox/parent_other.go").write_text(r'''//go:build !windows

package main

func parentProcessAlive(pid int) bool {
	return pid > 0
}
''')

Path("tool/build_singbox_desktop.ps1").write_text(r'''param(
  [ValidateSet("windows", "linux", "darwin")]
  [string]$Target = $(if ($IsMacOS) { "darwin" } elseif ($IsLinux) { "linux" } else { "windows" }),
  [ValidateSet("amd64", "arm64")]
  [string]$Arch = $(if ($env:PROCESSOR_ARCHITECTURE -eq "ARM64") { "arm64" } else { "amd64" })
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path "$PSScriptRoot\.."
$source = Join-Path $root "core\singbox"
$output = Join-Path $root "runtime\singbox\$Target-$Arch"
New-Item -ItemType Directory -Force -Path $output | Out-Null
$versionsFile = Join-Path $PSScriptRoot "core_versions.env"
$versionLine = Get-Content $versionsFile | Where-Object {
  $_ -match '^SING_BOX_VERSION='
} | Select-Object -First 1
if (-not $versionLine) { throw "SING_BOX_VERSION is missing from $versionsFile" }
$version = ($versionLine -split '=', 2)[1].Trim().TrimStart('v')

$env:GOOS = $Target
$env:GOARCH = $Arch
$env:CGO_ENABLED = "1"
if ($Target -eq "windows" -and -not $env:CC) {
  if (Get-Command gcc -ErrorAction SilentlyContinue) {
    $env:CC = "gcc"
  } elseif (Get-Command clang -ErrorAction SilentlyContinue) {
    $env:CC = "clang"
  } else {
    throw "A C compiler (gcc or clang) is required to build the Windows core"
  }
}
$tags = "with_clash_api,with_quic,with_utls,with_wireguard"

Push-Location $source
try {
  go mod download
  if ($Target -eq "windows") {
    Remove-Item -LiteralPath (Join-Path $output "litchi_singbox.dll") -Force -ErrorAction SilentlyContinue
    $binary = Join-Path $output "litchi-core.exe"
    go build -trimpath -tags $tags -ldflags "-s -w -X github.com/sagernet/sing-box/constant.Version=$version" -o $binary .
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    Write-Host "isolated Windows sing-box core ready: $binary"
  } else {
    $extension = if ($Target -eq "darwin") { ".dylib" } else { ".so" }
    $library = Join-Path $output "litchi_singbox$extension"
    go build -trimpath -tags $tags -buildmode=c-shared -ldflags "-s -w -X github.com/sagernet/sing-box/constant.Version=$version" -o $library .
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    Write-Host "sing-box desktop library ready: $library"
  }
} finally {
  Pop-Location
}
''')

Path("tool/build_singbox_desktop.sh").write_text(r'''#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE="$ROOT/core/singbox"
TARGET="${1:-$(go env GOOS)}"
ARCH="${2:-$(go env GOARCH)}"
OUTPUT="$ROOT/runtime/singbox/$TARGET-$ARCH"
mkdir -p "$OUTPUT"
VERSION="$(sed -n 's/^SING_BOX_VERSION=v\{0,1\}//p' "$ROOT/tool/core_versions.env" | head -n 1)"
if [[ -z "$VERSION" ]]; then
  echo "SING_BOX_VERSION is missing from tool/core_versions.env" >&2
  exit 1
fi
TAGS="with_clash_api,with_quic,with_utls,with_wireguard"

cd "$SOURCE"
go mod download
if [[ "$TARGET" == "windows" ]]; then
  rm -f "$OUTPUT/litchi_singbox.dll"
  CGO_ENABLED=1 GOOS="$TARGET" GOARCH="$ARCH" go build \
    -trimpath -tags "$TAGS" \
    -ldflags "-s -w -X github.com/sagernet/sing-box/constant.Version=$VERSION" \
    -o "$OUTPUT/litchi-core.exe" .
  echo "isolated Windows sing-box core ready: $OUTPUT/litchi-core.exe"
else
  if [[ "$TARGET" == "darwin" ]]; then EXT=".dylib"; else EXT=".so"; fi
  CGO_ENABLED=1 GOOS="$TARGET" GOARCH="$ARCH" go build \
    -trimpath -tags "$TAGS" -buildmode=c-shared \
    -ldflags "-s -w -X github.com/sagernet/sing-box/constant.Version=$VERSION" \
    -o "$OUTPUT/litchi_singbox$EXT" .
  echo "sing-box desktop library ready: $OUTPUT/litchi_singbox$EXT"
fi
''')

Path("tool/bundle_windows_singbox.ps1").write_text(r'''param(
  [Parameter(Mandatory = $true)]
  [string]$ReleaseDir
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path "$PSScriptRoot\.."
$release = Resolve-Path $ReleaseDir

& "$PSScriptRoot\build_singbox_desktop.ps1" -Target windows -Arch amd64
$coreBinary = Join-Path $root "runtime\singbox\windows-amd64\litchi-core.exe"
if (-not (Test-Path -LiteralPath $coreBinary)) {
  throw "Windows sing-box core was not generated: $coreBinary"
}

@(
  (Join-Path $release "litchi_singbox.dll"),
  (Join-Path $release "core\litchi_singbox.dll")
) | ForEach-Object {
  Remove-Item -LiteralPath $_ -Force -ErrorAction SilentlyContinue
}
Copy-Item -LiteralPath $coreBinary -Destination (Join-Path $release "litchi-core.exe") -Force

$versions = @{}
Get-Content "$PSScriptRoot\core_versions.env" | ForEach-Object {
  if ($_ -match '^\s*([^#][^=]+)=(.*)$') {
    $versions[$matches[1].Trim()] = $matches[2].Trim()
  }
}
$wintunVersion = $versions["WINTUN_VERSION"]
$tempRoot = if ($env:RUNNER_TEMP) { $env:RUNNER_TEMP } else { [IO.Path]::GetTempPath() }
$wintunArchive = Join-Path $tempRoot "wintun-$wintunVersion.zip"
$extractDirectory = Join-Path ([IO.Path]::GetTempPath()) "litchi-wintun-$PID"
try {
  Invoke-WebRequest "https://www.wintun.net/builds/wintun-$wintunVersion.zip" -OutFile $wintunArchive
  $actual = (Get-FileHash $wintunArchive -Algorithm SHA256).Hash.ToLower()
  if ($actual -ne $versions["WINTUN_SHA256"].ToLower()) {
    throw "wintun SHA-256 mismatch: $actual"
  }
  Expand-Archive $wintunArchive -DestinationPath $extractDirectory -Force
  Copy-Item -LiteralPath "$extractDirectory\wintun\bin\amd64\wintun.dll" -Destination (Join-Path $release "wintun.dll") -Force
} finally {
  Remove-Item -LiteralPath $wintunArchive -Force -ErrorAction SilentlyContinue
  if (Test-Path -LiteralPath $extractDirectory) {
    Remove-Item -LiteralPath $extractDirectory -Recurse -Force
  }
}

$version = & (Join-Path $release "litchi-core.exe") version
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace("$version")) {
  throw "litchi-core.exe version smoke test failed"
}
if (Test-Path -LiteralPath (Join-Path $release "litchi_singbox.dll")) {
  throw "legacy litchi_singbox.dll must not be present in Windows release"
}
Write-Host "isolated Windows core $version and Wintun bundled into $release"
''')

replace_once(
    "litchi_setup.iss",
    """[InstallDelete]
Type: files; Name: "{app}\\Client.exe"
""",
    """[InstallDelete]
Type: files; Name: "{app}\\Client.exe"
; v1.1.3 and older shipped the Windows core as an in-process DLL. Remove it
; explicitly during upgrades so old runtime files can never shadow the new
; isolated litchi-core.exe architecture.
Type: files; Name: "{app}\\litchi_singbox.dll"
Type: files; Name: "{app}\\core\\litchi_singbox.dll"
""",
)

gitignore = Path(".gitignore").read_text()
if "\n/runtime/\n" not in gitignore:
    Path(".gitignore").write_text(
        gitignore.rstrip()
        + "\n\n# Generated desktop core binaries (never commit build products).\n/runtime/\n"
    )

# The patch carrier is not part of the product.
Path("tool/windows_tun_refactor.py").unlink(missing_ok=True)
