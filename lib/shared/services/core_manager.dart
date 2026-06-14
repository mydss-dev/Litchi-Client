import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'secure_logger.dart';

enum CoreState { stopped, starting, running, error }

/// Manages the sing-box process lifecycle.
class CoreManager {
  Process? _process;
  CoreState _state = CoreState.stopped;
  String _lastError = '';

  final _stateCtrl = StreamController<CoreState>.broadcast();
  final _logCtrl   = StreamController<String>.broadcast();

  CoreState get state      => _state;
  String get lastError     => _lastError;
  bool get isRunning       => _state == CoreState.running;
  Stream<CoreState> get stateStream => _stateCtrl.stream;

  /// Emits stripped log lines from sing-box stdout + stderr.
  Stream<String> get logStream => _logCtrl.stream;

  // ── PID file ──────────────────────────────────────────────────────────────

  static File get _pidFile {
    final tmp = Platform.environment['TEMP'] ??
        Platform.environment['TMP'] ??
        Directory.systemTemp.path;
    return File('$tmp\\litchi_singbox.pid');
  }

  // ── Executable discovery ──────────────────────────────────────────────────

  static String? findExecutable() {
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    final candidates = [
      '$exeDir\\sing-box.exe',
      '$exeDir\\core\\sing-box.exe',
      '${Platform.environment['LOCALAPPDATA']}\\LitchiClient\\sing-box.exe',
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
      _setError('未找到 sing-box.exe，请将其放置在应用目录下');
      return;
    }

    // Kill any previously owned sing-box process (by saved PID).
    await _killSavedPid();

    // Verify the API port is actually free before we try to start.
    if (!await _isPortFree(apiPort)) {
      _setError('端口 $apiPort 已被占用，请关闭其他代理软件后重试');
      return;
    }

    _lastError = '';
    _setState(CoreState.starting);
    _emitLog('── sing-box 启动中 ──');

    try {
      _process = await Process.start(exe, ['run', '-c', configPath]);

      // Save PID so the next startup can clean this process up if we crash.
      await _pidFile.writeAsString(_process!.pid.toString());

      _process!.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) => _emitLog(line));

      final stderrLines = <String>[];
      _process!.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
        stderrLines.add(line);
        _emitLog(line);
        if (_state == CoreState.starting) {
          final lower = line.toLowerCase();
          if (lower.contains('fatal') || lower.contains('error')) {
            _lastError = _stripAnsi(line);
          }
        }
      });

      unawaited(_process!.exitCode.then((code) {
        if (_state == CoreState.running || _state == CoreState.starting) {
          if (_lastError.isEmpty && stderrLines.isNotEmpty) {
            _lastError = _stripAnsi(stderrLines.last);
          }
          if (_lastError.isEmpty) _lastError = '核心进程退出 (code: $code)';
          _setState(CoreState.error);
          _process = null;
          _deletePidFile();
        }
      }));

      // Poll the Clash API port to confirm sing-box is actually ready.
      final ready = await _waitForPort(apiPort);

      if (_process != null && _state != CoreState.error) {
        if (ready) {
          _emitLog('── sing-box 运行中 (PID ${_process!.pid}) ──');
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
      if (raw.contains('Access is denied') || raw.contains('access')) {
        msg = '权限不足，请以管理员身份运行客户端';
      } else if (raw.contains('No such file') || raw.contains('系统找不到')) {
        msg = '未找到 sing-box.exe，请检查文件是否存在';
      } else {
        msg = '启动失败，请检查 sing-box.exe 是否完整';
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
    _emitLog('── sing-box 已停止 ──');
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

  /// Called at app startup to kill any orphaned sing-box process left by a
  /// previous crash and remove the stale PID file.
  static Future<void> cleanupOnStartup() => _killSavedPid();

  /// Kill the specific sing-box process we previously spawned (by saved PID).
  /// This only affects our own process — not any other sing-box instances.
  static Future<void> _killSavedPid() async {
    try {
      if (!await _pidFile.exists()) return;
      final pidStr = (await _pidFile.readAsString()).trim();
      final pid = int.tryParse(pidStr);
      if (pid == null) {
        await _pidFile.delete();
        return;
      }
      await Process.run(
        'taskkill',
        ['/F', '/PID', pid.toString()],
        runInShell: true,
      );
      await _pidFile.delete();
      // Give the OS a moment to release the port.
      await Future.delayed(const Duration(milliseconds: 400));
    } catch (_) {}
  }

  static void _deletePidFile() {
    try { _pidFile.deleteSync(); } catch (_) {}
  }

  static void _deleteConfigFile(String path) {
    try { File(path).deleteSync(); } catch (_) {}
  }

  /// Returns true when [port] can be bound — i.e. nothing else is using it.
  static Future<bool> _isPortFree(int port) async {
    try {
      final s = await ServerSocket.bind(
        InternetAddress.loopbackIPv4, port,
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
  Future<bool> _waitForPort(int port) async {
    for (int i = 0; i < 20; i++) {
      if (_state == CoreState.error || _state == CoreState.stopped) {
        return false;
      }
      await Future.delayed(const Duration(milliseconds: 200));
      if (_state == CoreState.error || _state == CoreState.stopped) {
        return false;
      }
      try {
        final socket = await Socket.connect(
          '127.0.0.1', port,
          timeout: const Duration(milliseconds: 300),
        );
        socket.destroy();
        return true;
      } catch (_) {}
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
