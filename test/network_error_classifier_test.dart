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
