import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/shared/services/api_client.dart';

void main() {
  DioException error({required DioExceptionType type, int? statusCode}) {
    final options = RequestOptions(path: '/user/info');
    return DioException(
      requestOptions: options,
      type: type,
      response: statusCode == null
          ? null
          : Response(requestOptions: options, statusCode: statusCode),
    );
  }

  test('retries transient get failures', () {
    expect(
      ApiClient.isRetriableGetError(
        error(type: DioExceptionType.connectionTimeout),
      ),
      isTrue,
    );
    expect(
      ApiClient.isRetriableGetError(
        error(type: DioExceptionType.connectionError),
      ),
      isTrue,
    );
    expect(
      ApiClient.isRetriableGetError(
        error(type: DioExceptionType.badResponse, statusCode: 500),
      ),
      isTrue,
    );
    expect(
      ApiClient.isRetriableGetError(
        error(type: DioExceptionType.badResponse, statusCode: 429),
      ),
      isTrue,
    );
  });

  test('does not retry validation or auth failures', () {
    expect(
      ApiClient.isRetriableGetError(
        error(type: DioExceptionType.badResponse, statusCode: 400),
      ),
      isFalse,
    );
    expect(
      ApiClient.isRetriableGetError(
        error(type: DioExceptionType.badResponse, statusCode: 401),
      ),
      isFalse,
    );
    expect(
      ApiClient.isRetriableGetError(error(type: DioExceptionType.cancel)),
      isFalse,
    );
  });

  test('does not expose an HTML error page as an API message', () {
    expect(
      extractApiErrorMessage(
        '<!doctype html><html><head><title>404 Not Found</title></head></html>',
      ),
      isNull,
    );
  });

  test('bounds plain-text server error messages', () {
    final message = extractApiErrorMessage('x' * 500);

    expect(message, hasLength(301));
    expect(message, endsWith('…'));
  });
}
