import 'dart:async';

import 'package:flutter/gestures.dart';
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
  bool createHangs = false;

  @override
  List<InviteCodeModel> get inviteCodes => entries;
  @override
  String get inviteCode => fallbackCode;
  @override
  String get inviteLink => fallbackLink;

  @override
  Future<String?> createInviteCode() async {
    if (createHangs) {
      // Outage simulation: a future that never settles and never arms a
      // FakeAsync timer (flutter_test fails the test on pending timers).
      await Completer<void>().future;
      return null;
    }
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

/// The pager arrows hide inside the stage card until hover or focus — a
/// synthetic mouse pointer parked over the card reveals them for taps.
Future<void> _hoverStage(WidgetTester tester) async {
  final pointer = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await pointer.addPointer(
    location: tester.getCenter(find.byKey(const ValueKey('v3-invite-stage'))),
  );
  addTearDown(pointer.removePointer);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('empty invite page offers creation, not unavailable copy', (tester) async {
    final fixture = _InviteFixture([]);
    await _pump(tester, fixture);
    // Empty: the create card IS the panel — the old dead "no code yet" stage
    // with disabled copy buttons is gone whole.
    expect(find.byKey(const ValueKey('v3-invite-create')), findsOneWidget);
    expect(find.byKey(const ValueKey('v3-invite-copy-code')), findsNothing);
    expect(find.byKey(const ValueKey('v3-invite-copy-link')), findsNothing);
    expect(find.byKey(const ValueKey('v3-invite-next')), findsNothing);
    expect(find.text('邀请人数'), findsOneWidget);
    expect(find.text('成功邀请'), findsNothing);
    expect(find.text('最近返佣记录'), findsOneWidget);
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
    // The floating toast dismisses itself after 2.5s; flush its timer.
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('refresh reorder keeps the selected invitation identity', (tester) async {
    final fixture = _InviteFixture([_a, _b]);
    await _pump(tester, fixture);
    await _hoverStage(tester);
    // Both arrows reveal together even at the ends — the disabled one stays
    // visible but inert, so the pair never lopsides.
    IconButton previous() => tester.widget<IconButton>(
      find.byKey(const ValueKey('v3-invite-previous')),
    );
    expect(previous().onPressed, isNull);
    await tester.tap(find.byKey(const ValueKey('v3-invite-next')));
    await tester.pumpAndSettle();
    expect(find.text('CODE-B'), findsOneWidget);
    expect(previous().onPressed, isNotNull);
    fixture.replace([_b, _a]);
    await tester.pumpAndSettle();
    expect(find.text('CODE-B'), findsOneWidget);
    expect(find.text('1 / 2'), findsOneWidget);
  });

  testWidgets('focused stage pages with the arrow keys', (tester) async {
    final fixture = _InviteFixture([_a, _b]);
    await _pump(tester, fixture);
    // Clicking the stage card focuses it; arrows then page the carousel —
    // linearly: the first page holds the left arrow, the create card is the
    // terminal right stop.
    await tester.tap(find.byKey(const ValueKey('v3-invite-stage')));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(find.text('CODE-B'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(find.text('CODE-A'), findsOneWidget);
    // Linear: the first page holds the left arrow instead of wrapping.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(find.text('CODE-A'), findsOneWidget);
    // Right from the last code lands on the terminal create card.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(find.text('CODE-A'), findsNothing);
    expect(find.byKey(const ValueKey('v3-invite-create')), findsOneWidget);
  });

  testWidgets('successful creation reveals the new code', (tester) async {
    final fixture = _InviteFixture([_a])..afterCreate = [_a, _b];
    await _pump(tester, fixture);
    await _hoverStage(tester);
    // The create card is the pager's terminal page — page to it first.
    await tester.tap(find.byKey(const ValueKey('v3-invite-next')));
    await tester.pumpAndSettle();
    // The share rows stay on the create page — hiding them used to collapse
    // the whole panel and make it jump between pages.
    expect(find.byKey(const ValueKey('v3-invite-copy-link')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('v3-invite-create')));
    // Bounded pumps: pumpAndSettle would consume the floating toast entire
    // lifetime and remove it before its content could be asserted.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('CODE-B'), findsOneWidget);
    expect(find.text('2 / 2'), findsOneWidget);
    expect(find.text('邀请码已创建'), findsOneWidget);
    // Flush the floating toast timer before the tree is disposed.
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('creation error is shown instead of a success message', (tester) async {
    final fixture = _InviteFixture([_a])..createError = '创建权限不足';
    await _pump(tester, fixture);
    await _hoverStage(tester);
    // The create card is the pager's terminal page — page to it first.
    await tester.tap(find.byKey(const ValueKey('v3-invite-next')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('v3-invite-create')));
    // Bounded pumps: pumpAndSettle would consume the floating toast entire
    // lifetime and remove it before its content could be asserted.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('创建权限不足'), findsOneWidget);
    expect(find.text('邀请码已创建'), findsNothing);
    expect(find.text('CODE-A'), findsOneWidget);
    // Flush the floating toast timer before the tree is disposed.
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('create timeout releases the spinner with a retryable toast', (tester) async {
    final fixture = _InviteFixture([_a])..createHangs = true;
    await _pump(tester, fixture);
    await _hoverStage(tester);
    await tester.tap(find.byKey(const ValueKey('v3-invite-next')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('v3-invite-create')));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    // The 20s page cap fires while the hanging request is still pending;
    // the UI returns to the last code with an honest timeout toast.
    await tester.pump(const Duration(seconds: 21));
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('CODE-A'), findsOneWidget);
    expect(find.text('创建请求超时，请稍后刷新查看是否成功'), findsOneWidget);
    // Flush the floating toast timer before the tree is disposed.
    await tester.pump(const Duration(seconds: 3));
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
