import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';

import '../../config/app_config.dart';
import 'panel_backend_adapter.dart';
import 'secure_logger.dart';

typedef SessionExpiredCallback = FutureOr<void> Function();

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
  if (data is String && data.trim().isNotEmpty) {
    final text = data.trim();
    // Reverse proxies commonly return a full HTML error document for 404/5xx.
    // It is not a useful user-facing message and may contain large inline
    // images, CSS, or server details.
    if (RegExp(
      r'^(?:<!doctype\s+html|<html|<head|<body)\b',
      caseSensitive: false,
    ).hasMatch(text)) {
      return null;
    }
    const maxMessageLength = 300;
    final bounded = text.length <= maxMessageLength
        ? text
        : '${text.substring(0, maxMessageLength)}…';
    return formatApiErrorMessage(bounded);
  }
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

  /// Request-extra key marking a background/silent poll.
  ///
  /// The session-expired interceptor ignores requests tagged with this key so
  /// a transient 401 on a status timer can never log the user out.
  static const String silentPollExtraKey = 'silentPoll';

  Dio? _dio;
  List<String> _bases = const [];
  int _index = 0;
  String? _authData;

  SessionExpiredCallback? onSessionExpired;

  bool get isConfigured => _bases.isNotEmpty;

  String get _baseUrl => _bases.isEmpty ? '' : _bases[_index];

  /// Configures one or more API base URLs. The client tries them in order and
  /// sticks to the first that responds (see [_withFailover]); a blocked domain
  /// auto-falls back to the next.
  ///
  /// Only `https://` URLs with a non-empty host are accepted; everything else
  /// is silently dropped.  This is enforced here rather than relying solely on
  /// [AppConfig.applyRemote] so that every code path that reaches the API
  /// client is protected.
  void configure(List<String> serverUrls, {String? authData}) {
    _bases = _trustedApiBases(serverUrls);
    _index = 0;
    _authData = authData;
    if (_bases.isNotEmpty) _rebuild();
  }

  /// Atomically replaces API endpoints while preserving the current session.
  ///
  /// Invalid refreshes leave the last known-good client untouched.
  bool updateServerUrls(List<String> serverUrls, {bool forceRebuild = false}) {
    final next = _trustedApiBases(serverUrls);
    if (next.isEmpty) {
      SecureLogger.warn(
        'ApiClient.updateServerUrls: rejected empty trusted API base list',
      );
      return false;
    }
    if (!forceRebuild && _sameBases(_bases, next)) return true;
    _bases = next;
    _index = 0;
    _rebuild();
    return true;
  }

  static List<String> _trustedApiBases(List<String> values) => values
      .map(_normalizeTrustedApiBase)
      .whereType<String>()
      .toList(growable: false);

  static bool _sameBases(List<String> left, List<String> right) {
    if (left.length != right.length) return false;
    for (var i = 0; i < left.length; i++) {
      if (left[i] != right[i]) return false;
    }
    return true;
  }

  static String? _normalizeTrustedApiBase(String value) {
    final trimmed = value.trim().replaceAll(RegExp(r'/+$'), '');
    final uri = Uri.tryParse(trimmed);
    if (uri == null) return null;
    if (uri.scheme != 'https') return null;
    if (uri.host.isEmpty) return null;
    return trimmed;
  }

  void updateAuthData(String? authData) {
    _authData = authData;
    if (_bases.isNotEmpty) _rebuild();
  }

  /// Normalised API path prefix: guaranteed single leading slash, no trailing
  /// slash (so `$base$prefix/passport/...` is always well-formed).
  static String get _pathPrefix {
    var p = AppConfig.apiPrefix.trim();
    if (p.isEmpty) return '';
    if (!p.startsWith('/')) p = '/$p';
    return p.replaceAll(RegExp(r'/+$'), '');
  }

  void _rebuild() {
    _dio = Dio(
      BaseOptions(
        baseUrl: '$_baseUrl$_pathPrefix',
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 15),
        contentType: 'application/json',
        headers: {
          'Accept': 'application/json, text/plain, */*',
          'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
        },
      ),
    );
    // Route through the Windows system proxy when one is active.
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
          if (shouldHandleSessionExpired(response)) {
            final callback = onSessionExpired;
            if (callback != null) unawaited(Future<void>.sync(callback));
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

  /// True when a panel response indicates the session expired and the user
  /// should be logged out.
  ///
  /// Background/silent polls (requests tagged with [silentPollExtraKey]) are
  /// deliberately excluded: a transient 401 on a 60-second status timer must
  /// not kick the user out of the app — real auth expiry is handled the next
  /// time the user performs an action.
  static bool shouldHandleSessionExpired(Response response) {
    if (_isPublicAuthPath(response.requestOptions.path)) return false;
    if (response.requestOptions.extra[silentPollExtraKey] == true) return false;
    final data = response.data;
    if (data is! Map) return false;
    final code = data['code'];
    final msg = data['message']?.toString() ?? '';
    // Treat 401-class code or any "not logged in" message as expired.
    return code == 401 ||
        msg.contains('未登录') ||
        msg.toLowerCase().contains('unauthorized') ||
        msg.toLowerCase().contains('unauthenticated');
  }

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? params,
    bool silent = false,
  }) async {
    _assertReady();
    try {
      final res = await _withFailover(
        () => _getWithRetry(
          () => _dio!.get(
            path,
            queryParameters: params,
            options: silent
                ? Options(extra: {silentPollExtraKey: true})
                : null,
          ),
        ),
      );
      return _parse(res);
    } on DioException catch (e) {
      throw ApiException(_friendlyMessage(e));
    }
  }

  /// Downloads a plain-text resource (e.g. subscription node list) from an
  /// absolute URL.
  ///
  /// **Security**: this uses a standalone [Dio] instance that never carries the
  /// panel Authorization header, so the user's V2Board auth_data cannot leak to
  /// third-party subscription domains or CDNs.  Only `https://` URLs are
  /// accepted; the request does NOT participate in API-base failover because the
  /// URL is already absolute.
  Future<Response<String>> getPlainUrl(
    String url, {
    Map<String, dynamic>? headers,
  }) async {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      throw const ApiException('订阅地址不安全');
    }

    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 15),
        responseType: ResponseType.plain,
        headers: {
          'Accept': '*/*',
          // ignore: use_null_aware_elements
          if (headers != null) ...headers,
        },
      ),
    );

    // Route the subscription download through the system proxy so it can
    // reach blocked domains when the VPN tunnel is active.
    dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () =>
          HttpClient()..findProxy = HttpClient.findProxyFromEnvironment,
    );

    try {
      return await dio.get<String>(url);
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final uri = Uri.tryParse(url);
      final redacted = uri == null
          ? '<invalid-url>'
          : '${uri.scheme}://${uri.host}${uri.path}';
      SecureLogger.warn('getPlainUrl failed status=$status url=$redacted', e);
      throw ApiException(_friendlyMessage(e));
    }
  }

  /// Runs [request] against the current base; on a connection-level failure
  /// (domain unreachable / blocked) rotates to the next base and retries,
  /// cycling through every base once. Sticks to whichever base succeeds.
  ///
  /// **Only used by GET requests.**  POSTs use a narrower failover that
  /// excludes [DioExceptionType.receiveTimeout] to avoid double-submission.
  Future<T> _withFailover<T>(Future<T> Function() request) async {
    var tried = 0;
    while (true) {
      try {
        return await request();
      } on DioException catch (e) {
        tried += 1;
        if (!_isConnLevel(e) || tried >= _bases.length) rethrow;
        SecureLogger.warn('ApiClient failover rotating base attempt=$tried', e);
        _index = (_index + 1) % _bases.length;
        _rebuild();
      }
    }
  }

  /// True when the request could not reach the server at all — DNS failure,
  /// TCP handshake timeout, connection refused / reset.  Rotating to a
  /// different API base may help.
  static bool _isConnLevel(DioException e) => switch (e.type) {
    DioExceptionType.connectionTimeout ||
    DioExceptionType.sendTimeout ||
    DioExceptionType.receiveTimeout ||
    DioExceptionType.connectionError => true,
    _ => false,
  };

  /// True when the request failed *before* the server could have processed it
  /// — DNS, TCP handshake, or connection refused.  Safe for POST retry because
  /// the server never saw the request body.
  ///
  /// [DioExceptionType.receiveTimeout] is deliberately excluded: the server
  /// received and may have already acted on the POST body, so we must not
  /// blindly resubmit.
  static bool _isPreSendConnectionFailure(DioException e) => switch (e.type) {
    DioExceptionType.connectionTimeout ||
    DioExceptionType.connectionError => true,
    _ => false,
  };

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
    Map<String, dynamic>? headers,
  }) async {
    _assertReady();

    var tried = 0;
    while (true) {
      try {
        final backend = PanelBackendAdapter(AppConfig.panelType);
        final res = await _dio!.post(
          path,
          data: backend.preparePostData(path, data),
          options: Options(
            headers: headers,
            contentType: backend.postContentType,
          ),
        );
        return _parse(res);
      } on DioException catch (e) {
        tried += 1;

        // Only rotate to the next API base when the failure happened before
        // the server could have received the request body (DNS / TCP handshake /
        // connection refused).  A receiveTimeout means the server may have
        // already processed the POST — resubmitting would double-charge.
        if (!_isPreSendConnectionFailure(e) || tried >= _bases.length) {
          if (_isPreSendConnectionFailure(e)) {
            throw ApiException(_connectionFailureMessage());
          }
          throw ApiException(_friendlyMessage(e));
        }

        SecureLogger.warn(
          'ApiClient POST failover rotating base attempt=$tried',
          e,
        );
        _index = (_index + 1) % _bases.length;
        _rebuild();
      }
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

  String _connectionFailureMessage() {
    final count = _bases.length;
    if (count <= 1) {
      return '无法连接服务器，请检查网络后重试；如果持续失败，请联系管理员';
    }
    return '已尝试 $count 个服务器仍无法连接，请检查网络后重试；如果持续失败，请联系管理员';
  }

  /// V2Board panels put the human-readable reason (wrong password, account
  /// locked, too many attempts…) in the error body — surface it instead of
  /// a bare status code.
  static String? _serverMessage(DioException e) {
    final data = e.response?.data;
    return extractApiErrorMessage(data);
  }
}
