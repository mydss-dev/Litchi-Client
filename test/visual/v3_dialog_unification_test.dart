import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/v3/theme/v3_palette.dart';
import 'package:litchi_client/v3/ui/v3_dialog_frame.dart';
import 'package:litchi_client/v3/ui/v3_layout.dart';
import 'package:litchi_client/v3/ui/v3_sheet.dart';

void main() {
  for (final size in [const Size(900, 700), const Size(360, 480)]) {
    for (final dark in [false, true]) {
      testWidgets('dialog keeps its shared shape and scrollable action at $size dark=$dark',
          (tester) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(MaterialApp(
          theme: V3Theme.light(),
          darkTheme: V3Theme.dark(),
          themeMode: dark ? ThemeMode.dark : ThemeMode.light,
          home: Scaffold(body: Builder(builder: (context) => FilledButton(
            onPressed: () => showDialog<void>(context: context,
              builder: (_) => V3DialogFrame(width: 420, child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('统一弹窗'),
                  const SizedBox(height: 520),
                  FilledButton(key: const ValueKey('dialog-submit'),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('确认')),
                ],
              ))),
            child: const Text('打开')))),
        ));
        await tester.tap(find.text('打开'));
        await tester.pumpAndSettle();
        final dialog = tester.widget<Dialog>(find.byType(Dialog));
        final shape = dialog.shape! as RoundedRectangleBorder;
        expect(shape.borderRadius, BorderRadius.circular(V3Layout.cardRadius));
        expect(find.text('统一弹窗'), findsOneWidget);
        final submit = find.byKey(const ValueKey('dialog-submit'));
        await tester.ensureVisible(submit);
        await tester.pumpAndSettle();
        expect(tester.getRect(submit).bottom, lessThanOrEqualTo(size.height));
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final size in [const Size(900, 700), const Size(360, 480)]) {
    testWidgets('account sheet retains its close action and scrolls at $size',
        (tester) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(MaterialApp(
        theme: V3Theme.light(),
        home: Scaffold(body: Builder(builder: (context) => FilledButton(
          onPressed: () => showV3Sheet<void>(context,
            title: '兑换码',
            builder: (_) => const Column(mainAxisSize: MainAxisSize.min,
              children: [
                Text('输入兑换码'),
                SizedBox(height: 420),
                Text('底部说明'),
              ])),
          child: const Text('打开')))),
      ));
      await tester.tap(find.text('打开'));
      await tester.pumpAndSettle();
      expect(find.text('兑换码'), findsOneWidget);
      expect(find.byTooltip('关闭'), findsOneWidget);
      final footer = find.text('底部说明');
      await tester.ensureVisible(footer);
      await tester.pumpAndSettle();
      expect(tester.getRect(footer).bottom, lessThanOrEqualTo(size.height));
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('关闭'));
      await tester.pumpAndSettle();
      expect(find.text('兑换码'), findsNothing);
    });
  }
}
