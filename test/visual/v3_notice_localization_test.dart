import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/app/app_controller.dart';
import 'package:litchi_client/l10n/generated/app_localizations.dart';
import 'package:litchi_client/shared/models/api_models.dart';
import 'package:litchi_client/shared/models/app_models.dart';
import 'package:litchi_client/v3/theme/v3_palette.dart';
import 'package:litchi_client/v3/ui/v3_notice_bar.dart';

import 'v3_visual_fixture.dart';

class _NoticeController extends VisualV3Controller {
  _NoticeController() : super(AppPage.dashboard);

  @override
  List<NoticeModel> get notices => const [
    NoticeModel(id: 1, title: 'Server announcement',
      content: '<p>Server message</p>', createdAt: 1789430400),
  ];
}

void main() {
  for (final locale in [const Locale('en'), const Locale('zh', 'TW')]) {
    testWidgets('notice chrome follows $locale without translating server data',
      (tester) async {
        final controller = _NoticeController();
        addTearDown(controller.disposeVisual);
        await tester.pumpWidget(AppScope(controller: controller,
          child: MaterialApp(
            locale: locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: V3Theme.light(),
            home: Scaffold(body: Builder(builder: (context) => Column(
              children: [
                V3NoticeBar(controller: controller),
                TextButton(onPressed: () => V3NoticeDialog.showReader(context,
                  notices: const [
                    NoticeModel(id: 2, title: 'Backend title', content: '',
                      createdAt: 1789430400),
                  ], initialIndex: 0), child: const Text('Open reader')),
              ]))),
          )));
        await tester.pump();
        expect(find.textContaining('Server announcement'), findsOneWidget);
        expect(find.text(locale.languageCode == 'en' ? 'View' : '查看'),
          findsOneWidget);
        await tester.tap(find.text('Open reader'));
        await tester.pumpAndSettle();
        expect(find.text('Backend title'), findsOneWidget);
        expect(find.text(locale.languageCode == 'en'
          ? 'This notice has no body.' : '（本則公告沒有正文）'), findsOneWidget);
        await tester.tap(find.widgetWithText(FilledButton,
          locale.languageCode == 'en' ? 'Close' : '關閉'));
        await tester.pumpAndSettle();
        expect(find.byType(V3NoticeDialog), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      });
  }
}
