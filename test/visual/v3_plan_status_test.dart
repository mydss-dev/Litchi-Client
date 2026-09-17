import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/app/app_controller.dart';
import 'package:litchi_client/shared/models/app_models.dart';
import 'package:litchi_client/v3/app/v3_shell.dart';
import 'package:litchi_client/v3/theme/v3_palette.dart';

import 'v3_visual_fixture.dart';

class _UnnamedPlanController extends VisualV3Controller {
  _UnnamedPlanController(super.page, this.active);

  final bool active;

  @override
  bool get hasPlan => active;

  @override
  UserModel get user => const UserModel(
    name: 'Test user',
    plan: '',
    avatarLetter: 'T',
    expiry: '2026-12-31',
  );
}

void main() {
  for (final page in [AppPage.dashboard, AppPage.shop, AppPage.account]) {
    for (final active in [true, false]) {
      testWidgets('Unnamed plan on $page uses subscription state $active', (
        tester,
      ) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.windows;
        try {
          await tester.binding.setSurfaceSize(const Size(900, 700));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          final controller = _UnnamedPlanController(page, active);
          addTearDown(controller.disposeVisual);
          await tester.pumpWidget(
            MaterialApp(
              theme: V3Theme.dark(),
              home: AppScope(controller: controller, child: const V3Shell()),
            ),
          );
          await tester.pump();
          expect(tester.takeException(), isNull);
          if (active) {
            // A compact account/shop need not repeat the status twice. Assert
            // that the actual state is communicated, not the number of copies.
            expect(find.textContaining('已激活套餐'), findsWidgets);
            expect(find.textContaining('暂无套餐'), findsNothing);
            expect(find.text('还没有套餐'), findsNothing);
          } else {
            expect(find.textContaining('已激活套餐'), findsNothing);
            expect(find.textContaining('暂无套餐'), findsWidgets);
          }
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      });
    }
  }
}
