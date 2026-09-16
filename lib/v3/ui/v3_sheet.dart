import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../pages/v3_gift_card_page.dart';
import '../pages/v3_orders_page.dart';
import '../pages/v3_wallet_page.dart';
import '../theme/v3_palette.dart';
import 'v3_components.dart';

/// The width at which v3 swaps between its wide and its compact layout.
///
/// Kept in step with `_V3Workspace`'s own breakpoint: a sheet that picked a
/// different one would come up as a bottom drawer on a window that is drawing
/// the desktop rail.
const double kV3CompactBreakpoint = 760;

/// Opens [title]'s content as a modal.
///
/// Wide windows get a centred dialog and narrow ones a bottom drawer. Both are
/// the same sheet: the header, the scroll container and the surface treatment
/// come from here, so a caller writes only its content.
///
/// This exists because the account's sub-pages (wallet, orders, gift card) were
/// routed pages with no way back — the shell's navigation is a page swap with no
/// history, so entering one from the account hub meant leaving the bar's
/// highlighted tab behind and having nothing on screen to return by. A modal
/// does not need a way back: dismissing it is the way back, and the page
/// underneath never went anywhere.
Future<T?> showV3Sheet<T>(
  BuildContext context, {
  required String title,
  Widget? trailing,
  required WidgetBuilder builder,
}) {
  final size = MediaQuery.sizeOf(context);
  final compact = size.width < kV3CompactBreakpoint;

  Widget content(BuildContext ctx) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        V3SheetHeader(title: title, trailing: trailing),
        Flexible(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              22,
              2,
              22,
              22 + MediaQuery.paddingOf(ctx).bottom,
            ),
            child: Builder(builder: builder),
          ),
        ),
      ],
    );
  }

  if (compact) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: V3Palette.of(context).surface,
      barrierColor: Colors.black.withValues(alpha: 0.48),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      // Sizes to its content, but never past the point where the page behind it
      // stops being visible evidence that this is a layer, not a destination.
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

/// The sheet's title row and its close affordance.
///
/// The close button is not optional and not the caller's to supply: a modal
/// whose only dismissal is a tap outside is the same dead end the routed pages
/// had, one layer up.
class V3SheetHeader extends StatelessWidget {
  const V3SheetHeader({super.key, required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 16, 10, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: p.ink,
                fontSize: 19,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
            ),
          ),
          ?trailing,
          IconButton(
            tooltip: '关闭',
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded, size: 20),
            color: p.inkMuted,
          ),
        ],
      ),
    );
  }
}

/// Opens [page] the way that page is meant to be opened.
///
/// Wallet, orders and the gift card are modals; everything else is still a
/// page swap. Being total is the point — a nav list can hand this every entry
/// it has without asking which kind each one is, and a page added to the
/// account hub later opens correctly instead of becoming a dead row.
///
/// Returns nothing on purpose: every caller opens something and walks away,
/// and there is no result to hand back. Saying so keeps the call sites from
/// each needing `unawaited`.
void openV3Page(BuildContext context, AppPage page) {
  final Future<void> Function(BuildContext)? sheet = switch (page) {
    AppPage.wallet => V3WalletPage.show,
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

/// Renders a page that is normally a sheet as a full page instead.
///
/// `_pageFor` still answers for wallet, orders and the gift card, because a
/// stray `goToPage` should land on the real thing rather than a blank screen.
/// What those pages can no longer do on their own is be a *page*: the sheet
/// owns their title and their scrolling, so this puts both back.
class V3SheetPageFallback extends StatelessWidget {
  const V3SheetPageFallback({
    super.key,
    required this.kicker,
    required this.title,
    required this.child,
  });

  final String kicker;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 26, 24, 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          V3PageHeader(kicker: kicker, title: title),
          const SizedBox(height: 24),
          child,
        ],
      ),
    );
  }
}

/// Closes the sheet [context] is drawn in, if it is drawn in one.
///
/// The three modal pages are still reachable as routed pages through
/// `_pageFor`'s fallback, and a bare `Navigator.pop()` there would take the
/// shell itself off the stack — the app would be left with nothing behind it.
/// So this asks the route first.
void closeV3Sheet(BuildContext context) {
  final route = ModalRoute.of(context);
  if (route != null && !route.isFirst) Navigator.of(context).pop();
}
