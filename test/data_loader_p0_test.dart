import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/shared/models/api_models.dart';
import 'package:litchi_client/shared/services/api_client.dart';
import 'package:litchi_client/shared/services/data_loader.dart';
import 'package:litchi_client/shared/services/panel_api.dart';

class _StubPanelApi extends PanelApi {
  _StubPanelApi({required this.userInfo, required this.subscribeInfo})
    : super(ApiClient());

  final Future<RemoteUser> Function() userInfo;
  final Future<RemoteSubscribe> Function() subscribeInfo;

  @override
  Future<RemoteUser> getUserInfo({bool silent = false}) => userInfo();

  @override
  Future<RemoteSubscribe> getSubscribeInfo({bool silent = false}) =>
      subscribeInfo();
}

RemoteUser _user({int? planId, double transferEnable = 0}) =>
    RemoteUser.fromJson({
      'id': 1,
      'email': 'test@example.com',
      if (planId != null) 'plan_id': planId,
      'transfer_enable': transferEnable,
    });

RemoteSubscribe _subscribe({
  int? planId,
  String url = '',
  double transferEnable = 0,
}) => RemoteSubscribe.fromJson({
  if (planId != null) 'plan_id': planId,
  'subscribe_url': url,
  'transfer_enable': transferEnable,
});

void main() {
  group('P0: account plan evidence', () {
    test('partial user data and failed subscription leave plan unknown', () async {
      final loader = DataLoader(
        _StubPanelApi(
          userInfo: () async => _user(),
          subscribeInfo: () async => throw StateError('subscription offline'),
        ),
      );

      final snapshot = await loader.loadAccountStatus();
      expect(snapshot.hasPlan, isNull);
      expect(snapshot.subscribeUrl, isNull);
    });

    test('user plan evidence survives a failed subscription request', () async {
      final loader = DataLoader(
        _StubPanelApi(
          userInfo: () async => _user(planId: 42),
          subscribeInfo: () async => throw StateError('subscription offline'),
        ),
      );

      final snapshot = await loader.loadAccountStatus();
      expect(snapshot.hasPlan, isTrue);
      expect(snapshot.currentPlanId, 42);
    });

    test('subscription evidence survives a failed user request', () async {
      final loader = DataLoader(
        _StubPanelApi(
          userInfo: () async => throw StateError('user offline'),
          subscribeInfo: () async => _subscribe(planId: 42),
        ),
      );

      final snapshot = await loader.loadAccountStatus();
      expect(snapshot.hasPlan, isTrue);
      expect(snapshot.currentPlanId, 42);
    });

    test('two successful no-plan responses clear subscription', () async {
      final loader = DataLoader(
        _StubPanelApi(
          userInfo: () async => _user(),
          subscribeInfo: () async => _subscribe(),
        ),
      );

      final snapshot = await loader.loadAccountStatus();
      expect(snapshot.hasPlan, isFalse);
      expect(snapshot.subscribeUrl, '');
      expect(snapshot.currentPlanId, isNull);
      expect(snapshot.traffic?.totalGb, 0);
    });

    test('empty subscription URL cannot erase a valid user plan', () async {
      final loader = DataLoader(
        _StubPanelApi(
          userInfo: () async => _user(planId: 42),
          subscribeInfo: () async => _subscribe(),
        ),
      );

      final snapshot = await loader.loadAccountStatus();
      expect(snapshot.hasPlan, isTrue);
      expect(snapshot.subscribeUrl, isNull);
    });

    test('both requests failing leave plan unknown', () async {
      final loader = DataLoader(
        _StubPanelApi(
          userInfo: () async => throw StateError('user offline'),
          subscribeInfo: () async => throw StateError('subscription offline'),
        ),
      );

      final snapshot = await loader.loadAccountStatus();
      expect(snapshot.hasPlan, isNull);
      expect(snapshot.criticalError, isNotNull);
    });
  });
}
