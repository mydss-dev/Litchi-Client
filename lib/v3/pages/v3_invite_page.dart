import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_controller.dart';
import '../../shared/models/app_models.dart';
import '../theme/v3_motion.dart';
import '../theme/v3_palette.dart';
import '../ui/v3_components.dart';
import '../ui/v3_empty_state.dart';
import '../ui/v3_layout.dart';
import '../ui/v3_locale_copy.dart';
import '../ui/v3_toast.dart';

class V3InvitePage extends StatefulWidget {
  const V3InvitePage({super.key});
  @override
  State<V3InvitePage> createState() => _V3InvitePageState();
}

class _V3InvitePageState extends State<V3InvitePage> {
  int _selected = 0;
  String? _selectedIdentity;
  bool _creating = false;

  List<InviteCodeModel> _codes(AppController controller) {
    if (controller.inviteCodes.isNotEmpty) return controller.inviteCodes;
    final code = controller.inviteCode.trim();
    final link = controller.inviteLink.trim();
    if (code.isEmpty && link.isEmpty) return const [];
    return [InviteCodeModel(code: code, link: link)];
  }

  String _identity(InviteCodeModel item) => item.code.trim().isNotEmpty
      ? 'code:${item.code.trim()}'
      : 'link:${item.link.trim()}';

  int _activeIndex(List<InviteCodeModel> codes) {
    if (codes.isEmpty) return 0;
    if (_selectedIdentity != null) {
      final index = codes.indexWhere(
        (item) => _identity(item) == _selectedIdentity,
      );
      if (index >= 0) return index;
    }
    return _selected.clamp(0, codes.length - 1);
  }

  // The pager is linear over codes.length + 1 pages — every code, then the
  // create card as the terminal page. The ends hold; no wraparound.
  bool _onCreatePage = false;

  void _goTo(List<InviteCodeModel> codes, int index) {
    setState(() {
      _onCreatePage = false;
      _selected = index;
      _selectedIdentity = _identity(codes[index]);
    });
  }

  void _next(List<InviteCodeModel> codes) {
    if (_onCreatePage) return;
    if (_selected >= codes.length - 1) {
      setState(() => _onCreatePage = true);
      return;
    }
    _goTo(codes, _selected + 1);
  }

  void _prev(List<InviteCodeModel> codes) {
    if (_onCreatePage) {
      _goTo(codes, codes.length - 1);
      return;
    }
    if (_selected <= 0) return;
    _goTo(codes, _selected - 1);
  }

  void _toast(String message, {V3ToastType type = V3ToastType.info}) {
    if (!mounted) return;
    V3Toast.show(context, message, type: type);
  }

  Future<void> _copy(String value, String message) async {
    if (value.trim().isEmpty) return;
    final copyFailure = v3Copy(
      context,
      zh: '复制失败，请重试',
      en: 'Copy failed. Please retry.',
      tw: '複製失敗，請重試',
    );
    try {
      await Clipboard.setData(ClipboardData(text: value.trim()));
      _toast(message, type: V3ToastType.success);
    } catch (_) {
      _toast(copyFailure, type: V3ToastType.error);
    }
  }

  Future<void> _createCode() async {
    if (_creating) return;
    final controller = AppScope.read(context);
    final before = _codes(controller).map(_identity).toSet();
    final created = v3Copy(
      context,
      zh: '邀请码已创建',
      en: 'Invite code created',
      tw: '邀請碼已建立',
    );
    final pending = v3Copy(
      context,
      zh: '创建请求已完成，邀请码尚未同步，请稍后刷新',
      en: 'Request completed, but the code has not synced. Refresh shortly.',
      tw: '建立請求已完成，但邀請碼尚未同步，請稍後重新整理',
    );
    setState(() => _creating = true);
    // The create chain (API + full refresh) can crawl for minutes when the
    // server is down — the spinner must never outlive the user's patience.
    // A page-level cap releases the UI with an honest, retryable message;
    // the request itself keeps running and a later refresh picks it up.
    final String? error;
    try {
      error = await controller.createInviteCode().timeout(
        const Duration(seconds: 20),
      );
    } on TimeoutException {
      if (!mounted) return;
      final timedOut = v3Copy(
        context,
        zh: '创建请求超时，请稍后刷新查看是否成功',
        en: 'Create request timed out. Refresh later to check.',
        tw: '建立請求逾時，請稍後重新整理查看是否成功',
      );
      setState(() {
        _creating = false;
        _onCreatePage = false;
        _selected = _activeIndex(_codes(controller));
      });
      _toast(timedOut, type: V3ToastType.error);
      return;
    }
    if (!mounted) return;
    final after = _codes(controller);
    final added = error == null
        ? after.where((item) => !before.contains(_identity(item))).toList()
        : <InviteCodeModel>[];
    setState(() {
      _creating = false;
      _onCreatePage = false;
      if (added.isNotEmpty) {
        _selectedIdentity = _identity(added.last);
        _selected = after.indexWhere(
          (item) => _identity(item) == _selectedIdentity,
        );
      } else {
        _selected = _activeIndex(after);
      }
    });
    if (error != null) {
      _toast(error, type: V3ToastType.error);
    } else if (added.isNotEmpty) {
      _toast(created, type: V3ToastType.success);
    } else {
      _toast(pending);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final codes = _codes(controller);
    final index = _activeIndex(codes);
    // The selected code stays resolved on the create page too: the link bar
    // and share rows below keep their content while paging. Only the empty
    // state has nothing to show.
    final active = codes.isEmpty ? null : codes[index];
    final hero = _InviteHero(
      code: active?.code ?? '',
      link: active?.link ?? '',
      currentIndex: index,
      total: codes.length,
      onCreatePage: _onCreatePage,
      creating: _creating,
      onPrevious: codes.isEmpty ? null : () => _prev(codes),
      onNext: codes.isEmpty ? null : () => _next(codes),
      onCreate: _createCode,
      onCopyCode: () => _copy(
        active?.code ?? '',
        v3Copy(context, zh: '邀请码已复制', en: 'Invite code copied', tw: '邀請碼已複製'),
      ),
      onCopyLink: () => _copy(
        active?.link ?? '',
        v3Copy(context, zh: '邀请链接已复制', en: 'Invite link copied', tw: '邀請連結已複製'),
      ),
      // One-tap share is a clipboard hand-off: copy the link and name the
      // destination, matching the hero's share-row comment.
      onShareTo: (target) => _copy(
        active?.link ?? '',
        v3Copy(
          context,
          zh: '链接已复制，去 $target 粘贴发送',
          en: 'Link copied — paste it in $target',
          tw: '連結已複製，貼到 $target 發送',
        ),
      ),
    );
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: V3Layout.pageInsets,
      child: V3WaveColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          V3PageHeader(
            title: v3Copy(
              context,
              zh: '邀请好友',
              en: 'Invite friends',
              tw: '邀請好友',
            ),
            trailing: IconButton(
              tooltip: v3Copy(
                context,
                zh: '刷新邀请数据',
                en: 'Refresh invitations',
                tw: '重新整理邀請資料',
              ),
              onPressed: controller.refreshData,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ),
          const SizedBox(height: 18),
          // Full-width hero, then stats, then the ledger. Splitting hero
          // beside stats starves the code stage and cramps the link bar and
          // share row.
          hero,
          const SizedBox(height: 16),
          _InviteStats(controller: controller),
          const SizedBox(height: 16),
          _ReferralLedger(controller: controller),
        ],
      ),
    );
  }
}

class _InviteHero extends StatelessWidget {
  const _InviteHero({
    required this.code,
    required this.link,
    required this.currentIndex,
    required this.total,
    required this.onCreatePage,
    required this.creating,
    required this.onPrevious,
    required this.onNext,
    required this.onCreate,
    required this.onCopyCode,
    required this.onCopyLink,
    required this.onShareTo,
  });
  final String code;
  final String link;
  final int currentIndex;
  final int total;
  final bool onCreatePage;
  final bool creating;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback onCreate;
  final VoidCallback onCopyCode;
  final VoidCallback onCopyLink;
  final ValueChanged<String> onShareTo;

  // Fixed third-party brand hues for the share icons, like the country flags:
  // they identify the destination app, not Litchi's own palette. X stays
  // monochrome on purpose — its mark is black/white.
  static const _shareTargets = [
    (label: '微信', en: 'WeChat', tw: '微信', brand: Color(0xFF2AAE67)),
    (label: 'QQ', en: 'QQ', tw: 'QQ', brand: Color(0xFF12B7F5)),
    (label: 'Twitter', en: 'X', tw: 'Twitter', brand: null),
    (label: 'Telegram', en: 'Telegram', tw: 'Telegram', brand: Color(0xFF27A7E5)),
  ];

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    final hasCode = code.trim().isNotEmpty;
    final hasLink = link.trim().isNotEmpty;
    // The pager's terminal page is the create card; with no codes at all it
    // is the whole panel — nothing to page through, so no arrows.
    final empty = total == 0;
    final onCard = onCreatePage || empty;
    // Link bar and share row carry the active code's link — kept on the
    // create page too, so paging there no longer collapses the panel and
    // makes it jump. Only the empty state has nothing to share.
    final showShareRows = total > 0;
    // Neutral hero ground, same material as the traffic quota panel and the
    // shell sidebar — brand color comes from the accents (create tile, chips,
    // share icons). The old inner title/description duplicated the page
    // header, so the panel is purely functional now: stage first, then the
    // action rows.
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: p.hero,
        borderRadius: BorderRadius.circular(V3Radius.panel),
        border: Border.all(color: p.hairline),
        boxShadow: p.shadows,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The pager owns the panel's face: the card takes the full width
          // and the arrows live INSIDE as hover/focus-revealed overlays
          // (linear paging — the ends hold, no wraparound).
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: empty
                ? _createCard(context, p)
                : _InvitePager(
                    canPrevious: onCreatePage || currentIndex > 0,
                    canNext: !onCreatePage,
                    onPrevious: onPrevious,
                    onNext: onNext,
                    child: onCard
                        ? _createCard(context, p)
                        : _InviteStageCard(
                            code: code,
                            link: link,
                            currentIndex: currentIndex,
                            total: total,
                            onCopyCode: onCopyCode,
                          ),
                  ),
          ),
          if (showShareRows) ...[
            const SizedBox(height: 10),
            // Link bar: the URL reads like an input, with its copy action
            // inline where the eye already is.
            Container(
              constraints: const BoxConstraints(minHeight: 48),
              padding: const EdgeInsets.fromLTRB(12, 6, 8, 6),
              decoration: BoxDecoration(
                color: p.surfaceRaised,
                borderRadius: BorderRadius.circular(V3Radius.field),
                border: Border.all(color: p.hairline),
              ),
              child: Row(
                children: [
                  Icon(Icons.link_rounded, size: 16, color: p.inkMuted),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      hasLink
                          ? link.trim()
                          : hasCode
                              ? v3Copy(
                                  context,
                                  zh: '后台尚未提供邀请链接，可分享邀请码',
                                  en: 'No link yet. You can share your invite code.',
                                  tw: '後台尚未提供邀請連結，可分享邀請碼',
                                )
                              : v3Copy(
                                  context,
                                  zh: '创建邀请码后即可分享',
                                  en: 'Create an invite code to start sharing',
                                  tw: '建立邀請碼後即可分享',
                                ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: hasLink ? p.ink : p.inkMuted,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton(
                    key: const ValueKey('v3-invite-copy-link'),
                    onPressed: hasLink ? onCopyLink : null,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: p.ink,
                      side: const BorderSide(color: Colors.transparent),
                      backgroundColor: p.surface,
                      minimumSize: const Size(0, 34),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                    ),
                    child: Text(
                      v3Copy(
                        context,
                        zh: '复制链接',
                        en: 'Copy link',
                        tw: '複製連結',
                      ),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            // One-tap share: copies the link and tells the user where to paste
            // it. Desktop has no share sheet; the clipboard hand-off is the
            // share. Disabled while there is no link to hand off.
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 2),
                  child: Text(
                    v3Copy(context, zh: '分享到', en: 'Share to', tw: '分享到'),
                    style: TextStyle(color: p.inkMuted, fontSize: 11),
                  ),
                ),
                for (final target in _shareTargets)
                  OutlinedButton.icon(
                    onPressed: hasLink
                        ? () => onShareTo(
                              v3Copy(
                                context,
                                zh: target.label,
                                en: target.en,
                                tw: target.tw,
                              ),
                            )
                        : null,
                    icon: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: target.brand ?? p.inkMuted,
                        shape: BoxShape.circle,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: p.ink,
                      side: BorderSide(color: p.line),
                      minimumSize: const Size(0, 34),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    label: Text(
                      v3Copy(
                        context,
                        zh: target.label,
                        en: target.en,
                        tw: target.tw,
                      ),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// The pager's terminal page: a dashed add-card, the shared "create new"
  /// affordance (Ant's dashed add-tile, the iOS Wallet add page). In the
  /// empty state it is the whole panel; tapping anywhere creates.
  Widget _createCard(BuildContext context, V3Palette p) {
    return InkWell(
      key: const ValueKey('v3-invite-create'),
      onTap: creating ? null : onCreate,
      borderRadius: BorderRadius.circular(V3Radius.field),
      child: CustomPaint(
        painter: _DashedRRectPainter(color: p.line, radius: V3Radius.field),
        child: SizedBox(
          height: 172,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: p.lychee.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(V3Radius.control),
                  ),
                  child: creating
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: p.lychee,
                          ),
                        )
                      : Icon(Icons.add_rounded, color: p.lychee, size: 20),
                ),
                const SizedBox(height: 10),
                Text(
                  v3Copy(
                    context,
                    zh: '新建邀请码',
                    en: 'New invite code',
                    tw: '建立邀請碼',
                  ),
                  style: TextStyle(
                    color: p.ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The invite-code stage as a tinted card — the one colored surface on the
/// hero. A soft lychee wash lifts the code off the neutral panel, and the
/// card owns the pager's full width: the arrows float inside its edges as
/// hover/focus-revealed overlays ([_InvitePager]) instead of eating flanks.
class _InviteStageCard extends StatelessWidget {
  const _InviteStageCard({
    required this.code,
    required this.link,
    required this.currentIndex,
    required this.total,
    required this.onCopyCode,
  });

  final String code;
  final String link;
  final int currentIndex;
  final int total;
  final VoidCallback onCopyCode;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    final hasCode = code.trim().isNotEmpty;
    final hasLink = link.trim().isNotEmpty;
    return Container(
      key: const ValueKey('v3-invite-stage'),
      width: double.infinity,
      // Same fixed height as the create card, so paging between codes and
      // the create card never resizes the panel mid-hover.
      height: 172,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            p.lychee.withValues(alpha: .11),
            p.lychee.withValues(alpha: .04),
          ],
        ),
        borderRadius: BorderRadius.circular(V3Radius.field),
        border: Border.all(color: p.lychee.withValues(alpha: .20)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(
                v3Copy(
                  context,
                  zh: '邀请码',
                  en: 'Invite code',
                  tw: '邀請碼',
                ),
                style: TextStyle(
                  color: p.inkMuted,
                  fontSize: 11,
                  height: 1.2,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              if (total > 0)
                Text(
                  '${currentIndex + 1} / $total',
                  style: TextStyle(
                    color: p.inkMuted,
                    fontSize: 11,
                    height: 1.2,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            hasCode
                ? code.trim()
                : hasLink
                    ? v3Copy(
                        context,
                        zh: '后台未返回邀请码',
                        en: 'No code returned by the server',
                        tw: '後台未傳回邀請碼',
                      )
                    : v3Copy(
                        context,
                        zh: '还没有邀请码',
                        en: 'No invite code yet',
                        tw: '尚無邀請碼',
                      ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: hasCode ? p.ink : p.inkMuted,
              fontSize: hasCode ? 28 : 15,
              height: 1.2,
              fontWeight: hasCode ? FontWeight.w900 : FontWeight.w600,
              letterSpacing: hasCode ? .8 : 0,
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            key: const ValueKey('v3-invite-copy-code'),
            onPressed: hasCode ? onCopyCode : null,
            style: OutlinedButton.styleFrom(
              foregroundColor: p.ink,
              side: BorderSide(color: p.line),
              minimumSize: const Size(0, 34),
              // Desktop mouse target — shrinkWrap keeps the measured height
              // pinned at 34 instead of the padded 48 tap target.
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: const EdgeInsets.symmetric(horizontal: 14),
            ),
            child: Text(
              v3Copy(
                context,
                zh: '复制邀请码',
                en: 'Copy code',
                tw: '複製邀請碼',
              ),
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

/// The pager chrome around the stage/create card. The whole area is
/// focusable (click or Tab), and the left/right arrows float INSIDE the
/// card's edges — revealed only on hover or focus, the Fluent/Apple carousel
/// behavior — so the card keeps its full width. Paging is linear: the first
/// page holds the left arrow, the create card is the terminal right stop;
/// no wraparound.
class _InvitePager extends StatefulWidget {
  const _InvitePager({
    required this.canPrevious,
    required this.canNext,
    required this.onPrevious,
    required this.onNext,
    required this.child,
  });

  final bool canPrevious;
  final bool canNext;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final Widget child;

  @override
  State<_InvitePager> createState() => _InvitePagerState();
}

class _InvitePagerState extends State<_InvitePager> {
  final FocusNode _focusNode = FocusNode();
  bool _focused = false;
  bool _hovered = false;

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  // KeyDown plus KeyRepeat: holding an arrow pages like holding it in a text
  // field. Events arrive here while focus sits on the pager or any child
  // (the copy button) — they bubble through this Focus node. At either end
  // the key is left for the system: the ends hold, no wraparound.
  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      if (!widget.canPrevious) return KeyEventResult.ignored;
      widget.onPrevious?.call();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      if (!widget.canNext) return KeyEventResult.ignored;
      widget.onNext?.call();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Widget _arrow(
    V3Palette p, {
    required Key key,
    required IconData icon,
    required bool enabled,
    required VoidCallback? onTap,
    required String tooltip,
  }) {
    // Hover/focus reveals BOTH arrows even at the ends — the disabled one
    // stays visible, dimmed and inert, so the pair never looks lopsided
    // (Fluent/Apple carousel chrome).
    final revealed = _focused || _hovered;
    return Tooltip(
      message: tooltip,
      child: AnimatedOpacity(
        opacity: revealed ? (enabled ? 1.0 : 0.4) : 0.0,
        duration: v3ReducedMotion(context) ? Duration.zero : V3Motion.fast,
        child: IgnorePointer(
          ignoring: !revealed || !enabled,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: p.surfaceRaised,
              shape: BoxShape.circle,
              border: Border.all(color: p.hairline),
              boxShadow: p.shadows,
            ),
            child: IconButton(
              key: key,
              padding: EdgeInsets.zero,
              iconSize: 20,
              onPressed: enabled ? onTap : null,
              icon: Icon(icon, color: p.ink, size: 20),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return Focus(
      focusNode: _focusNode,
      onKeyEvent: _handleKey,
      onFocusChange: (focused) => setState(() => _focused = focused),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: _focusNode.requestFocus,
          behavior: HitTestBehavior.opaque,
          child: Stack(
            children: [
              widget.child,
              Positioned(
                left: 10,
                top: 0,
                bottom: 0,
                child: Center(
                  child: _arrow(
                    p,
                    key: const ValueKey('v3-invite-previous'),
                    icon: Icons.chevron_left_rounded,
                    enabled: widget.canPrevious,
                    onTap: widget.onPrevious,
                    tooltip: v3Copy(
                      context,
                      zh: '上一个邀请码',
                      en: 'Previous code',
                      tw: '上一個邀請碼',
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 10,
                top: 0,
                bottom: 0,
                child: Center(
                  child: _arrow(
                    p,
                    key: const ValueKey('v3-invite-next'),
                    icon: Icons.chevron_right_rounded,
                    enabled: widget.canNext,
                    onTap: widget.onNext,
                    tooltip: v3Copy(
                      context,
                      zh: '下一个邀请码',
                      en: 'Next code',
                      tw: '下一個邀請碼',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dashed rounded-rect stroke for the create card — the shared "add new"
/// signifier (Ant's dashed add-tile, HTML dropzones). Flutter ships no
/// dashed [Border], so the card paints its own.
class _DashedRRectPainter extends CustomPainter {
  const _DashedRRectPainter({required this.color, required this.radius});
  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
          Offset.zero & size, Radius.circular(radius)));
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = color;
    // Walk the path dash-on/dash-off; per-metric so the rounded corners keep
    // the rhythm instead of clipping a fixed dash count per edge.
    for (final metric in path.computeMetrics()) {
      final length = metric.length;
      var distance = 0.0;
      while (distance < length) {
        final end = (distance + 4).clamp(0.0, length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance = end + 4;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedRRectPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}

class _InviteStats extends StatelessWidget {
  const _InviteStats({required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    final symbol = controller.currencySymbol;
    final entries = [
      (
        label: v3Copy(context, zh: '邀请人数', en: 'Friends invited', tw: '邀請人數'),
        value: '${controller.invitedCount}',
        suffix: v3Copy(context, zh: '人', en: ' people', tw: '人'),
        positive: false,
        amount: null,
        icon: Icons.group_add_rounded,
        accent: p.lychee,
      ),
      (
        label: v3Copy(context, zh: '返佣比例', en: 'Commission rate', tw: '返佣比例'),
        value: controller.commissionRate.toStringAsFixed(0),
        suffix: '%',
        positive: false,
        amount: null,
        icon: Icons.percent_rounded,
        accent: p.aquaInk,
      ),
      (
        label: v3Copy(context, zh: '累计佣金', en: 'Total commission', tw: '累計佣金'),
        value: '',
        suffix: '',
        positive: false,
        amount: controller.earnedCommission,
        icon: Icons.payments_rounded,
        accent: p.aquaInk,
      ),
      (
        label: v3Copy(
          context,
          zh: '待确认佣金',
          en: 'Pending commission',
          tw: '待確認佣金',
        ),
        value: '',
        suffix: '',
        positive: false,
        amount: controller.pendingCommission,
        icon: Icons.schedule_rounded,
        accent: p.warning,
      ),
      // Withdrawable balance is the one number the user can act on — green
      // marks it as money in hand, not just a counter, and it leads the band
      // by a step in size.
      (
        label: v3Copy(context, zh: '可提现佣金', en: 'Withdrawable', tw: '可提領佣金'),
        value: '',
        suffix: '',
        positive: controller.withdrawable > 0,
        amount: controller.withdrawable,
        icon: Icons.account_balance_wallet_rounded,
        accent: p.success,
      ),
    ];

    // One quiet band instead of five floating cards: a single panel whose
    // cells are divided by 1px hairlines (the Stripe/Ant-Pro KPI-strip
    // structure), with the traffic page's colored icon-tile DNA so the stats
    // read as the same family. The compact pane stacks the same cells as a
    // 2-column grid inside the same panel.
    Widget cell(entry) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: entry.accent.withValues(alpha: .11),
                  borderRadius: BorderRadius.circular(V3Radius.control),
                ),
                child: Icon(entry.icon, color: entry.accent, size: 16),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      entry.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: p.inkMuted, fontSize: 10),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Flexible(
                          child: entry.amount != null
                              ? V3RollingMoney(
                                  value: entry.amount!,
                                  symbol: symbol,
                                  style: TextStyle(
                                    color: entry.positive
                                        ? p.successInk
                                        : p.ink,
                                    fontSize: entry.positive ? 18 : 16,
                                    fontWeight: FontWeight.w900,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures()
                                    ],
                                  ),
                                )
                              : Text(
                                  entry.value,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: entry.positive
                                        ? p.successInk
                                        : p.ink,
                                    fontSize: entry.positive ? 18 : 16,
                                    fontWeight: FontWeight.w900,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures()
                                    ],
                                  ),
                                ),
                        ),
                        if (entry.suffix.isNotEmpty) ...[
                          const SizedBox(width: 3),
                          Text(
                            entry.suffix,
                            style: TextStyle(color: p.inkMuted, fontSize: 10),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );

    Widget hairline({required bool vertical}) => Container(
          width: vertical ? 1 : double.infinity,
          height: vertical ? 32 : 1,
          color: p.line,
        );

    return LayoutBuilder(
      builder: (context, box) {
        final wide = box.maxWidth >= V3Layout.paneCompact;
        return V3Panel(
          padding: EdgeInsets.zero,
          child: wide
              ? Row(children: [
                  for (var i = 0; i < entries.length; i++) ...[
                    if (i > 0) hairline(vertical: true),
                    Expanded(child: cell(entries[i])),
                  ],
                ])
              // Compact: the same cells pair up into a 2-column grid inside
              // the one panel, separated by horizontal hairlines.
              : Column(children: [
                  for (var r = 0; r < entries.length; r += 2) ...[
                    if (r > 0) hairline(vertical: false),
                    Row(children: [
                      Expanded(child: cell(entries[r])),
                      if (r + 1 < entries.length)
                        Expanded(child: cell(entries[r + 1]))
                      else
                        const Spacer(),
                    ]),
                  ],
                ]),
        );
      },
    );
  }
}

class _ReferralLedger extends StatelessWidget {
  const _ReferralLedger({required this.controller});
  final AppController controller;
  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    final records = controller.inviteRecords;
    return V3Panel(
      padding: const EdgeInsets.all(20),
      radius: V3Radius.panel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  v3Copy(
                    context,
                    zh: '最近返佣记录',
                    en: 'RECENT COMMISSIONS',
                    tw: '最近返佣紀錄',
                  ),
                  style: TextStyle(
                    color: p.inkMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
              Text(
                v3Copy(
                  context,
                  zh: '${records.length} 条',
                  en: '${records.length} entries',
                  tw: '${records.length} 筆',
                ),
                style: TextStyle(color: p.inkMuted, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (records.isEmpty)
            V3EmptyState(
              icon: Icons.receipt_long_rounded,
              title: v3Copy(
                context,
                zh: '暂无返佣记录',
                en: 'No commission records',
                tw: '暫無返佣紀錄',
              ),
              subtitle: v3Copy(
                context,
                zh: '好友消费后，返佣会显示在这里。',
                en: 'Commission shows up here once your referrals pay.',
                tw: '好友消費後，返佣會顯示在這裡。',
              ),
            )
          else
            for (final record in records.take(8))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: p.surfaceRaised,
                        borderRadius: BorderRadius.circular(V3Radius.field),
                      ),
                      child: Icon(
                        Icons.person_add_alt_1_rounded,
                        color: p.lycheeInk,
                        size: 17,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            record.userName.trim().isEmpty
                                ? v3Copy(
                                    context,
                                    zh: '新用户',
                                    en: 'New user',
                                    tw: '新用戶',
                                  )
                                : record.userName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: p.ink,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            record.dateDisplay,
                            style: TextStyle(color: p.inkMuted, fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          record.commissionDisplay(controller.currencySymbol),
                          style: TextStyle(
                            color: p.successInk,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          record.amountDisplay(controller.currencySymbol),
                          style: TextStyle(color: p.inkMuted, fontSize: 10,
                            fontFeatures: const [FontFeature.tabularFigures()]),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}
