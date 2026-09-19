import 'network_error_classifier.dart';

/// Only an explicit authentication failure may invalidate a stored session.
/// A failed catalog, malformed response, banned plan or unexpected runtime
/// exception does not prove that the auth token has expired.
enum SessionFailureKind { authentication, network, other }

abstract final class SessionFailurePolicy {
  static SessionFailureKind classify(Object error) {
    final message = error.toString().toLowerCase();
    // The API client emits a status fallback when HTTP 401 has no JSON body;
    // keep that explicit unauthorized signal instead of silently retaining a
    // definitively invalid token. Do not classify arbitrary 401 text.
    final unauthenticatedHttp =
        message.contains('服务器响应异常（401）') ||
        message.contains('服务器响应异常(401)') ||
        message.contains('server response error (401)');
    if (unauthenticatedHttp ||
        message.contains('登录已过期') ||
        message.contains('未登录') ||
        message.contains('登录失效') ||
        message.contains('认证已过期') ||
        message.contains('unauthenticated') ||
        message.contains('unauthorized') ||
        message.contains('invalid token') ||
        message.contains('token expired') ||
        message.contains('token invalid')) {
      return SessionFailureKind.authentication;
    }
    if (NetworkErrorClassifier.isNetworkError(error)) {
      return SessionFailureKind.network;
    }
    return SessionFailureKind.other;
  }

  static String syncError(Object error) => switch (classify(error)) {
    SessionFailureKind.authentication => '登录已过期，请重新登录',
    SessionFailureKind.network => '服务器连接失败，已保留现有数据，请检查网络后重试',
    SessionFailureKind.other => '数据同步失败，已保留现有数据，请稍后重试',
  };
}
