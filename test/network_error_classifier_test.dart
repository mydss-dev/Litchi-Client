import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/shared/services/network_error_classifier.dart';

void main() {
  test('detects common offline and timeout errors', () {
    expect(
      NetworkErrorClassifier.isNetworkError(
        'SocketException: Failed host lookup: api.example.com',
      ),
      isTrue,
    );
    expect(
      NetworkErrorClassifier.isNetworkError('DioException [receive timeout]'),
      isTrue,
    );
    expect(
      NetworkErrorClassifier.isNetworkError('Connection refused by peer'),
      isTrue,
    );
  });

  test('detects Chinese network error messages', () {
    expect(NetworkErrorClassifier.isNetworkError('超时，请重试'), isTrue);
    expect(NetworkErrorClassifier.isNetworkError('无法连接到服务器'), isTrue);
    expect(NetworkErrorClassifier.isNetworkError('网络请求失败'), isTrue);
    expect(NetworkErrorClassifier.isNetworkError('服务器响应异常'), isTrue);
  });

  test('does not classify authentication failures as network errors', () {
    expect(
      NetworkErrorClassifier.isNetworkError('ApiException: unauthenticated'),
      isFalse,
    );
    expect(
      NetworkErrorClassifier.isNetworkError('ApiException: token expired'),
      isFalse,
    );
  });
}
