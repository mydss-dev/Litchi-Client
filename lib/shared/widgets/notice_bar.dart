import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../l10n/l10n.dart';
import '../models/api_models.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_text_styles.dart';
import 'notice_carousel.dart';

/// Slim desktop announcement bar.
///
/// The image carousel is intentionally kept for compact layouts and special
/// campaign content. Desktop home uses this 44px ticker so notices stay visible
/// without pushing the connection controls below the fold.
class NoticeBar extends StatefulWidget {
  const NoticeBar({
    super.key,
    required this.notices,
    this.isLoading = false,
  });

  final List<NoticeModel> notices;
  final bool isLoading;

  @override
  State<NoticeBar> createState() => _NoticeBarState();
}

class _NoticeBarState extends State<NoticeBar> {
  static const _interval = Duration(seconds: 5);

  final Set<int> _dismissedIds = <int>{};
  Timer? _timer;
  int _index = 0;

  List<NoticeModel> get _visibleNotices => widget.notices
      .where((notice) => !_dismissedIds.contains(notice.id))
      .toList(growable: false);

  @override
  void initState() {
    super.initState();
    _ensureTimer();
  }

  @override
  void didUpdateWidget(covariant NoticeBar oldWidget) {
    super.didUpdateWidget(oldWidget);

    // An unrelated AppController notification can rebuild the whole dashboard
    // while keeping the exact same notice list instance. Do not restart the
    // autoplay timer in that case or a busy dashboard can indefinitely defer
    // the next announcement.
    final beforeVisibleIds = oldWidget.notices
        .where((notice) => !_dismissedIds.contains(notice.id))
        .map((notice) => notice.id)
        .toList(growable: false);

    // NoticesController replaces the list object after a real fetch. Treat that
    // as a fresh announcement session so items hidden by the user can reappear
    // after an explicit/background refresh, while ordinary rebuilds keep them
    // dismissed.
    final refreshed = !identical(oldWidget.notices, widget.notices);
    if (refreshed) _dismissedIds.clear();

    final afterVisibleIds = _visibleNotices
        .map((notice) => notice.id)
        .toList(growable: false);
    final visibleSetChanged = !listEquals(beforeVisibleIds, afterVisibleIds);

    if (_index >= afterVisibleIds.length) _index = 0;

    if (visibleSetChanged) {
      _restartTimer();
    } else {
      _ensureTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _ensureTimer() {
    final count = _visibleNotices.length;
    if (count < 2) {
      _timer?.cancel();
      _timer = null;
      return;
    }
    _timer ??= Timer.periodic(_interval, (_) {
      if (!mounted) return;
      final visible = _visibleNotices;
      if (visible.length < 2) {
        _ensureTimer();
        return;
      }
      setState(() => _index = (_index + 1) % visible.length);
    });
  }

  void _restartTimer() {
    _timer?.cancel();
    _timer = null;
    _ensureTimer();
  }

  void _dismissCurrent() {
    final visible = _visibleNotices;
    if (visible.isEmpty) return;
    final safeIndex = _index >= visible.length ? 0 : _index;
    setState(() {
      _dismissedIds.add(visible[safeIndex].id);
      _index = 0;
    });
    _restartTimer();
  }

  Future<void> _openNotice(NoticeModel notice) async {
    await showDialog<void>(
      context: context,
      builder: (_) => NoticePopupDialog(notice: notice),
    );
  }

  String _summary(NoticeModel notice) {
    final title = notice.title.trim();
    final plain = notice.content
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll(RegExp(r'&nbsp;?', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (title.isEmpty) return plain;
    if (plain.isEmpty || plain == title) return title;
    return '$title  ·  $plain';
  }

  Widget _withBottomGap(Widget child) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: child,
      );

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final visible = _visibleNotices;

    if (widget.isLoading && visible.isEmpty) {
      return _withBottomGap(
        Container(
          height: 44,
          decoration: BoxDecoration(
            color: c.cardBg,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: c.softBorder),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              Icon(LucideIcons.megaphone, size: 16, color: c.iconMuted),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  height: 10,
                  decoration: BoxDecoration(
                    color: c.surfaceMuted,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (visible.isEmpty) return const SizedBox.shrink();

    final safeIndex = _index >= visible.length ? 0 : _index;
    final notice = visible[safeIndex];

    return _withBottomGap(
      Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openNotice(notice),
          mouseCursor: SystemMouseCursors.click,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Ink(
            height: 44,
            decoration: BoxDecoration(
              color: c.cardBg,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: c.softBorder),
            ),
            padding: const EdgeInsets.fromLTRB(10, 0, 6, 0),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: c.primarySoft,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Icon(
                    LucideIcons.megaphone,
                    size: 14,
                    color: c.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    layoutBuilder: (currentChild, previousChildren) => Stack(
                      alignment: Alignment.centerLeft,
                      children: [...previousChildren, ?currentChild],
                    ),
                    child: Text(
                      _summary(notice),
                      key: ValueKey(notice.id),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.body.copyWith(
                        color: c.textSecondary,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  context.l10n.view,
                  style: AppTextStyles.caption.copyWith(
                    color: c.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Icon(LucideIcons.chevronRight, size: 15, color: c.primary),
                const SizedBox(width: 2),
                Tooltip(
                  message: context.l10n.close,
                  child: IconButton(
                    onPressed: _dismissCurrent,
                    visualDensity: VisualDensity.compact,
                    iconSize: 15,
                    color: c.iconMuted,
                    splashRadius: 16,
                    icon: const Icon(LucideIcons.x),
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
