import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';

typedef SessionExpiredCallback = void Function();

/// Thrown when the remote API returns a non-success response.
class ApiException implements Exception {
  final String message;
  const ApiException(this.message);

  @override
  String toString() => message;
}

class ApiClient {
  Dio? _dio;
  String _baseUrl = '';
  String? _authData;

  /// Active Windows system proxy as "host:port", or null when none is set.
  /// Dio is routed through it so a geo-blocked API panel domain is reachable
  /// whenever the user has a proxy (Clash / v2rayN in system-proxy mode) up.
  String? _proxy;

  SessionExpiredCallback? onSessionExpired;

  bool get isConfigured => _baseUrl.isNotEmpty;

  void configure(String serverUrl, {String? authData}) {
    _baseUrl = serverUrl.trim().replaceAll(RegExp(r'/+$'), '');
    _authData = authData;
    _rebuild();
  }

  void updateAuthData(String? authData) {
    _authData = authData;
    if (_baseUrl.isNotEmpty) _rebuild();
  }

  /// Re-reads the Windows system proxy and, if it changed, rebuilds Dio to
  /// route through it. Call before login and on token-based startup so the
  /// request goes out through whatever proxy the user currently has running.
  Future<void> refreshSystemProxy() async {
    final p = await _readSystemProxy();
    if (p != _proxy) {
      _proxy = p;
      if (_baseUrl.isNotEmpty) _rebuild();
    }
  }

  static Future<String?> _readSystemProxy() async {
    if (!Platform.isWindows) return null;
    try {
      const key =
          r'HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings';
      final en = await Process.run('reg', ['query', key, '/v', 'ProxyEnable']);
      if (!'${en.stdout}'.contains('0x1')) return null; // proxy disabled
      final sv = await Process.run('reg', ['query', key, '/v', 'ProxyServer']);
      final m =
          RegExp(r'ProxyServer\s+REG_SZ\s+(\S+)').firstMatch('${sv.stdout}');
      var v = m?.group(1)?.trim();
      if (v == null || v.isEmpty) return null;
      // Per-protocol form "http=host:port;https=host:port" → pick https/first.
      if (v.contains('=')) {
        final parts = v.split(';');
        final https = parts.firstWhere(
          (p) => p.startsWith('https='),
          orElse: () => parts.first,
        );
        v = https.split('=').last.trim();
      }
      return v.isEmpty ? null : v;
    } catch (_) {
      return null;
    }
  }

  void _rebuild() {
    final dio = Dio(BaseOptions(
      baseUrl: '$_baseUrl/api/v1',
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      contentType: 'application/json',
    ));

    final proxy = _proxy;
    if (proxy != null && proxy.isNotEmpty) {
      dio.httpClientAdapter = IOHttpClientAdapter(
        createHttpClient: () {
          final client = HttpClient();
          client.findProxy = (_) => 'PROXY $proxy';
          return client;
        },
      );
    }

    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (_authData != null && _authData!.isNotEmpty) {
          options.headers['Authorization'] = _authData;
        }
        handler.next(options);
      },
      onResponse: (response, handler) {
        final data = response.data;
        if (data is Map) {
          final code = data['code'];
          final msg  = data['message']?.toString() ?? '';
          // Treat 401-class code or any "not logged in" message as expired.
          final isExpired = code == 401 ||
              msg.contains('未登录') ||
              msg.toLowerCase().contains('unauthorized') ||
              msg.toLowerCase().contains('unauthenticated');
          if (isExpired) onSessionExpired?.call();
        }
        handler.next(response);
      },
    ));

    _dio = dio;
  }

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? params,
  }) async {
    _assertReady();
    try {
      final res = await _dio!.get(path, queryParameters: params);
      return _parse(res);
    } on DioException catch (e) {
      throw ApiException(_friendlyMessage(e));
    }
  }

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? data,
  }) async {
    _assertReady();
    try {
      final res = await _dio!.post(path, data: data);
      return _parse(res);
    } on DioException catch (e) {
      throw ApiException(_friendlyMessage(e));
    }
  }

  Map<String, dynamic> _parse(Response res) {
    if (res.data is Map<String, dynamic>) return res.data as Map<String, dynamic>;
    throw const ApiException('响应格式异常');
  }

  void _assertReady() {
    if (!isConfigured) throw const ApiException('请先配置服务器地址');
  }

  static String _friendlyMessage(DioException e) {
    return switch (e.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout =>
        '连接超时，请检查网络后重试',
      DioExceptionType.connectionError => '无法连接到服务器，请检查网络',
      DioExceptionType.badResponse =>
        '服务器响应异常（${e.response?.statusCode ?? '未知'}）',
      _ => '网络请求失败，请重试',
    };
  }
}
