import 'dart:async';
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
          process.exitCode.then((code) => _handleProcessExit(generation, code)),
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
    _reportUnexpectedExit(generation, 'Windows 核心进程意外退出 (exit $exitCode)');
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
      final body = await utf8.decoder
          .bind(response)
          .join()
          .timeout(const Duration(milliseconds: 700));
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
      final response = await request.close().timeout(
        const Duration(seconds: 1),
      );
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

  Future<int> _launchElevated(String executable, List<String> arguments) async {
    final argumentLine = arguments.map(_quoteWindowsArgument).join(' ');
    final exeBase64 = base64Encode(utf8.encode(executable));
    final argsBase64 = base64Encode(utf8.encode(argumentLine));
    final script =
        """
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
""";
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
      throw StateError(detail.isEmpty ? '无法以管理员权限启动 Windows TUN 核心' : detail);
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
