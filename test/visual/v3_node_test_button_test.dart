import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/app/app_controller.dart';
import 'package:litchi_client/v3/theme/v3_palette.dart';
import 'package:litchi_client/v3/ui/v3_node_picker.dart';

import 'v3_visual_fixture.dart';

class _TestFixture extends VisualV3Controller {
  _TestFixture() : super(AppPage.dashboard);
  int calls = 0;
  @override
  Future<bool> testLatencies() async {
    calls++;
    return true;
  }
}

void main() {
  testWidgets('test action is alongside search and calls controller', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = _TestFixture();
    addTearDown(controller.disposeVisual);
    await tester.pumpWidget(
      AppScope(
        controller: controller,
        child: MaterialApp(
          theme: V3Theme.light(),
          home: const Scaffold(body: V3NodePicker()),
        ),
      ),
    );
    await tester.pump();
    expect(find.byKey(const Key('v3-node-speed-test')), findsOneWidget);
    await tester.tap(find.byKey(const Key('v3-node-speed-test')));
    await tester.pump();
    expect(controller.calls, 1);
    expect(tester.takeException(), isNull);
  });
}
