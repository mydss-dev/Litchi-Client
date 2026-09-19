import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/shared/services/api_client.dart';
import 'package:litchi_client/shared/services/panel_api.dart';

class _StubApiClient extends ApiClient {
  _StubApiClient(this.response);

  final Map<String, dynamic> response;

  @override
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? params,
    bool silent = false,
  }) async => response;
}

void main() {
  test('a real empty plan list is accepted', () async {
    final api = PanelApi(_StubApiClient({'code': 0, 'data': []}));
    expect(await api.getPlans(), isEmpty);
  });

  test('missing plan list throws instead of clearing cached catalog', () async {
    final api = PanelApi(_StubApiClient({'code': 0, 'data': null}));
    await expectLater(api.getPlans(), throwsA(isA<ApiException>()));
  });

  test('malformed plan list item throws instead of filtering it out', () async {
    final api = PanelApi(_StubApiClient({'code': 0, 'data': ['broken']}));
    await expectLater(api.getPlans(), throwsA(isA<ApiException>()));
  });

  test('a real empty traffic list is accepted', () async {
    final api = PanelApi(_StubApiClient({'code': 0, 'data': []}));
    expect(await api.getTrafficLog(), isEmpty);
  });

  test('missing traffic list throws instead of erasing cached history', () async {
    final api = PanelApi(_StubApiClient({'code': 0, 'data': null}));
    await expectLater(api.getTrafficLog(), throwsA(isA<ApiException>()));
  });

  test('malformed traffic entry throws instead of filtering it out', () async {
    final api = PanelApi(_StubApiClient({'code': 0, 'data': [123]}));
    await expectLater(api.getTrafficLog(), throwsA(isA<ApiException>()));
  });
}
