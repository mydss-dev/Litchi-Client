import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/l10n/generated/app_localizations.dart';
import 'package:litchi_client/v3/ui/v3_account_labels.dart';
import 'package:litchi_client/v3/ui/v3_locale_copy.dart';

Future<void> pumpLabels(
  WidgetTester tester, {
  Locale? locale,
  bool installDelegates = true,
  String? name,
  String? email,
}) async {
  await tester.pumpWidget(MaterialApp(
    locale: locale,
    localizationsDelegates:
        installDelegates ? AppLocalizations.localizationsDelegates : null,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: Builder(builder: (context) => Column(children: [
      Text(v3AccountDisplayName(context, name)),
      Text(v3AccountEmailLabel(context, email)),
    ]))),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('missing identity uses simplified Chinese in standalone previews',
      (tester) async {
    await pumpLabels(tester, installDelegates: false);
    expect(find.text('资料待同步'), findsOneWidget);
    expect(find.text('邮箱待同步'), findsOneWidget);
  });

  testWidgets('missing identity follows English locale', (tester) async {
    await pumpLabels(tester, locale: const Locale('en'));
    expect(find.text('Details pending'), findsOneWidget);
    expect(find.text('Email pending'), findsOneWidget);
    expect(find.text('资料待同步'), findsNothing);
  });

  testWidgets('missing identity follows traditional Chinese locale',
      (tester) async {
    await pumpLabels(tester, locale: const Locale('zh', 'TW'));
    expect(find.text('資料待同步'), findsOneWidget);
    expect(find.text('電子郵件待同步'), findsOneWidget);
  });

  testWidgets('valid backend identity is preserved', (tester) async {
    await pumpLabels(tester,
        locale: const Locale('en'),
        name: '真实用户',
        email: 'owner@example.com');
    expect(find.text('真实用户'), findsOneWidget);
    expect(find.text('owner@example.com'), findsOneWidget);
    expect(find.text('Details pending'), findsNothing);
    expect(find.text('Email pending'), findsNothing);
  });

  testWidgets('shared localization helper has consistent delegate-free fallback',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: Builder(builder: (context) {
        final fallback = v3Localizations(context);
        return Text(fallback.localeName);
      })),
    ));
    expect(find.text('zh'), findsOneWidget);
  });
}
