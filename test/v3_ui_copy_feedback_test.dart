import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/app/app_controller.dart';
import 'package:litchi_client/shared/models/api_models.dart';
import 'package:litchi_client/v3/app/v3_nav.dart';
import 'package:litchi_client/v3/ui/v3_notice_bar.dart';

void main() {
  testWidgets('Chinese navigation labels are consistently two characters',
      (tester) async {
    late BuildContext context;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (value) {
      context = value;
      return const SizedBox();
    })));
    const expected = <AppPage, String>{
      AppPage.dashboard: '连接',
      AppPage.nodes: '节点',
      AppPage.shop: '套餐',
      AppPage.traffic: '流量',
      AppPage.invite: '邀请',
      AppPage.tickets: '工单',
      AppPage.settings: '设置',
    };
    for (final item in [...kDesktopRail, kRailSettings]) {
      expect(item.localizedLabel(context), expected[item.page]);
      expect(item.localizedLabel(context).runes.length, 2);
    }
  });

  test('notice ticker uses title only, not body text', () {
    const notice = NoticeModel(
      id: 1, title: '重要通知', content: '<p>新增节点和其他正文</p>',
      createdAt: 0,
    );
    expect(v3NoticeHeadline(notice), '重要通知');
    expect(v3NoticeText(notice.content), '新增节点和其他正文');
  });

  test('empty notice title has a neutral heading, never body preview', () {
    const notice = NoticeModel(
      id: 2, title: ' ', content: '这是正文，不应出现在公告栏',
      createdAt: 0,
    );
    expect(v3NoticeHeadline(notice), '公告');
  });
}
