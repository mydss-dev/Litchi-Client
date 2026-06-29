import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'secure_logger.dart';
import 'windows_shell.dart';
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

  /// Geo databases mihomo loads for GEOIP/GEOSITE rules. They are bundled next
  /// to the executable by the platform packaging scripts.
  static const _geoFiles = ['country.mmdb', 'geosite.dat', 'geoip.dat'];

  /// Copies any bundled geo databases into the writable home dir if missing, so
  /// the core never has to download them at startup. Best-effort: if a file is
  /// absent or the copy fails, the core falls back to its own download logic and
  /// startup is not blocked.
  static Future<void> _ensureGeoAssets(String exePath) async {
    try {
      final sep = Platform.pathSeparator;
      final exeDir = File(exePath).parent.path;
      final destDir = MihomoConfig.appDataDir();
      await Directory(destDir).create(recursive: true);

      // Where the bundled geo files might live relative to the executable.
      // macOS ships them in the .app bundle's Contents/Resources.
      final sourceDirs = <String>[exeDir, '$exeDir$sep..${sep}Resources'];

      for (final name in _geoFiles) {
        final dest = File('$destDir$sep$name');
        if (await dest.exists()) continue; // keep an already-updated copy
        for (final dir in sourceDirs) {
          final src = File('$dir$sep$name');
          if (await src.exists()) {
            await src.copy(dest.path);
            break;
          }
        }
      }
    } catch (_) {
      // intentional: best-effort staging, failure must not block core startup
    }
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  Future<void> start(String configPath, {int apiPort = 9090}) async {
    if (_state == CoreState.running || _state == CoreState.starting) return;

    final exe = findExecutable();
    if (exe == null) {
      _setError('未找到 mihomo 核心，请重新安装客户端');
      return;
    }

    // Stage the geo databases the core needs (country.mmdb for GEOIP rules,
    // geosite.dat for GEOSITE rules) into the writable home dir before spawning.
    // They ship next to the executable; copying them here means a fresh install
    // never has to download geo data at startup — that download fails behind a
    // firewall and would leave the core unable to start (no API → no latency
    // test, no proxy → no connectivity).
    await _ensureGeoAssets(exe);

    // Kill any previously owned mihomo process (by saved PID).
    await _killSavedPid(expectedExePath: exe);
    // Also sweep any orphans from earlier force-closes that the saved-PID
    // cleanup cannot see — otherwise they keep port 7890 occupied and the new
    // core comes up with a dead proxy port (connected, but no traffic).
    await _killOrphanedCores(exe);

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
      // mihomo logs a non-fatal error and keeps running when it cannot bind the
      // mixed proxy port. In system-proxy mode that means the system proxy then
      // points at a dead port: "connected", but zero traffic. Track it so we can
      // surface a real error instead of a fake "running" state.
      var proxyPortBindFailed = false;
      void handleOutput(String line) {
        outputLines.add(line);
        if (outputLines.length > 50) outputLines.removeAt(0);
        _emitLog(line);
        final lower = line.toLowerCase();
        if (lower.contains('mixed') &&
            lower.contains('server error') &&
            lower.contains('bind')) {
          proxyPortBindFailed = true;
        }
        if (_state == CoreState.starting) {
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
        if (!ready) {
          _setError('核心启动超时 (端口 $apiPort)，请检查配置文件或重试');
          _emitLog('── 启动超时，已停止 ──');
          _process?.kill();
          _process = null;
          _deletePidFile();
          _deleteConfigFile(configPath);
        } else if (proxyPortBindFailed) {
          _setError(
            '代理端口被占用，无法建立连接。请关闭占用该端口的程序'
            '（或残留的 mihomo 进程）后重试，或在设置里更换代理端口。',
          );
          _emitLog('── 代理端口被占用，已停止 ──');
          _process?.kill();
          _process = null;
          _deletePidFile();
          _deleteConfigFile(configPath);
        } else {
          _emitLog('── mihomo 运行中 (PID ${_process!.pid}) ──');
          _setState(CoreState.running);
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
    await _killOrphanedCores(findExecutable());
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
      } catch (_) {
        // intentional: parse attempt, corrupt PID file is safe to ignore
      }
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
    } catch (_) {
      // intentional: best-effort process cleanup, failure is safe to ignore
    }
  }

  /// Kills EVERY stray mihomo whose executable path matches our bundled core,
  /// not just the single PID we last recorded. The old single-PID cleanup
  /// could not reclaim cores orphaned by earlier force-closes/crashes, so they
  /// accumulated (dozens of mihomo.exe holding port 7890 + the cache file).
  /// Scoped by exe path so other apps' mihomo instances are left untouched.
  /// Best-effort: any failure leaves the previous behaviour unchanged.
  static Future<void> _killOrphanedCores(String? exePath) async {
    if (exePath == null || exePath.isEmpty) return;
    try {
      if (Platform.isWindows) {
        final escaped = exePath.replaceAll("'", "''");
        await Process.run('powershell', [
          '-NoProfile',
          '-NonInteractive',
          '-Command',
          "Get-CimInstance Win32_Process -Filter \"Name='mihomo.exe'\" | "
              "Where-Object { \$_.ExecutablePath -ieq '$escaped' } | "
              "ForEach-Object { Stop-Process -Id \$_.ProcessId -Force "
              "-ErrorAction SilentlyContinue }",
        ]).timeout(const Duration(seconds: 5));
      } else {
        // Matches processes whose command line contains our exe path.
        await Process.run('pkill', ['-f', exePath])
            .timeout(const Duration(seconds: 5));
      }
      // Let the OS release the listening ports the killed cores held.
      await Future.delayed(const Duration(milliseconds: 400));
    } catch (_) {
      // intentional: best-effort sweep, failure is safe to ignore
    }
  }

  static void _deletePidFile() {
    try {
      _pidFile.deleteSync();
    } catch (_) {
      // intentional: best-effort file cleanup, failure is safe to ignore
    }
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
        return getProcessImagePath(pid);
      }
      if (Platform.isLinux) {
        try {
          final link = File('/proc/$pid/exe');
          if (link.existsSync()) {
            return link.resolveSymbolicLinksSync();
          }
        } catch (_) {
          // Fall through to generic ps method.
        }
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
    } catch (e) {
      SecureLogger.debug('_processPath: ps query failed for pid=$pid', e);
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
    } catch (e) {
      SecureLogger.debug('_processCommand: ps query failed for pid=$pid', e);
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
    } catch (_) {
      // intentional: best-effort config file cleanup, failure is safe to ignore
    }
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
      // intentional: port check failed, treat as unavailable
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
