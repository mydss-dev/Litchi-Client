import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/app/app_controller.dart';
import 'package:litchi_client/shared/models/api_models.dart';
import 'package:litchi_client/shared/models/app_models.dart';
import 'package:litchi_client/v3/app/v3_shell.dart';
import 'package:litchi_client/v3/theme/v3_palette.dart';

import 'v3_visual_fixture.dart';

class _PlanStateController extends VisualV3Controller {
  _PlanStateController(super.page, {
    required this.evidence,
    required this.expiry,
    this.planName = '',
    this.status,
    this.expiryTimestamp,
  });

  final bool evidence;
  final String expiry;
  final String planName;
  final int? status;
  final int? expiryTimestamp;

  @override
  bool get hasPlan => evidence;
  @override
  int? get currentPlanId => null;
  @override
  List<PlanModel> get plans => const [];
  @override
  RemoteUser? get accountDetails => status == null ? null : RemoteUser(
    id: 1,
    email: '',
    balance: 0,
    transferEnable: 0,
    used: 0,
    subscribeStatus: status!,
    remindExpire: false,
    remindTraffic: false,
    autoRenewal: false,
  );
  @override
  int? get expiredAt => expiryTimestamp;
  @override
  UserModel get user => UserModel(
    name: 'Test user',
    plan: planName,
    avatarLetter: 'T',
    expiry: expiry,
  );
}

void main() {
  for (final page in [AppPage.dashboard, AppPage.shop, AppPage.account]) {
    for (final scenario in <({String label, bool evidence, String name, String expiry, int? status, int? expiryTimestamp, String expected})>[
      (label: 'no plan', evidence: false, name: '', expiry: '', status: null, expiryTimestamp: null, expected: '暂无套餐'),
      (label: 'unnamed', evidence: true, name: '', expiry: '2026-12-31', status: null, expiryTimestamp: null, expected: '套餐名称待同步 · 使用中'),
      (label: 'named', evidence: true, name: 'Litchi Ultra', expiry: '2026-12-31', status: null, expiryTimestamp: null, expected: 'Litchi Ultra · 使用中'),
      (label: 'expired', evidence: true, name: 'Litchi Ultra', expiry: '2026-12-31', status: 1, expiryTimestamp: null, expected: 'Litchi Ultra · 已到期'),
      (label: 'unknown', evidence: true, name: '', expiry: '', status: null, expiryTimestamp: null, expected: '套餐名称待同步 · 状态待同步'),
    ]) {
      testWidgets('${scenario.label} on $page has factual plan status', (
        tester,
      ) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.windows;
        try {
          await tester.binding.setSurfaceSize(const Size(900, 700));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          final controller = _PlanStateController(
            page,
            evidence: scenario.evidence,
            expiry: scenario.expiry,
            planName: scenario.name,
            status: scenario.status,
            expiryTimestamp: scenario.expiryTimestamp,
          );
          addTearDown(controller.disposeVisual);
          await tester.pumpWidget(
            MaterialApp(
              theme: V3Theme.dark(),
              home: AppScope(controller: controller, child: const V3Shell()),
            ),
          );
          await tester.pump();
          expect(tester.takeException(), isNull);
          expect(find.textContaining(scenario.expected), findsWidgets);
          expect(find.textContaining('已激活套餐'), findsNothing);
          if (!scenario.evidence) {
            expect(find.textContaining('套餐名称待同步'), findsNothing);
          }
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      });
    }
  }
}
