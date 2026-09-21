import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../pages/v3_gift_card_page.dart';
import '../pages/v3_orders_page.dart';
import '../theme/v3_palette.dart';
import 'v3_components.dart';
import 'v3_layout.dart';
import 'v3_locale_copy.dart';

/// The width at which the workspace and its sheets switch layouts.
const double kV3CompactBreakpoint = 760;

/// Wide windows show a centered modal; compact windows show a bottom drawer.
/// Account subpages stay above their parent, preserving the selected tab.
Future<T?> showV3Sheet<T>(
  BuildContext context, {
  required String title,
  Widget? trailing,
  required WidgetBuilder builder,
}) {
  final size = MediaQuery.sizeOf(context);
  final compact = size.width < kV3CompactBreakpoint;

  Widget content(BuildContext ctx) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      V3SheetHeader(title: title, trailing: trailing),
      Flexible(child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(22, 2, 22 + 0.0,
          22 + MediaQuery.paddingOf(ctx).bottom),
        child: Builder(builder: builder))),
    ]);
  }

  if (compact) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: V3Palette.of(context).surface,
      barrierColor: Colors.black.withValues(alpha: .48),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(V3Radius.panel))),
      constraints: BoxConstraints(maxHeight: size.height * .9),
      builder: content);
  }

  return showDialog<T>(context: context,
    barrierColor: Colors.black.withValues(alpha: .48),
    builder: (ctx) {
      final p = V3Palette.of(ctx);
      return Dialog(backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        child: Container(width: 560,
          constraints: const BoxConstraints(maxHeight: 720),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(color: p.surface,
            borderRadius: BorderRadius.circular(V3Radius.panel),
            border: Border.all(color: p.line)),
          child: content(ctx)));
    });
}

class V3SheetHeader extends StatelessWidget {
  const V3SheetHeader({super.key, required this.title, this.trailing});
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return Padding(padding: const EdgeInsets.fromLTRB(22, 16, 10, 4),
      child: Row(children: [
        Expanded(child: Text(title, maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: p.ink, fontSize: 19,
            fontWeight: FontWeight.w800, letterSpacing: -.2))),
        ?trailing,
        IconButton(
          tooltip: v3Copy(context, zh: '关闭', en: 'Close', tw: '關閉'),
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close_rounded, size: 20),
          color: p.inkMuted),
      ]));
  }
}

/// Whether this build targets desktop, matching the shell's own target check.
/// The hub-open decision is a navigation-model question — desktop gets a
/// first-class workspace page — not a window-width question, so platform is
/// the honest signal here.
bool _v3DesktopTarget(BuildContext context) => !kIsWeb &&
    switch (Theme.of(context).platform) {
      TargetPlatform.windows ||
      TargetPlatform.macOS ||
      TargetPlatform.linux => true,
      _ => false,
    };

/// Hub destinations. On desktop, orders is a first-class workspace page — the
/// shell owns its [V3SheetPageFallback] — because a 560dp modal is a
/// phone-shaped place to manage a ledger. Compact targets keep the sheet
/// above the account page. The gift card stays a modal everywhere: it is a
/// single form.
void openV3Page(BuildContext context, AppPage page) {
  final Future<void> Function(BuildContext)? sheet = switch (page) {
    AppPage.orders => _v3DesktopTarget(context) ? null : V3OrdersPage.show,
    AppPage.giftCard => V3GiftCardPage.show,
    _ => null,
  };
  if (sheet == null) {
    AppScope.read(context).goToPage(page);
    return;
  }
  unawaited(sheet(context));
}

class V3SheetPageFallback extends StatelessWidget {
  const V3SheetPageFallback({super.key, required this.kicker,
    required this.title, this.description, required this.child});
  final String kicker;
  final String title;
  final String? description;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: V3Layout.pageInsets,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        V3PageHeader(kicker: kicker, title: title, description: description),
        const SizedBox(height: 24),
        child,
      ]));
  }
}

void closeV3Sheet(BuildContext context) {
  final route = ModalRoute.of(context);
  if (route != null && !route.isFirst) Navigator.of(context).pop();
}