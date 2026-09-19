import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/config/app_config.dart';
import 'package:litchi_client/config/panel_backend.dart';
import 'package:litchi_client/shared/models/api_models.dart';
import 'package:litchi_client/shared/services/api_client.dart';
import 'package:litchi_client/shared/services/data_loader.dart';
import 'package:litchi_client/shared/services/panel_api.dart';

class _InviteNodesApi extends PanelApi {
  _InviteNodesApi({required this.invite, required this.subscription})
      : super(ApiClient());

  final Future<RemoteInvite> Function() invite;
  final Future<SubscriptionResult> Function() subscription;

  @override
  Future<RemoteInvite> getInviteInfo() => invite();

  @override
  Future<RemoteCommConfig> getCommConfig() async => const RemoteCommConfig(
    inviteUrlBase: '',
    currencySymbol: '¥',
    withdrawClose: 1,
    withdrawMethods: [],
    minWithdrawAmount: 0,
  );

  @override
  Future<List<RemoteInviteRecord>> getInviteDetails({
    int current = 1,
    int pageSize = 10,
  }) async => [];

  @override
  Future<SubscriptionResult> fetchSubscription(String subscribeUrl) =>
      subscription();

  @override
  Future<List<RemoteTrafficLog>> getTrafficLog() async => [];
}

const _emptyInvite = RemoteInvite(
  inviteCode: '',
  inviteUrl: '',
  codes: [],
  commissionRate: 0,
  validCommission: 0,
  pendingCommission: 0,
  balance: 0,
  effectCount: 0,
);

void main() {
  final originalFeatures = AppConfig.panelFeatures;
  setUp(() => AppConfig.panelFeatures = PanelFeatures.legacy);
  tearDown(() => AppConfig.panelFeatures = originalFeatures);

  test('successful empty invite clears old codes and link', () async {
    final api = _InviteNodesApi(
      invite: () async => _emptyInvite,
      subscription: () async => const SubscriptionResult(nodes: []),
    );
    final snap = DataSnapshot();
    await DataLoader(api).loadSecondary(snap);
    expect(snap.inviteCodes, isEmpty);
    expect(snap.inviteCode, '');
    expect(snap.inviteLink, '');
    expect(snap.inviteUrlBase, '');
    expect(snap.inviteRecords, isEmpty);
    expect(snap.invitedCount, 0);
  });

  test('failed invite request preserves unknown snapshot fields', () async {
    final api = _InviteNodesApi(
      invite: () async => throw StateError('invite offline'),
      subscription: () async => const SubscriptionResult(nodes: []),
    );
    final snap = DataSnapshot();
    await DataLoader(api).loadSecondary(snap);
    expect(snap.inviteCodes, isNull);
    expect(snap.inviteCode, isNull);
    expect(snap.inviteLink, isNull);
  });

  test('empty subscription never erases existing nodes and reports issue', () async {
    final api = _InviteNodesApi(
      invite: () async => _emptyInvite,
      subscription: () async => const SubscriptionResult(nodes: []),
    );
    final snap = await DataLoader(api).loadNodes('https://example.com/sub');
    expect(snap.nodes, isNull);
    expect(snap.nodesError, isNotNull);
  });

  test('failed subscription never claims a confirmed empty node list', () async {
    final api = _InviteNodesApi(
      invite: () async => _emptyInvite,
      subscription: () async => throw StateError('subscription corrupt'),
    );
    final snap = await DataLoader(api).loadNodes('https://example.com/sub');
    expect(snap.nodes, isNull);
    expect(snap.nodesError, isNotNull);
  });

  test('a usable subscription replaces nodes without an error', () async {
    final api = _InviteNodesApi(
      invite: () async => _emptyInvite,
      subscription: () async => const SubscriptionResult(
        nodes: [RemoteNode(id: 1, name: 'JP', rate: 1, server: 'jp.example.com', port: 443)],
      ),
    );
    final snap = await DataLoader(api).loadNodes('https://example.com/sub');
    expect(snap.nodes, hasLength(1));
    expect(snap.nodesError, isNull);
  });
}
