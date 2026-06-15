import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/app/app_controller.dart';
import 'package:litchi_client/shared/widgets/app_selector.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(TestWidgetsFlutterBinding.ensureInitialized);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('AppSelector rebuilds only when its slice changes', (
    tester,
  ) async {
    final controller = AppController();
    addTearDown(controller.dispose);

    var builds = 0;
    await tester.pumpWidget(
      AppScope(
        controller: controller,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: AppSelector<AppPage>(
            selector: (c) => c.page,
            builder: (context, page, _) {
              builds++;
              return Text('$page');
            },
          ),
        ),
      ),
    );

    expect(builds, 1);
    expect(find.text('AppPage.dashboard'), findsOneWidget);

    // A change to an unrelated slice must NOT rebuild the selector.
    controller.toggleDarkMode(true);
    await tester.pump();
    expect(builds, 1);

    // A change to the selected slice DOES rebuild it.
    controller.goToPage(AppPage.nodes);
    await tester.pump();
    expect(builds, 2);
    expect(find.text('AppPage.nodes'), findsOneWidget);
  });

  testWidgets('AppSelector dedupes equal selected values', (tester) async {
    final controller = AppController();
    addTearDown(controller.dispose);

    var builds = 0;
    await tester.pumpWidget(
      AppScope(
        controller: controller,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: AppSelector<bool>(
            selector: (c) => c.isDark,
            builder: (context, isDark, _) {
              builds++;
              return Text('$isDark');
            },
          ),
        ),
      ),
    );

    expect(builds, 1);

    // Re-setting the same theme value notifies listeners but the selected slice
    // is unchanged, so no rebuild.
    controller.setThemeMode(ThemeMode.light);
    await tester.pump();
    expect(builds, 1);
  });
}
