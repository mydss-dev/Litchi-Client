import 'package:dio/dio.dart';

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

  void _rebuild() {
    _dio = Dio(BaseOptions(
      baseUrl: '$_baseUrl/api/v1',
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      contentType: 'application/json',
    ));
    _dio!.interceptors.add(InterceptorsWrapper(
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
  }

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? params,
  }) async {
    _assertReady();
    final res = await _dio!.get(path, queryParameters: params);
    return _parse(res);
  }

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? data,
  }) async {
    _assertReady();
    final res = await _dio!.post(path, data: data);
    return _parse(res);
  }

  Map<String, dynamic> _parse(Response res) {
    if (res.data is Map<String, dynamic>) return res.data as Map<String, dynamic>;
    throw const ApiException('响应格式异常');
  }

  void _assertReady() {
    if (!isConfigured) throw const ApiException('请先配置服务器地址');
  }
}
