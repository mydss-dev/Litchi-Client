import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/app/app_controller.dart';
import 'package:litchi_client/shared/models/app_models.dart';
import 'package:litchi_client/v3/pages/v3_invite_page.dart';
import 'package:litchi_client/v3/theme/v3_palette.dart';

import 'v3_visual_fixture.dart';

const _a = InviteCodeModel(code: 'CODE-A', link: 'https://example.com/a');
const _b = InviteCodeModel(code: 'CODE-B', link: 'https://example.com/b');

class _InviteFixture extends VisualV3Controller {
  _InviteFixture(this.entries) : super(AppPage.invite);

  List<InviteCodeModel> entries;
  String fallbackCode = '';
  String fallbackLink = '';
  String? createError;
  List<InviteCodeModel>? afterCreate;

  @override
  List<InviteCodeModel> get inviteCodes => entries;
  @override
  String get inviteCode => fallbackCode;
  @override
  String get inviteLink => fallbackLink;

  @override
  Future<String?> createInviteCode() async {
    if (createError == null && afterCreate != null) {
      entries = afterCreate!;
      notifyListeners();
    }
    return createError;
  }

  void replace(List<InviteCodeModel> codes) {
    entries = codes;
    notifyListeners();
  }
}

Future<void> _pump(
  WidgetTester tester,
  _InviteFixture controller, {
  Size size = const Size(900, 700),
  ThemeMode mode = ThemeMode.light,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  addTearDown(controller.disposeVisual);
  await tester.pumpWidget(MaterialApp(
    theme: V3Theme.light(),
    darkTheme: V3Theme.dark(),
    themeMode: mode,
    home: AppScope(
      controller: controller,
      child: const Scaffold(body: V3InvitePage()),
    ),
  ));
  await tester.pumpAndSettle();
}

OutlinedButton _copyButton(WidgetTester tester, String name) =>
    tester.widget<OutlinedButton>(find.byKey(ValueKey(name)));

void main() {
  testWidgets('empty invite page offers creation, not unavailable copy', (tester) async {
    final fixture = _InviteFixture([]);
    await _pump(tester, fixture);
    expect(find.text('还没有邀请码'), findsOneWidget);
    expect(_copyButton(tester, 'v3-invite-copy-code').onPressed, isNull);
    expect(_copyButton(tester, 'v3-invite-copy-link').onPressed, isNull);
    expect(find.text('邀请人�?), findsOneWidget);
    expect(find.text('成功邀�?), findsNothing);
    expect(find.text('最近返佣记�?), findsOneWidget);
  });

  testWidgets('code without link enables only the real copy action', (tester) async {
    final fixture = _InviteFixture([
      const InviteCodeModel(code: 'CODE-ONLY', link: ''),
    ]);
    await _pump(tester, fixture);
    expect(find.text('CODE-ONLY'), findsOneWidget);
    expect(find.text('后台尚未提供邀请链接，可分享邀请码'), findsOneWidget);
    expect(_copyButton(tester, 'v3-invite-copy-code').onPressed, isNotNull);
    expect(_copyButton(tester, 'v3-invite-copy-link').onPressed, isNull);
    expect(find.text('LITCHI'), findsNothing);
  });

  testWidgets('link without code never invents a code and copies actual URL', (tester) async {
    const url = 'https://example.com/register?code=A';
    final fixture = _InviteFixture([
      const InviteCodeModel(code: '', link: url),
    ]);
    String? copied;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied = (call.arguments as Map)['text'] as String?;
      }
      return null;
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding.instance
        .defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await _pump(tester, fixture, size: const Size(390, 844));
    expect(find.text('后台未返回邀请码'), findsOneWidget);
    expect(find.text('LITCHI'), findsNothing);
    expect(_copyButton(tester, 'v3-invite-copy-code').onPressed, isNull);
    expect(_copyButton(tester, 'v3-invite-copy-link').onPressed, isNotNull);
    await tester.tap(find.byKey(const ValueKey('v3-invite-copy-link')));
    await tester.pump();
    expect(copied, url);
    expect(find.text('邀请链接已复制'), findsOneWidget);
  });

  testWidgets('refresh reorder keeps the selected invitation identity', (tester) async {
    final fixture = _InviteFixture([_a, _b]);
    await _pump(tester, fixture);
    await tester.tap(find.byKey(const ValueKey('v3-invite-next')));
    await tester.pumpAndSettle();
    expect(find.text('CODE-B'), findsOneWidget);
    fixture.replace([_b, _a]);
    await tester.pumpAndSettle();
    expect(find.text('CODE-B'), findsOneWidget);
    expect(find.text('1 / 2'), findsOneWidget);
  });

  testWidgets('successful creation reveals the new code', (tester) async {
    final fixture = _InviteFixture([_a])..afterCreate = [_a, _b];
    await _pump(tester, fixture);
    await tester.tap(find.byKey(const ValueKey('v3-invite-create')));
    await tester.pumpAndSettle();
    expect(find.text('CODE-B'), findsOneWidget);
    expect(find.text('2 / 2'), findsOneWidget);
    expect(find.text('邀请码已创�?), findsOneWidget);
  });

  testWidgets('creation error is shown instead of a success message', (tester) async {
    // Start with a fresh messenger: Flutter deliberately queues consecutive
    // snackbars, so asserting a second snackbar immediately after a success
    // would be testing the queue rather than the error-handling path.
    final fixture = _InviteFixture([_a])..createError = '创建权限不足';
    await _pump(tester, fixture);
    await tester.tap(find.byKey(const ValueKey('v3-invite-create')));
    await tester.pumpAndSettle();
    expect(find.text('创建权限不足'), findsOneWidget);
    expect(find.text('邀请码已创�?), findsNothing);
    expect(find.text('CODE-A'), findsOneWidget);
  });

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('compact invite renders without overflow in $mode', (tester) async {
      final fixture = _InviteFixture([_a]);
      await _pump(tester, fixture, size: const Size(360, 800), mode: mode);
      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('v3-invite-copy-code')), findsOneWidget);
      expect(find.byKey(const ValueKey('v3-invite-copy-link')), findsOneWidget);
    });
  }
}
