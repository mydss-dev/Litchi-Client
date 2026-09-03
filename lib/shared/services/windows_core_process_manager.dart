import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'app_paths.dart';
import 'secure_logger.dart';

/// Runs the Windows main sing-box core outside the Flutter process.
///
/// This process is deliberately always user-owned. It keeps node, DNS, route,
/// selector, mixed/SOCKS and Clash API state. Privileged TUN work belongs to
/// [WindowsTunServiceManager], so changing network layers never changes this
/// process's privilege level or lifetime.
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
  int? get pid => _pid;
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

  Future<bool> start(String configPath, {required int apiPort}) async {
    if (!Platform.isWindows) {
      _lastError = 'Windows core process is only available on Windows';
      return false;
    }
    final previousStopped = await stop();
    if (!previousStopped) {
      if (_lastError.isEmpty) {
        _lastError = '旧的 Windows 主核心无法停止，已取消启动新核心';
      }
      return false;
    }

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
      final process = await Process.start(executable, arguments);
      _process = process;
      _pid = process.pid;
      _pipeProcessOutput(process);
      unawaited(
        process.exitCode.then((code) => _handleProcessExit(generation, code)),
      );
    } catch (error) {
      _lastError = 'Windows 主核心启动失败：$error';
      _clearSession();
      return false;
    }

    final started = await _waitForStartup(generation);
    if (!started) {
      final failure = _lastError.isEmpty ? 'Windows 主核心启动超时' : _lastError;
      await stop();
      _lastError = failure;
      return false;
    }

    _running = true;
    _emitLog(
      '── Windows sing-box 主核心运行中 '
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
    final stopGeneration = ++_generation;
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
        // Keep ownership below so a later stop can retry instead of orphaning
        // the process and accidentally starting a second core beside it.
      }
    }

    _stopping = false;
    if (!graceful) {
      _lastError = 'Windows 主核心停止失败，已保留进程状态以便重试';
      _running = true;
      unawaited(_monitor(stopGeneration));
      return false;
    }

    _running = false;
    _clearSession();
    if (hadSession) _emitLog('── Windows sing-box 主核心已停止 ──');
    return true;
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
        _lastError = '${status?['error'] ?? 'Windows 主核心启动失败'}'.trim();
        if (_lastError.isEmpty) _lastError = 'Windows 主核心启动失败';
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
          _reportUnexpectedExit(generation, 'Windows 主核心进程意外退出');
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
          error.isEmpty ? 'Windows 主核心运行异常' : error,
        );
        return;
      }
    }
  }

  void _handleProcessExit(int generation, int exitCode) {
    if (_stopping || generation != _generation) return;
    if (!_running) {
      if (_lastError.isEmpty) {
        _lastError = 'Windows 主核心进程启动失败 (exit $exitCode)';
      }
      _process = null;
      _pid = null;
      return;
    }
    _reportUnexpectedExit(generation, 'Windows 主核心进程意外退出 (exit $exitCode)');
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
