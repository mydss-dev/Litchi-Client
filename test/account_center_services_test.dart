import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/config/panel_backend.dart';
import 'package:litchi_client/shared/models/api_models.dart';
import 'package:litchi_client/shared/services/api_client.dart';
import 'package:litchi_client/shared/services/panel_api.dart';

class _RecordingApiClient extends ApiClient {
  String? lastMethod;
  String? lastPath;
  Map<String, dynamic>? lastData;
  Map<String, dynamic> nextResponse = const {'code': 0};

  @override
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? params,
    bool silent = false,
  }) async {
    lastMethod = 'GET';
    lastPath = path;
    lastData = params;
    return nextResponse;
  }

  @override
  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? data,
    Map<String, dynamic>? headers,
  }) async {
    lastMethod = 'POST';
    lastPath = path;
    lastData = data;
    return nextResponse;
  }
}

void main() {
  group('RemoteUser Telegram binding state', () {
    test('keeps a real Telegram identifier', () {
      final user = RemoteUser.fromJson({
        'email': '191066639@example.com',
        'telegram_id': 123456789,
      });

      expect(user.telegramId, '123456789');
    });

    test('normalizes XiaoV2Board unbound sentinels', () {
      for (final value in <Object?>[null, 0, '0', '', 'null']) {
        final user = RemoteUser.fromJson({
          'email': '191066639@example.com',
          'telegram_id': value,
        });
        expect(user.telegramId, isNull, reason: 'value=$value');
      }
    });
  });

  group('XiaoV2Board account services', () {
    late _RecordingApiClient client;
    late PanelApi api;

    setUp(() {
      client = _RecordingApiClient();
      api = PanelApi(client, panelTypeProvider: () => PanelType.xiaoV2board);
    });

    test('redeem gift card posts the expected endpoint and body', () async {
      await api.redeemGiftCard('  GIFT-123  ');

      expect(client.lastMethod, 'POST');
      expect(client.lastPath, '/user/redeemgiftcard');
      expect(client.lastData, {'giftcard': 'GIFT-123'});
    });

    test('reads and normalizes Telegram bot username', () async {
      client.nextResponse = {
        'code': 0,
        'data': {'username': '@litchi_bot'},
      };

      final username = await api.getTelegramBotUsername();

      expect(username, 'litchi_bot');
      expect(client.lastMethod, 'GET');
      expect(client.lastPath, '/user/telegram/getBotInfo');
    });

    test('unbinds Telegram through the expected endpoint', () async {
      await api.unbindTelegram();

      expect(client.lastMethod, 'GET');
      expect(client.lastPath, '/user/unbindTelegram');
    });

    test('rejects Xiao-only calls for other panel types', () async {
      final guarded = PanelApi(
        client,
        panelTypeProvider: () => PanelType.v2board,
      );

      await expectLater(
        guarded.redeemGiftCard('GIFT-123'),
        throwsA(isA<ApiException>()),
      );
      await expectLater(
        guarded.getTelegramBotUsername(),
        throwsA(isA<ApiException>()),
      );
      await expectLater(guarded.unbindTelegram(), throwsA(isA<ApiException>()));
      expect(client.lastPath, isNull);
    });
  });
}
