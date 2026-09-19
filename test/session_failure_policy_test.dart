import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/shared/services/api_client.dart';
import 'package:litchi_client/shared/services/session_failure_policy.dart';

void main() {
  test('explicit token expiry is an authentication failure', () {
    expect(
      SessionFailurePolicy.classify(const ApiException('登录已过期，请重新登录')),
      SessionFailureKind.authentication,
    );
    expect(
      SessionFailurePolicy.classify(const ApiException('Unauthenticated.')),
      SessionFailureKind.authentication,
    );
    expect(
      SessionFailurePolicy.classify(const ApiException('Invalid token')),
      SessionFailureKind.authentication,
    );
  });

  test('an explicit HTTP 401 response fallback expires the session', () {
    expect(
      SessionFailurePolicy.classify(const ApiException('服务器响应异常（401）')),
      SessionFailureKind.authentication,
    );
    expect(
      SessionFailurePolicy.classify(const ApiException('服务器响应异常（500）')),
      SessionFailureKind.network,
    );
  });

  test('transport failures permit cached-mode handling', () {
    expect(
      SessionFailurePolicy.classify(const ApiException('连接超时，请检查网络后重试')),
      SessionFailureKind.network,
    );
    expect(
      SessionFailurePolicy.classify(const ApiException('无法连接到服务器')),
      SessionFailureKind.network,
    );
  });

  test('server format, plan and validation failures are not logout triggers', () {
    for (final message in [
      '服务器返回数据格式异常',
      '响应格式异常',
      '套餐已过期',
      '账户已被停用',
      '提交内容有误，请检查后重试',
    ]) {
      expect(
        SessionFailurePolicy.classify(ApiException(message)),
        SessionFailureKind.other,
        reason: message,
      );
    }
  });

  test('unexpected runtime errors do not prove token expiry', () {
    expect(
      SessionFailurePolicy.classify(StateError('bad parser state')),
      SessionFailureKind.other,
    );
  });
}
