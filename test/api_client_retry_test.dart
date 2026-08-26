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

  test(
    'rejects an invalid live endpoint refresh without clearing the client',
    () {
      final client = ApiClient()
        ..configure(const ['https://api.example.com'], authData: 'session');

      expect(client.isConfigured, isTrue);
      expect(
        client.updateServerUrls(const ['http://insecure.example.com']),
        isFalse,
      );
      expect(client.isConfigured, isTrue);
    },
  );

  test('silent polls never trigger a session-expired logout', () {
    Response response({bool silent = false, int? code, String message = ''}) {
      return Response(
        requestOptions: RequestOptions(
          path: '/user/info',
          extra: silent ? {ApiClient.silentPollExtraKey: true} : const {},
        ),
        data: {'code': code, 'message': message},
      );
    }

    // Expired responses on normal (user-initiated) requests do log out.
    expect(
      ApiClient.shouldHandleSessionExpired(response(code: 401)),
      isTrue,
    );
    expect(
      ApiClient.shouldHandleSessionExpired(response(message: '未登录')),
      isTrue,
    );
    expect(
      ApiClient.shouldHandleSessionExpired(
        response(message: 'unauthenticated'),
      ),
      isTrue,
    );

    // The same responses on a silent/background poll must NOT log out.
    expect(
      ApiClient.shouldHandleSessionExpired(response(code: 401, silent: true)),
      isFalse,
    );
    expect(
      ApiClient.shouldHandleSessionExpired(
        response(message: '未登录', silent: true),
      ),
      isFalse,
    );

    // Successful responses are ignored.
    expect(
      ApiClient.shouldHandleSessionExpired(response(code: 200)),
      isFalse,
    );

    // Public auth paths are never treated as session-expired.
    final publicPath = Response(
      requestOptions: RequestOptions(path: '/passport/auth/login'),
      data: {'code': 401, 'message': '未登录'},
    );
    expect(ApiClient.shouldHandleSessionExpired(publicPath), isFalse);
  });
}
