import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart' show FTheme, FToaster, FToast;
import 'package:litchi_client/v3/theme/v3_palette.dart';
import 'package:litchi_client/v3/ui/v3_toast.dart';

void main() {
  testWidgets('app-level Forui toaster renders success with brand accent',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: V3Theme.light(),
      builder: (context, child) => FTheme(
        data: FTheme.neutral.light.touch,
        child: FToaster(child: child!),
      ),
      home: Scaffold(
        body: Builder(builder: (context) => TextButton(
          onPressed: () => V3Toast.show(
            context,
            '已连接',
            type: V3ToastType.success,
          ),
          child: const Text('Native Toast'),
        )),
      ),
    ));

    await tester.tap(find.text('Native Toast'));
    await tester.pump();
    expect(find.byType(FToast), findsOneWidget);
    expect(find.text('已连接'), findsOneWidget);
    expect(
      tester.widget<Icon>(find.byIcon(Icons.check_circle_outline_rounded)).color,
      V3Palette.light.lychee,
    );

    V3Toast.dismiss();
    await tester.pump();
  });


  testWidgets('success toast floats with Litchi accent icon and progress',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: V3Theme.light(),
      home: Scaffold(
        body: Builder(builder: (context) => TextButton(
          onPressed: () => V3Toast.show(
            context,
            '节点切换成功',
            type: V3ToastType.success,
          ),
          child: const Text('Notify'),
        )),
      ),
    ));

    await tester.tap(find.text('Notify'));
    await tester.pump();
    expect(find.text('节点切换成功'), findsOneWidget);
    // Approved UI V1: success feedback uses the Litchi brand accent.
    expect(
      tester.widget<Icon>(find.byIcon(Icons.check_circle_outline_rounded)).color,
      V3Palette.light.lychee,
    );
    expect(
      tester.widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator)).color,
      V3Palette.light.lychee,
    );
    expect(find.byType(SnackBar), findsNothing);

    await tester.pump(const Duration(milliseconds: 2600));
    await tester.pump();
    expect(find.text('节点切换成功'), findsNothing);
  });

  testWidgets('new notification replaces the old one', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: V3Theme.dark(),
      home: Scaffold(body: Builder(builder: (context) => Column(children: [
        TextButton(
          onPressed: () => V3Toast.show(
            context,
            '第一次',
            type: V3ToastType.success,
          ),
          child: const Text('First'),
        ),
        TextButton(
          onPressed: () => V3Toast.show(
            context,
            '第二次',
            type: V3ToastType.error,
          ),
          child: const Text('Second'),
        ),
      ]))),
    ));

    await tester.tap(find.text('First'));
    await tester.pump();
    await tester.tap(find.text('Second'));
    await tester.pump();
    expect(find.text('第一次'), findsNothing);
    expect(find.text('第二次'), findsOneWidget);
    expect(
      tester.widget<Icon>(find.byIcon(Icons.error_outline_rounded)).color,
      V3Palette.dark.danger,
    );

    await tester.pump(V3Toast.errorDuration);
    await tester.pump();
    expect(find.text('第二次'), findsNothing);
  });
}
