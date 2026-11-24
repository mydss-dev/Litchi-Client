import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/preview/litchi_cupertino_preview.dart';

void main() {
  testWidgets('Cupertino preview navigates every primary tab', (tester) async {
    await tester.pumpWidget(const LitchiCupertinoPreview());
    await tester.pumpAndSettle();
    expect(find.text('Litchi'), findsOneWidget);

    await tester.tap(find.text('节点').last);
    await tester.pumpAndSettle();
    expect(find.text('选择适合你的网络线路'), findsOneWidget);

    await tester.tap(find.text('套餐').last);
    await tester.pumpAndSettle();
    expect(find.text('Litchi Elite'), findsOneWidget);

    await tester.tap(find.text('我的').last);
    await tester.pumpAndSettle();
    expect(find.text('账户服务'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('account order row opens full details and back', (tester) async {
    await tester.pumpWidget(const LitchiCupertinoPreview());
    await tester.pumpAndSettle();
    await tester.tap(find.text('我的').last);
    await tester.pumpAndSettle();
    final orders = find.text('订单记录').first;
    await tester.ensureVisible(orders);
    await tester.tap(orders);
    await tester.pumpAndSettle();
    expect(find.text('订单列表  ·  4 笔'), findsOneWidget);
    await tester.tap(find.text('Litchi Ultra · 256 GB').first);
    await tester.pumpAndSettle();
    expect(find.text('订单详情'), findsOneWidget);
    expect(find.text('订单编号'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('订单记录'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('secondary pages use native back with no primary tab bar',
      (tester) async {
    await tester.pumpWidget(const LitchiCupertinoPreview());
    await tester.pumpAndSettle();
    await tester.tap(find.text('我的').last);
    await tester.pumpAndSettle();
    final settings = find.text('应用设置');
    await tester.ensureVisible(settings);
    await tester.tap(settings);
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoNavigationBar), findsOneWidget);
    expect(find.byType(CupertinoTabBar), findsNothing);
    expect(find.text('应用设置'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
