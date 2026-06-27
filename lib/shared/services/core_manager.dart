import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'secure_logger.dart';
import 'mihomo_api_client.dart';
import 'mihomo_config.dart';

enum CoreState { stopped, starting, running, error }

/// Manages the mihomo process lifecycle.
class CoreManager {
  Process? _process;
  CoreState _state = CoreState.stopped;
  String _lastError = '';

  final _stateCtrl = StreamController<CoreState>.broadcast();
  final _logCtrl = StreamController<String>.broadcast();

  CoreState get state => _state;
  String get lastError => _lastError;
  bool get isRunning => _state == CoreState.running;
  Stream<CoreState> get stateStream => _stateCtrl.stream;

  /// Emits stripped log lines from mihomo stdout + stderr.
  Stream<String> get logStream => _logCtrl.stream;

  // ── PID file ──────────────────────────────────────────────────────────────

  static File get _pidFile {
    final base = Platform.isWindows
        ? (Platform.environment['LOCALAPPDATA'] ??
              Platform.environment['APPDATA'] ??
              Directory.systemTemp.path)
        : (Platform.environment['HOME'] != null
              ? '${Platform.environment['HOME']}/Library/Application Support'
              : Directory.systemTemp.path);
    final dir = Platform.isWindows
        ? '$base\\Litchi'
        : '$base${Platform.pathSeparator}Litchi';
    return File('$dir${Platform.pathSeparator}mihomo.pid.json');
  }

  // ── Executable discovery ──────────────────────────────────────────────────

  static String? findExecutable() {
    final sep = Platform.pathSeparator;
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    final home = Platform.environment['HOME'];
    final candidates = <String>[
      if (Platform.isWindows) ...[
        '$exeDir\\mihomo.exe',
        '$exeDir\\core\\mihomo.exe',
        '${Platform.environment['LOCALAPPDATA']}\\LitchiClient\\mihomo.exe',
      ] else ...[
        '$exeDir${sep}mihomo',
        // macOS .app bundle ships the binary under Contents/Resources.
        '$exeDir$sep..${sep}Resources${sep}mihomo',
        '$exeDir${sep}core${sep}mihomo',
        if (home != null && home.isNotEmpty)
          '$home/Library/Application Support/LitchiClient/mihomo',
      ],
    ];
    for (final p in candidates) {
      if (File(p).existsSync()) return p;
    }
    return null;
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  Future<void> start(String configPath, {int apiPort = 9090}) async {
    if (_state == CoreState.running || _state == CoreState.starting) return;

    final exe = findExecutable();
    if (exe == null) {
      _setError('未找到 mihomo 核心，请重新安装客户端');
      return;
    }

    // Kill any previously owned mihomo process (by saved PID).
    await _killSavedPid(expectedExePath: exe);

    // Wait (briefly) for the API port to become free instead of failing on the
    // first check. This makes restarts robust without callers having to insert
    // fixed "settle" delays before calling start().
    if (!await _waitForPortFree(apiPort)) {
      _setError('端口 $apiPort 已被占用，请关闭其他代理软件后重试');
      return;
    }

    _lastError = '';
    _setState(CoreState.starting);
    _emitLog('── mihomo 启动中 ──');

    try {
      _process = await Process.start(exe, [
        '-d',
        MihomoConfig.appDataDir(),
        '-f',
        configPath,
      ]);

      // Save PID so the next startup can clean this process up if we crash.
      await _writePidFile(_process!.pid, exe);

      final outputLines = <String>[];
      void handleOutput(String line) {
        outputLines.add(line);
        if (outputLines.length > 50) outputLines.removeAt(0);
        _emitLog(line);
        if (_state == CoreState.starting) {
          final lower = line.toLowerCase();
          if (lower.contains('fatal') || lower.contains('error')) {
            _lastError = _stripAnsi(line);
          }
        }
      }

      final stdoutDone = _process!.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(handleOutput)
          .asFuture<void>();

      final stderrDone = _process!.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(handleOutput)
          .asFuture<void>();

      unawaited(
        _process!.exitCode.then((code) async {
          // Mihomo emits some fatal startup diagnostics on stdout. Drain both
          // streams before choosing the message so the useful line is not
          // replaced by a generic exit code.
          await Future.wait([stdoutDone, stderrDone]);
          if (_state == CoreState.running || _state == CoreState.starting) {
            if (_lastError.isEmpty && outputLines.isNotEmpty) {
              _lastError = _stripAnsi(outputLines.last);
            }
            if (_lastError.isEmpty) _lastError = '核心进程退出 (code: $code)';
            _setState(CoreState.error);
            _process = null;
            _deletePidFile();
          }
        }),
      );

      // Poll the controller API to confirm mihomo is actually ready.
      final ready = await _waitForApi(apiPort);

      if (_process != null && _state != CoreState.error) {
        if (ready) {
          _emitLog('── mihomo 运行中 (PID ${_process!.pid}) ──');
          _setState(CoreState.running);
          _deleteConfigFile(configPath);
        } else {
          _setError('核心启动超时 (端口 $apiPort)，请检查配置文件或重试');
          _emitLog('── 启动超时，已停止 ──');
          _process?.kill();
          _process = null;
          _deletePidFile();
          _deleteConfigFile(configPath);
        }
      }
      if (_process == null || _state == CoreState.error) {
        _deleteConfigFile(configPath);
      }
    } catch (e) {
      final raw = '$e';
      final String msg;
      if (raw.contains('Access is denied') ||
          raw.contains('Permission denied') ||
          raw.contains('EACCES') ||
          raw.contains('access')) {
        msg = Platform.isMacOS
            ? '权限不足，请确认 mihomo 具有执行权限（chmod +x）'
            : '权限不足，请以管理员身份运行客户端';
      } else if (raw.contains('No such file') || raw.contains('系统找不到')) {
        msg = '未找到 mihomo 核心，请检查文件是否存在';
      } else {
        msg = '启动失败，请检查 mihomo 核心是否完整';
      }
      _setError(msg);
      _emitLog('── 启动异常: $raw ──');
      _process = null;
      _deletePidFile();
      _deleteConfigFile(configPath);
    }
  }

  Future<void> stop() async {
    final p = _process;
    _process = null;
    _lastError = '';
    _setState(CoreState.stopped);
    _emitLog('── mihomo 已停止 ──');
    p?.kill();
    _deletePidFile();
    // Brief wait so the port is released before any next start().
    await Future.delayed(const Duration(milliseconds: 300));
  }

  void dispose() {
    _process?.kill();
    _stateCtrl.close();
    _logCtrl.close();
    _deletePidFile();
  }

  void _emitLog(String raw) {
    if (_logCtrl.isClosed) return;
    final line = SecureLogRedactor.redact(_stripAnsi(raw));
    if (line.isEmpty) return;
    _logCtrl.add(line);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Called at app startup to kill any orphaned mihomo process left by a
  /// previous crash, remove stale PID/config files, and restore proxy state.
  static Future<void> cleanupOnStartup() async {
    await _killSavedPid(expectedExePath: findExecutable());
    await MihomoConfig.cleanupStaleConfigFiles();
  }

  /// Kill the specific mihomo process we previously spawned (by saved PID).
  /// This only affects our own process — not any other mihomo instances.
  /// Uses [Process.killPid], which maps to TerminateProcess on Windows and
  /// SIGKILL on POSIX, so it is cross-platform.
  static Future<void> _killSavedPid({String? expectedExePath}) async {
    try {
      if (!await _pidFile.exists()) return;
      final raw = await _pidFile.readAsString();
      Object? decoded;
      try {
        decoded = jsonDecode(raw);
      } catch (_) {}
      final pid = decoded is Map
          ? int.tryParse('${decoded['pid'] ?? ''}')
          : int.tryParse(raw.trim());
      if (pid == null) {
        await _pidFile.delete();
        return;
      }
      final savedExe = decoded is Map ? decoded['exePath']?.toString() : null;
      final expected = expectedExePath ?? savedExe;
      if (expected == null ||
          !await _pidLooksLikeOurCore(pid, expectedExePath: expected)) {
        await _pidFile.delete();
        return;
      }
      Process.killPid(pid, ProcessSignal.sigkill);
      await _pidFile.delete();
      // Give the OS a moment to release the port.
      await Future.delayed(const Duration(milliseconds: 400));
    } catch (_) {}
  }

  static void _deletePidFile() {
    try {
      _pidFile.deleteSync();
    } catch (_) {}
  }

  static Future<void> _writePidFile(int pid, String exePath) async {
    await _pidFile.parent.create(recursive: true);
    await _pidFile.writeAsString(
      jsonEncode({
        'pid': pid,
        'exePath': File(exePath).absolute.path,
        'savedAt': DateTime.now().toIso8601String(),
      }),
    );
  }

  static Future<bool> _pidLooksLikeOurCore(
    int pid, {
    required String expectedExePath,
  }) async {
    // On macOS, `ps -o comm=` often returns only the command name. Use the full
    // command line first so paths inside `.app` bundles (including spaces) still
    // match the executable path saved in the PID file.
    if (Platform.isMacOS) {
      final command = await _processCommand(pid);
      if (command != null && _commandStartsWithPath(command, expectedExePath)) {
        return true;
      }
    }

    final actual = await _processPath(pid);
    if (actual == null || actual.isEmpty) return false;
    return _samePath(actual, expectedExePath);
  }

  static Future<String?> _processPath(int pid) async {
    try {
      if (Platform.isWindows) {
        final result = await Process.run('powershell', [
          '-NoProfile',
          '-NonInteractive',
          '-Command',
          '(Get-CimInstance Win32_Process -Filter "ProcessId=$pid").ExecutablePath',
        ]).timeout(const Duration(seconds: 3));
        if (result.exitCode != 0) return null;
        final path = '${result.stdout}'.trim();
        return path.isEmpty ? null : path;
      }
      final result = await Process.run('ps', [
        '-p',
        '$pid',
        '-o',
        'comm=',
      ]).timeout(const Duration(seconds: 3));
      if (result.exitCode != 0) return null;
      final path = '${result.stdout}'.trim();
      return path.isEmpty ? null : path;
    } catch (_) {
      return null;
    }
  }

  static Future<String?> _processCommand(int pid) async {
    try {
      final result = await Process.run('ps', [
        '-p',
        '$pid',
        '-o',
        'command=',
      ]).timeout(const Duration(seconds: 3));
      if (result.exitCode != 0) return null;
      final command = '${result.stdout}'.trim();
      return command.isEmpty ? null : command;
    } catch (_) {
      return null;
    }
  }

  static bool _commandStartsWithPath(String command, String expectedExePath) {
    final trimmed = command.trim();
    final expected = File(expectedExePath).absolute.path;
    final normalized = expected.replaceAll('/', Platform.pathSeparator);
    final quoted = '"$normalized"';
    return trimmed == normalized ||
        trimmed.startsWith('$normalized ') ||
        trimmed == quoted ||
        trimmed.startsWith('$quoted ');
  }

  static bool _samePath(String a, String b) {
    String normalize(String path) =>
        File(path).absolute.path.replaceAll('/', Platform.pathSeparator);
    final left = normalize(a);
    final right = normalize(b);
    return Platform.isWindows
        ? left.toLowerCase() == right.toLowerCase()
        : left == right;
  }

  static void _deleteConfigFile(String path) {
    try {
      File(path).deleteSync();
    } catch (_) {}
  }

  /// Polls until [port] is free, up to ~2 s. Handles the common race where a
  /// just-killed mihomo process has not yet released the API port.
  static Future<bool> _waitForPortFree(int port) async {
    for (var i = 0; i < 10; i++) {
      if (await _isPortFree(port)) return true;
      await Future.delayed(const Duration(milliseconds: 200));
    }
    return false;
  }

  /// Returns true when [port] can be bound — i.e. nothing else is using it.
  static Future<bool> _isPortFree(int port) async {
    try {
      final s = await ServerSocket.bind(
        InternetAddress.loopbackIPv4,
        port,
        shared: false,
      );
      await s.close();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Poll [port] on 127.0.0.1 until it accepts connections (core is ready).
  /// Aborts early if the process already died (state == error/stopped).
  /// Tries up to 20 times × 200 ms = max 4 seconds.
  Future<bool> _waitForApi(int port) async {
    for (int i = 0; i < 20; i++) {
      if (_state == CoreState.error || _state == CoreState.stopped) {
        return false;
      }
      await Future.delayed(const Duration(milliseconds: 200));
      if (_state == CoreState.error || _state == CoreState.stopped) {
        return false;
      }
      if (await MihomoApiClient.isReady(apiPort: port)) return true;
    }
    return false;
  }

  static String _stripAnsi(String s) =>
      s.replaceAll(RegExp(r'\x1B\[[0-9;]*m'), '').trim();

  void _setState(CoreState s) {
    _state = s;
    if (!_stateCtrl.isClosed) _stateCtrl.add(s);
  }

  void _setError(String msg) {
    _lastError = msg;
    _setState(CoreState.error);
  }
}
