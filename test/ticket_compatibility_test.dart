import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/shared/services/api_client.dart';
import 'package:litchi_client/shared/services/panel_api.dart';

class _RecordingApiClient extends ApiClient {
  String? path;
  Map<String, dynamic>? data;

  @override
  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? data,
    Map<String, dynamic>? headers,
  }) async {
    this.path = path;
    this.data = data;
    return {'data': true};
  }
}

void main() {
  test('creates tickets with the exact EZ and V2Board payload', () async {
    final client = _RecordingApiClient();
    final api = PanelApi(client);

    await api.createTicket(
      subject: 'Connection issue',
      level: 1,
      message: 'Please help diagnose the connection.',
    );

    expect(client.path, '/user/ticket/save');
    expect(client.data, {
      'subject': 'Connection issue',
      'level': 1,
      'message': 'Please help diagnose the connection.',
    });
  });
}
