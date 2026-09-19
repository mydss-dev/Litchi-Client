import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/shared/services/api_client.dart';
import 'package:litchi_client/shared/services/panel_api.dart';

class _RecordingClient extends ApiClient {
  Map<String, dynamic> response = const {};
  String? lastPath;
  Map<String, dynamic>? lastData;

  @override
  Future<Map<String, dynamic>> get(String path, {
    Map<String, dynamic>? params,
    bool silent = false,
  }) async {
    lastPath = path;
    return response;
  }

  @override
  Future<Map<String, dynamic>> post(String path, {
    Map<String, dynamic>? data,
    Map<String, dynamic>? headers,
  }) async {
    lastPath = path;
    lastData = data;
    return response;
  }
}

void main() {
  late _RecordingClient client;
  late PanelApi api;

  setUp(() {
    client = _RecordingClient();
    api = PanelApi(client);
  });

  test('enabled email verification and suffix whitelist come from guest config',
      () async {
    client.response = {
      'code': 0,
      'data': {
        'is_email_verify': 1,
        'email_whitelist_suffix': ['@gmail.com', '@qq.com'],
        'stop_register': 0,
      },
    };
    final config = await api.fetchRegisterConfig();
    expect(client.lastPath, '/guest/comm/config');
    expect(config.emailVerifyRequired, isTrue);
    expect(config.emailSuffixes, ['@gmail.com', '@qq.com']);
    expect(config.registerOpen, isTrue);
  });

  test('disabled verification, empty suffix list and closed registration',
      () async {
    client.response = {
      'code': 0,
      'data': {
        'is_email_verify': 0,
        'email_whitelist_suffix': '',
        'stop_register': 1,
      },
    };
    final config = await api.fetchRegisterConfig();
    expect(config.emailVerifyRequired, isFalse);
    expect(config.emailSuffixes, isEmpty);
    expect(config.registerOpen, isFalse);
  });

  test('login remains email and password only', () async {
    client.response = {'code': 0, 'data': {'auth_data': 'token'}};
    await api.login('user@gmail.com', 'password');
    expect(client.lastPath, '/passport/auth/login');
    expect(client.lastData, {'email': 'user@gmail.com', 'password': 'password'});
  });

  test('registration sends code only when provided', () async {
    client.response = {'code': 0, 'data': {'auth_data': 'token'}};
    await api.register(
      email: 'user@gmail.com', password: 'password',
      passwordConfirmation: 'password',
    );
    expect(client.lastData?.containsKey('email_code'), isFalse);

    await api.register(
      email: 'user@gmail.com', password: 'password',
      passwordConfirmation: 'password', emailCode: '123456',
    );
    expect(client.lastData?['email_code'], '123456');
  });
}
