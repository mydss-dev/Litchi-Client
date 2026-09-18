import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/app/app_controller.dart';
import 'package:litchi_client/shared/models/api_models.dart';
import 'package:litchi_client/v3/app/v3_shell.dart';
import 'package:litchi_client/v3/pages/v3_telegram_page.dart';
import 'package:litchi_client/v3/theme/v3_palette.dart';

import 'v3_visual_fixture.dart';

class _BoundController extends VisualV3Controller {
  _BoundController() : super(AppPage.account);
  static const _boundUser = RemoteUser(
    id: 7, email: 'litchi-user@example.com', expiredAt: 1798675200,
    balance: 12880, transferEnable: 512, used: 128,
    subscribeStatus: 0, planId: 8, planName: 'Litchi Ultra · 512G',
    remindExpire: true, remindTraffic: true, autoRenewal: false,
    telegramId: '123456789',
  );
  @override
  RemoteUser? get accountDetails => _boundUser;
}

const _telegramRow = ValueKey('v3-hub-telegram');
const _mobile = Size(390, 844);

Future<VisualV3Controller> _pumpAccount(WidgetTester tester,
    {bool bound = false}) async {
  await tester.binding.setSurfaceSize(_mobile);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final controller = bound
      ? _BoundController() : VisualV3Controller(AppPage.account);
  addTearDown(controller.disposeVisual);
  await tester.pumpWidget(AppScope(controller: controller,
    child: MaterialApp(theme: V3Theme.dark(), home: const V3Shell())));
  await tester.pumpAndSettle();
  // Previous layout exposes the service directly: no expansion is needed.
  expect(find.text('账户偏好与安全'), findsNothing);
  expect(find.byKey(_telegramRow), findsOneWidget);
  expect(tester.takeException(), isNull);
  return controller;
}

Future<void> _onPlatform(TargetPlatform platform,
    Future<void> Function() body) async {
  debugDefaultTargetPlatformOverride = platform;
  try { await body(); } finally { debugDefaultTargetPlatformOverride = null; }
}

Future<void> _tap(WidgetTester tester, Finder finder, String what) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull, reason: 'tapping $what threw');
}

void main() {
  testWidgets('account shows Telegram directly with its binding status',
      (tester) async {
    await _onPlatform(TargetPlatform.android, () async {
      await _pumpAccount(tester);
      expect(find.byKey(_telegramRow), findsOneWidget);
      expect(find.text('Telegram 通知'), findsOneWidget);
      expect(find.text('未绑定'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('Telegram row opens a sheet with the bot username',
      (tester) async {
    await _onPlatform(TargetPlatform.android, () async {
      final controller = await _pumpAccount(tester);
      await _tap(tester, find.byKey(_telegramRow), 'Telegram row');
      expect(find.byType(V3TelegramPage), findsOneWidget);
      expect(find.text('@litchi_bot'), findsOneWidget);
      expect(controller.page, AppPage.account);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('copy bind command writes /bind plus the subscribe url',
      (tester) async {
    final writes = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          writes.add((call.arguments as Map)['text'] as String);
        }
        return null;
      },
    );
    addTearDown(() => tester.binding.defaultBinaryMessenger
      .setMockMethodCallHandler(SystemChannels.platform, null));
    await _onPlatform(TargetPlatform.android, () async {
      await _pumpAccount(tester);
      await _tap(tester, find.byKey(_telegramRow), 'Telegram row');
      await _tap(tester, find.text('复制绑定命令'), 'copy bind command');
      expect(writes, ['/bind https://thelitchi.com/sub/litchi']);
      expect(find.text('绑定命令已复制，去 Telegram 粘贴发送'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('a bound account can unbind', (tester) async {
    await _onPlatform(TargetPlatform.android, () async {
      await _pumpAccount(tester, bound: true);
      expect(find.textContaining('已绑定'), findsWidgets);
      await _tap(tester, find.byKey(_telegramRow), 'Telegram row');
      expect(find.text('解除绑定'), findsOneWidget);
      await _tap(tester, find.text('解除绑定'), 'unbind');
      expect(find.text('Telegram 已解绑'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
