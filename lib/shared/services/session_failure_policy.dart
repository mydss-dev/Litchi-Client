import 'network_error_classifier.dart';

/// Only an explicit authentication failure may invalidate a stored session.
/// A failed catalog, malformed response, banned plan or unexpected runtime
/// exception does not prove that the auth token has expired.
enum SessionFailureKind { authentication, network, other }

abstract final class SessionFailurePolicy {
  static SessionFailureKind classify(Object error) {
    final message = error.toString().toLowerCase();
    // Prefer auth evidence to generic text such as "server response error".
    if (message.contains('登录已过期') ||
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
