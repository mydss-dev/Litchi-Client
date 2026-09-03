import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';

import 'app_paths.dart';
import 'secure_logger.dart';
import 'windows_core_process_manager.dart';
import 'windows_dpapi.dart';

/// Controls the persistent privileged Windows TUN service.
///
/// The normal `litchi-core.exe` remains a user-owned main core for node, DNS,
/// selector and Clash API state. This service owns only the TUN interface and
/// forwards it to the main core's loopback SOCKS/mixed port. The service is
/// installed on first TUN use and survives app restarts, so UAC is not part of
/// every connect/disconnect cycle.
final class WindowsTunServiceManager {
  static const _credentialFileName = 'tun_service.cred';

  final _exitController = StreamController<String>.broadcast();
  _TunCredentials? _cachedCredentials;
  String _lastError = '';
  bool _running = false;
  bool _stopping = false;
  int _generation = 0;

  bool get isRunning => _running;
  String get lastError => _lastError;
  Stream<String> get exitStream => _exitController.stream;

  Future<bool> start({
    required int mainProxyPort,
    int mtu = 1500,
    bool strictRoute = false,
    String stack = 'system',
  }) async {
    if (!Platform.isWindows) {
      _lastError = 'Windows TUN service is only available on Windows';
      return false;
    }
    _lastError = '';
    _stopping = false;
    final generation = ++_generation;

    var credentials = await _loadOrCreateCredentials();
    if (!await _serviceReady(credentials)) {
      // A non-Litchi listener or stale service credentials on our saved port
      // must not be trusted. Move to a new random loopback port/token before
      // reinstalling the privileged service.
      if (!await _portAvailable(credentials.port)) {
        credentials = await _createCredentials();
      }
      final installed = await _installService(credentials);
      if (!installed) return false;
      if (!await _waitForService(credentials)) {
        if (_lastError.isEmpty) {
          _lastError = 'Windows TUN 服务安装完成但控制接口未就绪';
        }
        return false;
      }
    }

    final response = await _request(
      credentials,
      'POST',
      '/start',
      body: {
        'main_proxy_port': mainProxyPort,
        'mtu': mtu,
        'strict_route': strictRoute,
        'stack': stack,
      },
      timeout: const Duration(seconds: 12),
    );
    final state = '${response?.body?['state'] ?? ''}';
    if (response?.statusCode != HttpStatus.ok || state != 'running') {
      final detail = '${response?.body?['error'] ?? ''}'.trim();
      _lastError = detail.isEmpty ? 'Windows TUN 服务启动失败' : detail;
      _running = false;
      return false;
    }

    _running = true;
    unawaited(_monitor(credentials, generation));
    return true;
  }

  Future<bool> stop() async {
    if (!Platform.isWindows) return true;
    _stopping = true;
    ++_generation;
    final credentials = await _loadCredentials();
    if (credentials == null) {
      _running = false;
      _stopping = false;
      return true;
    }
    final response = await _request(
      credentials,
      'POST',
      '/stop',
      timeout: const Duration(seconds: 8),
    );
    // A missing service is already a stopped TUN from the app's perspective.
    final stopped = response == null ||
        (response.statusCode == HttpStatus.ok &&
            '${response.body?['state'] ?? ''}' != 'running');
    if (!stopped) {
      final detail = '${response.body?['error'] ?? ''}'.trim();
      _lastError = detail.isEmpty ? 'Windows TUN 服务停止失败' : detail;
    }
    _running = false;
    _stopping = false;
    return stopped;
  }

  Future<void> cleanupOnStartup() async {
    if (!Platform.isWindows) return;
    // If the previous GUI crashed, the service also has its own main-port
    // watchdog. This explicit stop makes startup convergence immediate.
    await stop();
    _lastError = '';
  }

  void dispose() {
    ++_generation;
    _running = false;
    if (!_exitController.isClosed) {
      unawaited(_exitController.close());
    }
  }

  Future<void> _monitor(_TunCredentials credentials, int generation) async {
    var missed = 0;
    while (_running && !_stopping && generation == _generation) {
      await Future<void>.delayed(const Duration(seconds: 1));
      if (!_running || _stopping || generation != _generation) return;
      final response = await _request(credentials, 'GET', '/status');
      if (response?.statusCode != HttpStatus.ok) {
        missed += 1;
        if (missed < 3) continue;
        _reportUnexpectedStop(generation, 'Windows TUN 服务失去响应');
        return;
      }
      missed = 0;
      final state = '${response?.body?['state'] ?? ''}';
      if (state == 'running') continue;
      final detail = '${response?.body?['error'] ?? ''}'.trim();
      _reportUnexpectedStop(
        generation,
        detail.isEmpty ? 'Windows TUN 服务意外停止' : detail,
      );
      return;
    }
  }

  void _reportUnexpectedStop(int generation, String message) {
    if (_stopping || generation != _generation || !_running) return;
    _running = false;
    _lastError = message;
    if (!_exitController.isClosed) _exitController.add(message);
  }

  Future<bool> _serviceReady(_TunCredentials credentials) async {
    final response = await _request(credentials, 'GET', '/status');
    return response?.statusCode == HttpStatus.ok;
  }

  Future<bool> _waitForService(_TunCredentials credentials) async {
    final deadline = DateTime.now().add(const Duration(seconds: 12));
    while (DateTime.now().isBefore(deadline)) {
      if (await _serviceReady(credentials)) return true;
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    return false;
  }

  Future<bool> _installService(_TunCredentials credentials) async {
    final executable = WindowsCoreProcessManager.findExecutable();
    if (executable == null) {
      _lastError = '缺少 Windows 核心文件 litchi-core.exe';
      return false;
    }
    final authHash = sha256.convert(utf8.encode(credentials.token)).toString();
    final arguments = [
      'tun-service',
      'install',
      '--auth-hash',
      authHash,
      '--port',
      '${credentials.port}',
    ];
    try {
      final exitCode = await _runElevatedAndWait(executable, arguments);
      if (exitCode != 0) {
        _lastError = 'Windows TUN 服务安装失败 (exit $exitCode)';
        return false;
      }
      return true;
    } catch (error) {
      final text = '$error'.replaceFirst('Bad state: ', '');
      _lastError = text.contains('管理员授权')
          ? text
          : 'Windows TUN 服务安装失败：$text';
      return false;
    }
  }

  Future<_TunCredentials> _loadOrCreateCredentials() async {
    final existing = await _loadCredentials();
    return existing ?? _createCredentials();
  }

  Future<_TunCredentials?> _loadCredentials() async {
    final cached = _cachedCredentials;
    if (cached != null) return cached;
    try {
      final file = File(_credentialPath);
      if (!await file.exists()) return null;
      final protected = (await file.readAsString()).trim();
      final clear = WindowsDpapi.unprotect(protected);
      if (clear == null || clear.isEmpty) return null;
      final decoded = jsonDecode(clear);
      if (decoded is! Map) return null;
      final token = '${decoded['token'] ?? ''}'.trim();
      final port = decoded['port'];
      final parsedPort = port is num ? port.toInt() : int.tryParse('$port');
      if (token.length < 32 || parsedPort == null || parsedPort <= 1024 || parsedPort > 65535) {
        return null;
      }
      return _cachedCredentials = _TunCredentials(token, parsedPort);
    } catch (error) {
      SecureLogger.debug('TUN service credentials load failed', error);
      return null;
    }
  }

  Future<_TunCredentials> _createCredentials() async {
    final random = Random.secure();
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final token = List.generate(
      64,
      (_) => chars[random.nextInt(chars.length)],
    ).join();
    final port = await _allocatePort();
    final credentials = _TunCredentials(token, port);
    final clear = jsonEncode({'token': token, 'port': port});
    final protected = WindowsDpapi.protect(clear);
    if (protected == null || protected.isEmpty) {
      throw StateError('无法保护 Windows TUN 服务凭据');
    }
    final directory = Directory(AppPaths.dataDirectory);
    await directory.create(recursive: true);
    await File(_credentialPath).writeAsString(protected, flush: true);
    _cachedCredentials = credentials;
    return credentials;
  }

  String get _credentialPath =>
      '${AppPaths.dataDirectory}${Platform.pathSeparator}$_credentialFileName';

  Future<_TunResponse?> _request(
    _TunCredentials credentials,
    String method,
    String path, {
    Map<String, dynamic>? body,
    Duration timeout = const Duration(seconds: 2),
  }) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 1);
    try {
      final uri = Uri.parse('http://127.0.0.1:${credentials.port}$path');
      final request = method == 'POST'
          ? await client.postUrl(uri).timeout(timeout)
          : await client.getUrl(uri).timeout(timeout);
      request.headers.set('X-Litchi-Tun-Token', credentials.token);
      if (body != null) {
        request.headers.contentType = ContentType.json;
        request.write(jsonEncode(body));
      } else if (method == 'POST') {
        request.contentLength = 0;
      }
      final response = await request.close().timeout(timeout);
      final text = await utf8.decoder.bind(response).join().timeout(timeout);
      Map<String, dynamic>? decoded;
      if (text.trim().isNotEmpty) {
        try {
          final value = jsonDecode(text);
          if (value is Map) {
            decoded = value.map((key, value) => MapEntry('$key', value));
          }
        } catch (_) {
          // Non-JSON responses are represented by status code only.
        }
      }
      return _TunResponse(response.statusCode, decoded);
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }

  static Future<bool> _portAvailable(int port) async {
    ServerSocket? socket;
    try {
      socket = await ServerSocket.bind(
        InternetAddress.loopbackIPv4,
        port,
        shared: false,
      );
      return true;
    } catch (_) {
      return false;
    } finally {
      await socket?.close();
    }
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

  static Future<int> _runElevatedAndWait(
    String executable,
    List<String> arguments,
  ) async {
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
  \$process.WaitForExit()
  exit \$process.ExitCode
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
    if (result.exitCode != 0 && '${result.stderr}'.trim().isNotEmpty) {
      throw StateError('${result.stderr}'.trim());
    }
    return result.exitCode;
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
}

final class _TunCredentials {
  const _TunCredentials(this.token, this.port);
  final String token;
  final int port;
}

final class _TunResponse {
  const _TunResponse(this.statusCode, this.body);
  final int statusCode;
  final Map<String, dynamic>? body;
}
