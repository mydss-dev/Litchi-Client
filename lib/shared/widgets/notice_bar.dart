import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../l10n/l10n.dart';
import '../models/api_models.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_text_styles.dart';
import 'notice_carousel.dart';

/// Slim desktop news ticker.
///
/// Desktop treats notices as persistent news rather than consumable alerts:
/// opening a notice never removes it. Multiple items rotate every 8 seconds
/// with a visible progress track, while hover/detail reading pauses autoplay.
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

class _NoticeBarState extends State<NoticeBar>
    with SingleTickerProviderStateMixin {
  static const _interval = Duration(seconds: 8);

  late final AnimationController _progress;
  int _index = 0;
  bool _hovering = false;
  bool _dialogOpen = false;

  @override
  void initState() {
    super.initState();
    _progress = AnimationController(vsync: this, duration: _interval)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) _advance();
      });
    _syncPlayback(restart: true);
  }

  @override
  void didUpdateWidget(covariant NoticeBar oldWidget) {
    super.didUpdateWidget(oldWidget);

    final oldIds = oldWidget.notices.map((notice) => notice.id).toList();
    final newIds = widget.notices.map((notice) => notice.id).toList();
    final changed = !listEquals(oldIds, newIds);

    if (widget.notices.isEmpty) {
      _index = 0;
    } else if (changed) {
      final oldCurrentId = oldWidget.notices.isEmpty
          ? null
          : oldWidget.notices[_index.clamp(0, oldWidget.notices.length - 1)].id;
      final matchingIndex = oldCurrentId == null
          ? -1
          : widget.notices.indexWhere((notice) => notice.id == oldCurrentId);
      _index = matchingIndex >= 0
          ? matchingIndex
          : _index.clamp(0, widget.notices.length - 1);
    } else if (_index >= widget.notices.length) {
      _index = 0;
    }

    _syncPlayback(restart: changed);
  }

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  void _advance() {
    if (!mounted || widget.notices.length < 2) return;
    setState(() => _index = (_index + 1) % widget.notices.length);
    _syncPlayback(restart: true);
  }

  void _syncPlayback({bool restart = false}) {
    if (widget.notices.length < 2 || _hovering || _dialogOpen) {
      _progress.stop();
      if (widget.notices.length < 2) _progress.value = 0;
      return;
    }
    if (restart) {
      _progress.forward(from: 0);
    } else if (!_progress.isAnimating) {
      _progress.forward();
    }
  }

  void _setHovering(bool value) {
    if (_hovering == value) return;
    setState(() => _hovering = value);
    _syncPlayback();
  }

  Future<void> _openNotice(NoticeModel notice) async {
    _dialogOpen = true;
    _syncPlayback();
    await showDialog<void>(
      context: context,
      builder: (_) => NoticePopupDialog(notice: notice),
    );
    if (!mounted) return;
    _dialogOpen = false;
    _syncPlayback();
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

    if (widget.isLoading && widget.notices.isEmpty) {
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

    // No placeholder copy: when the server has no news, the ticker is absent.
    if (widget.notices.isEmpty) return const SizedBox.shrink();

    final safeIndex = _index.clamp(0, widget.notices.length - 1);
    final notice = widget.notices[safeIndex];
    final hasMultiple = widget.notices.length > 1;

    return _withBottomGap(
      MouseRegion(
        onEnter: (_) => _setHovering(true),
        onExit: (_) => _setHovering(false),
        child: Material(
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
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 0, 10, 2),
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
                            layoutBuilder: (currentChild, previousChildren) =>
                                Stack(
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
                        if (hasMultiple) ...[
                          const SizedBox(width: 12),
                          Text(
                            '${safeIndex + 1} / ${widget.notices.length}',
                            style: AppTextStyles.caption.copyWith(
                              color: c.textMuted,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        const SizedBox(width: 12),
                        Text(
                          context.l10n.view,
                          style: AppTextStyles.caption.copyWith(
                            color: c.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Icon(
                          LucideIcons.chevronRight,
                          size: 15,
                          color: c.primary,
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: 2,
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(AppRadius.lg),
                      ),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ColoredBox(color: c.surfaceMuted),
                          if (hasMultiple)
                            AnimatedBuilder(
                              animation: _progress,
                              builder: (context, _) => Align(
                                alignment: Alignment.centerLeft,
                                child: FractionallySizedBox(
                                  widthFactor: _progress.value,
                                  child: ColoredBox(
                                    color: c.primary.withValues(alpha: 0.72),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
