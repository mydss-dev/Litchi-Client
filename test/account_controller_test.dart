import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/app/account_controller.dart';
import 'package:litchi_client/shared/models/app_models.dart';
import 'package:litchi_client/shared/services/api_client.dart';
import 'package:litchi_client/shared/services/panel_api.dart';

void main() {
  AccountController build() => AccountController(PanelApi(ApiClient()));

  const user = UserModel(
    name: 'Alice',
    plan: 'Pro',
    avatarLetter: 'A',
    expiry: '2030-01-01',
  );
  const traffic = TrafficModel(totalGb: 100, usedGb: 40, remainGb: 60);

  test('applySnapshot stores user and traffic; nulls are ignored', () {
    final c = build();
    c.applySnapshot(user: user, traffic: traffic);
    expect(c.user.name, 'Alice');
    expect(c.traffic.totalGb, 100);

    c.applySnapshot(user: null, traffic: null);
    expect(c.user.name, 'Alice');
  });

  test('reset restores empty defaults', () {
    final c = build();
    c.applySnapshot(user: user, traffic: traffic);
    c.reset();
    expect(c.user.name, isEmpty);
    expect(c.traffic.totalGb, 0);
  });

  test('updateUserSettings rolls back the optimistic change on failure', () async {
    final c = build();
    c.applySnapshot(user: user);
    // Unconfigured API → call throws → optimistic toggle must roll back.
    final error = await c.updateUserSettings(
      remindExpire: true,
      remindTraffic: true,
      autoRenewal: true,
    );
    expect(error, isNotNull);
    expect(c.user.remindExpire, user.remindExpire);
  });
}
