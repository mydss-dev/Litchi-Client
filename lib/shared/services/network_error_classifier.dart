abstract final class NetworkErrorClassifier {
  static const _patterns = [
    'timeout',
    'timed out',
    'connection refused',
    'connection reset',
    'connection failed',
    'connection closed',
    'failed host lookup',
    'socketexception',
    'network is unreachable',
    'network request failed',
    'no address associated with hostname',
    'receive timeout',
    'send timeout',
    'connect timeout',
    '超时',
    '无法连接',
    '网络请求失败',
    '服务器响应异常',
  ];

  static bool isNetworkError(Object error) {
    final message = error.toString().toLowerCase();
    return _patterns.any(message.contains);
  }
}
