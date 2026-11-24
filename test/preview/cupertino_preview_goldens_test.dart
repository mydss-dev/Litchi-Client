import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/preview/litchi_cupertino_preview.dart';

void main() {
  // Font loading needs real async before testWidgets enters fake async.
  setUpAll(() async {
    // Flutter widget tests otherwise draw Ahem block glyphs, not actual text.
    // Use the CI runner's open-source Noto face for a legible visual review.
    final noto = File('/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc');
    if (noto.existsSync()) {
      final typeface = await noto.readAsBytes();
      final loader = FontLoader('.SF Pro Text')
        ..addFont(Future.value(ByteData.sublistView(typeface)));
      await loader.load();
    }
    final iconData = await rootBundle.load(
      'packages/cupertino_icons/assets/CupertinoIcons.ttf');
    final iconLoader = FontLoader('packages/cupertino_icons/CupertinoIcons')
      ..addFont(Future.value(iconData));
    await iconLoader.load();
  });

  testWidgets('export full Cupertino suite screenshots', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      debugDefaultTargetPlatformOverride = null;
    });

    await tester.pumpWidget(const LitchiCupertinoPreview());
    await tester.pumpAndSettle();

    Future<void> capture(String filename) async {
      await expectLater(
        find.byKey(const ValueKey('cupertino-preview-capture')),
        matchesGoldenFile('goldens/' + filename + '.png'),
      );
    }

    Future<void> tab(String label) async {
      await tester.tap(find.text(label).last);
      await tester.pumpAndSettle();
    }

    Future<void> openAccountItem(String label) async {
      final item = find.text(label).first;
      await tester.ensureVisible(item);
      await tester.pumpAndSettle();
      await tester.tap(item);
      await tester.pumpAndSettle();
    }

    await capture('01_connect');
    await tab('节点');
    await capture('02_nodes');
    await tab('套餐');
    await capture('03_plans');
    await tab('我的');
    await capture('04_account');

    await openAccountItem('订单记录');
    await capture('05_orders');
    await tester.tap(find.text('Litchi Ultra · 256 GB').first);
    await tester.pumpAndSettle();
    await capture('06_order_detail');
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    await openAccountItem('流量用量');
    await capture('07_usage');
    await tester.pageBack();
    await tester.pumpAndSettle();

    await openAccountItem('帮助与工单');
    await capture('08_tickets');
    await tester.pageBack();
    await tester.pumpAndSettle();

    await openAccountItem('邀请好友');
    await capture('09_invite');
    await tester.pageBack();
    await tester.pumpAndSettle();

    await openAccountItem('应用设置');
    await capture('10_settings');
    await openAccountItem('登录页面');
    await capture('11_login');
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
