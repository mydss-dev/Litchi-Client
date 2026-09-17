import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../pages/v3_gift_card_page.dart';
import '../pages/v3_orders_page.dart';
import '../theme/v3_palette.dart';
import 'v3_components.dart';

/// Keep the modal breakpoint aligned with the desktop shell.
const double kV3CompactBreakpoint = 760;

/// Wide windows get a centered dialog; compact windows get a bottom sheet.
Future<T?> showV3Sheet<T>(
  BuildContext context, {
  required String title,
  Widget? trailing,
  required WidgetBuilder builder,
}) {
  final size = MediaQuery.sizeOf(context);
  final compact = size.width < kV3CompactBreakpoint;

  Widget content(BuildContext ctx) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      V3SheetHeader(title: title, trailing: trailing),
      Flexible(child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          22, 2, 22, 22 + MediaQuery.paddingOf(ctx).bottom),
        child: Builder(builder: builder),
      )),
    ],
  );

  if (compact) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: V3Palette.of(context).surface,
      barrierColor: Colors.black.withValues(alpha: 0.48),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      constraints: BoxConstraints(maxHeight: size.height * 0.9),
      builder: content,
    );
  }

  return showDialog<T>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.48),
    builder: (ctx) {
      final p = V3Palette.of(ctx);
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        child: Container(
          width: 560,
          constraints: const BoxConstraints(maxHeight: 720),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: p.line),
          ),
          child: content(ctx),
        ),
      );
    },
  );
}

class V3SheetHeader extends StatelessWidget {
  const V3SheetHeader({super.key, required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 16, 10, 4),
      child: Row(children: [
        Expanded(child: Text(title, maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: p.ink, fontSize: 19,
            fontWeight: FontWeight.w800, letterSpacing: -0.2))),
        ?trailing,
        IconButton(tooltip: '关闭',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close_rounded, size: 20),
          color: p.inkMuted),
      ]),
    );
  }
}

/// Account-owned destinations are dialogs, everything else is a page swap.
void openV3Page(BuildContext context, AppPage page) {
  final Future<void> Function(BuildContext)? sheet = switch (page) {
    AppPage.orders => V3OrdersPage.show,
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
    required this.title, required this.child});
  final String kicker;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(24, 26, 24, 36),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      V3PageHeader(kicker: kicker, title: title),
      const SizedBox(height: 24),
      child,
    ]),
  );
}

/// The caller may be the underlying account page rather than a widget inside
/// the sheet. Navigator.canPop checks the actual stack, so it safely dismisses
/// the top sheet in either case without ever popping the shell's only route.
void closeV3Sheet(BuildContext context) {
  final navigator = Navigator.of(context);
  if (navigator.canPop()) navigator.pop();
}
