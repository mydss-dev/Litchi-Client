import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';

typedef SessionExpiredCallback = void Function();

/// Thrown when the remote API returns a non-success response.
class ApiException implements Exception {
  final String message;
  const ApiException(this.message);

  @override
  String toString() => formatApiErrorMessage(message);
}

String formatApiErrorMessage(String message) {
  final text = message.trim();
  if (text.isEmpty) return '请求失败，请稍后重试';
  final lower = text.toLowerCase();
  if (lower == 'the given data was invalid.' ||
      lower == 'the given data was invalid') {
    return '提交内容有误，请检查后重试';
  }
  if (lower.contains('unauthenticated') || lower.contains('unauthorized')) {
    return '登录已过期，请重新登录';
  }
  if (lower.contains('server error')) {
    return '服务器暂时不可用，请稍后重试';
  }
  if (lower.contains('too many attempts')) {
    return '操作太频繁，请稍后再试';
  }
  return text;
}

String? extractApiErrorMessage(Object? data) {
  if (data is Map) {
    final details =
        _firstValidationMessage(data['errors']) ??
        _firstValidationMessage(data['data']);
    final message = data['message']?.toString();
    if (details != null &&
        (message == null ||
            message.isEmpty ||
            formatApiErrorMessage(message) == '提交内容有误，请检查后重试')) {
      return formatApiErrorMessage(details);
    }
    if (message != null && message.isNotEmpty) {
      return formatApiErrorMessage(message);
    }
  }
  if (data is String && data.isNotEmpty) return formatApiErrorMessage(data);
  return null;
}

String? _firstValidationMessage(Object? value) {
  if (value is Map) {
    for (final item in value.values) {
      final found = _firstValidationMessage(item);
      if (found != null) return found;
    }
  }
  if (value is List) {
    for (final item in value) {
      final found = _firstValidationMessage(item);
      if (found != null) return found;
    }
  }
  if (value is String && value.trim().isNotEmpty) return value.trim();
  return null;
}

class ApiClient {
  static const int maxGetRetries = 2;

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
    _dio = Dio(
      BaseOptions(
        baseUrl: '$_baseUrl/api/v1',
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
        contentType: 'application/json',
      ),
    );
    // Route through the Windows system proxy when one is active (e.g. sing-box).
    // This allows API calls to reach blocked domains via the VPN tunnel.
    _dio!.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () =>
          HttpClient()..findProxy = HttpClient.findProxyFromEnvironment,
    );
    _dio!.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (_authData != null &&
              _authData!.isNotEmpty &&
              !_isPublicAuthPath(options.path)) {
            options.headers['Authorization'] = _authData;
          }
          handler.next(options);
        },
        onResponse: (response, handler) {
          final data = response.data;
          if (data is Map) {
            final code = data['code'];
            final msg = data['message']?.toString() ?? '';
            // Treat 401-class code or any "not logged in" message as expired.
            final isExpired =
                code == 401 ||
                msg.contains('未登录') ||
                msg.toLowerCase().contains('unauthorized') ||
                msg.toLowerCase().contains('unauthenticated');
            if (isExpired && !_isPublicAuthPath(response.requestOptions.path)) {
              onSessionExpired?.call();
            }
          }
          handler.next(response);
        },
      ),
    );
  }

  static bool _isPublicAuthPath(String path) {
    final uri = Uri.tryParse(path);
    final normalized = uri?.path ?? path;
    return normalized.startsWith('/guest/') ||
        normalized.startsWith('/passport/');
  }

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? params,
  }) async {
    _assertReady();
    try {
      final res = await _getWithRetry(
        () => _dio!.get(path, queryParameters: params),
      );
      return _parse(res);
    } on DioException catch (e) {
      throw ApiException(_friendlyMessage(e));
    }
  }

  Future<Response<String>> getPlainUrl(
    String url, {
    Map<String, dynamic>? headers,
  }) async {
    final dio = _dio;
    if (dio == null) {
      throw const ApiException('请先配置服务器地址');
    }
    try {
      return await _getWithRetry(
        () => dio.get<String>(
          url,
          options: Options(responseType: ResponseType.plain, headers: headers),
        ),
      );
    } on DioException catch (e) {
      throw ApiException(_friendlyMessage(e));
    }
  }

  Future<Response<T>> _getWithRetry<T>(
    Future<Response<T>> Function() request,
  ) async {
    var attempt = 0;
    while (true) {
      try {
        return await request();
      } on DioException catch (e) {
        if (attempt >= maxGetRetries || !isRetriableGetError(e)) rethrow;
        attempt += 1;
        await Future.delayed(Duration(milliseconds: 250 * attempt));
      }
    }
  }

  static bool isRetriableGetError(DioException e) {
    return switch (e.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.connectionError => true,
      DioExceptionType.badResponse => _isRetriableStatus(
        e.response?.statusCode,
      ),
      _ => false,
    };
  }

  static bool _isRetriableStatus(int? statusCode) {
    if (statusCode == null) return false;
    return statusCode == 429 || statusCode >= 500;
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
    if (res.data is Map<String, dynamic>) {
      return res.data as Map<String, dynamic>;
    }
    throw const ApiException('响应格式异常');
  }

  void _assertReady() {
    if (!isConfigured) {
      throw const ApiException('请先配置服务器地址');
    }
  }

  static String _friendlyMessage(DioException e) {
    return switch (e.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout => '连接超时，请检查网络后重试',
      DioExceptionType.connectionError => '无法连接到服务器，请检查网络',
      DioExceptionType.badResponse =>
        _serverMessage(e) ?? '服务器响应异常（${e.response?.statusCode ?? '未知'}）',
      _ => '网络请求失败，请重试',
    };
  }

  /// V2Board panels put the human-readable reason (wrong password, account
  /// locked, too many attempts…) in the error body — surface it instead of
  /// a bare status code.
  static String? _serverMessage(DioException e) {
    final data = e.response?.data;
    return extractApiErrorMessage(data);
  }
}
