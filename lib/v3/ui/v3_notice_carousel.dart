import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../shared/models/api_models.dart';
import '../../shared/models/app_models.dart';
import '../../shared/services/url_opener.dart';
import '../theme/v3_motion.dart';
import '../theme/v3_palette.dart';
import 'v3_components.dart';
import 'v3_locale_copy.dart';
import 'v3_notice_bar.dart';

/// Phone landing lane: backend notice images rotate as a carousel with the
/// title overlaid, arrows on both sides and a page counter. The update
/// prompt outranks announcements and owns page 0. Tap opens the same reader
/// dialog as the desktop ticker. Desktop keeps the slim one-line ticker — a
/// tall image card there would push the connect orb below the fold.
class V3NoticeCarousel extends StatefulWidget {
  const V3NoticeCarousel({super.key, required this.controller});
  final AppController controller;

  @override
  State<V3NoticeCarousel> createState() => _V3NoticeCarouselState();
}

class _V3NoticeCarouselState extends State<V3NoticeCarousel> {
  // Cap the carousel so a chatty feed cannot bury the connect card; the
  // reader dialog still reaches every notice.
  static const _maxPages = 6;
  static const _interval = Duration(seconds: 6);
  final PageController _pages = PageController();
  Timer? _timer;
  int _index = 0;
  List<NoticeModel> _notices = const [];

  UpdateInfo? get _update => widget.controller.updateInfo;
  /// The update page owns page 0; announcements shift behind it.
  int get _updateOffset => _update == null ? 0 : 1;
  int get _pageCount => _notices.length + _updateOffset;

  @override
  void initState() {
    super.initState();
    _notices = widget.controller.notices.take(_maxPages).toList();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // v3ReducedMotion reads MediaQuery, which cannot be depended on during
    // initState — the first timer sync starts here instead.
    _syncTimer();
  }

  @override
  void didUpdateWidget(covariant V3NoticeCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    _notices = widget.controller.notices.take(_maxPages).toList();
    _index = _pageCount == 0 ? 0 : _index.clamp(0, _pageCount - 1);
    _syncTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pages.dispose();
    super.dispose();
  }

  void _syncTimer() {
    _timer?.cancel();
    _timer = null;
    // Reduced motion means no 6s auto-advance at all; hovering pauses the
    // timer and leaving resumes through this same sync.
    if (_pageCount > 1 && !v3ReducedMotion(context)) {
      _timer = Timer.periodic(_interval, (_) => _go(1));
    }
  }

  Future<void> _go(int delta) async {
    if (_pageCount < 2) return;
    final target = (_index + delta + _pageCount) % _pageCount;
    if (_pages.hasClients) {
      if (v3ReducedMotion(context)) {
        _pages.jumpToPage(target);
      } else {
        await _pages.animateToPage(
          target,
          duration: V3Motion.medium,
          curve: V3Motion.ease,
        );
      }
    }
    if (!mounted) return;
    setState(() => _index = target);
    _syncTimer();
  }

  Future<void> _open(int index) async {
    if (index >= _notices.length) return;
    _timer?.cancel();
    await V3NoticeDialog.showReader(
      context,
      notices: _notices,
      initialIndex: index,
    );
    if (!mounted) return;
    _index = _index.clamp(0, _pageCount - 1);
    _syncTimer();
  }

  @override
  Widget build(BuildContext context) {
    if (_pageCount == 0) return const SizedBox.shrink();
    final p = V3Palette.of(context);
    // Hovering pauses the 6s auto-advance so the page under the pointer
    // stays put; leaving resumes it. Reduced motion never starts a timer.
    return MouseRegion(
      onEnter: (_) => _timer?.cancel(),
      onExit: (_) => _syncTimer(),
      child: Container(
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(V3Radius.card),
          border: Border.all(color: p.hairline),
          boxShadow: p.shadows,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(V3Radius.card),
          child: SizedBox(
            height: 148,
            child: Stack(
              children: [
                Positioned.fill(
                  child: PageView.builder(
                    itemCount: _pageCount,
                    controller: _pages,
                    onPageChanged: (i) => setState(() => _index = i),
                    itemBuilder: (context, index) {
                      // The update prompt outranks announcements: it owns
                      // page 0; notices shift one page back.
                      if (index < _updateOffset) {
                        return _NoticeUpdatePage(update: _update!);
                      }
                      final noticeIndex = index - _updateOffset;
                      return _NoticeImagePage(
                        notice: _notices[noticeIndex],
                        onTap: () => _open(noticeIndex),
                      );
                    },
                  ),
                ),
                if (_pageCount > 1) ...[
                  _NoticeCarouselArrow(
                    icon: Icons.chevron_left_rounded,
                    onTap: () => _go(-1),
                    alignLeft: true,
                  ),
                  _NoticeCarouselArrow(
                    icon: Icons.chevron_right_rounded,
                    onTap: () => _go(1),
                    alignLeft: false,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One announcement: the backend image full-bleed with the title scrimmed at
/// the bottom; without an image a quiet gradient carries the title alone.
class _NoticeImagePage extends StatelessWidget {
  const _NoticeImagePage({required this.notice, required this.onTap});
  final NoticeModel notice;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    final title = v3NoticeHeadline(notice, fallback: '公告');
    final image = notice.imgUrl?.trim() ?? '';
    return Stack(
      fit: StackFit.expand,
      children: [
        if (image.isNotEmpty)
          Image.network(
            image,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Container(color: p.surfaceRaised),
            loadingBuilder: (context, child, progress) =>
                progress == null ? child : Container(color: p.surfaceRaised),
          )
        else
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [p.lycheeSoft, p.surfaceRaised],
              ),
            ),
          ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: .78),
                ],
                // Deepens only in the title zone so the photo above stays
                // bright, and the white title still clears 4.5:1.
                stops: const [0.35, 1.0],
              ),
            ),
          ),
        ),
        Positioned(
          left: 14,
          right: 14,
          bottom: 10,
          child: Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              height: 1.3,
            ),
          ),
        ),
        // The pressable rides on top of the full-bleed image — ink paints
        // below its own Material's child, so wrapping the page would hide it
        // under the photo. The card's ClipRRect clips the ink to the rounded
        // corners.
        Positioned.fill(
          child: V3Pressable(
            onTap: onTap,
            borderRadius: BorderRadius.circular(V3Radius.card),
            child: const SizedBox.expand(),
          ),
        ),
      ],
    );
  }
}

/// The release page: same lane, update call-to-action instead of an image.
class _NoticeUpdatePage extends StatelessWidget {
  const _NoticeUpdatePage({required this.update});
  final UpdateInfo update;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return Container(
      color: p.surfaceRaised,
      // Padding rides inside the pressable so the whole page stays tappable
      // edge to edge and the ink covers it; the card's ClipRRect clips the
      // ink to the rounded corners.
      child: V3Pressable(
        onTap: () => unawaited(UrlOpener.open(update.downloadUrl)),
        borderRadius: BorderRadius.circular(V3Radius.card),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: p.lychee,
                  borderRadius: BorderRadius.circular(V3Radius.field),
                ),
                child: Icon(
                  Icons.system_update_rounded,
                  color: p.onLychee,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      v3Copy(context,
                        zh: '新版本 ${update.version} 可用',
                        en: 'Version ${update.version} is available',
                        tw: '新版本 ${update.version} 可用'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: p.ink,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      v3Copy(context,
                        zh: '点按前往下载页面',
                        en: 'Tap to open the download page',
                        tw: '點按前往下載頁面'),
                      style: TextStyle(color: p.inkMuted, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: p.lychee, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoticeCarouselArrow extends StatelessWidget {
  const _NoticeCarouselArrow({
    required this.icon,
    required this.onTap,
    required this.alignLeft,
  });
  final IconData icon;
  final VoidCallback onTap;
  final bool alignLeft;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      bottom: 0,
      left: alignLeft ? 6 : null,
      right: alignLeft ? null : 6,
      child: Center(
        child: SizedBox(
          width: 44,
          height: 44,
          child: Tooltip(
            message: alignLeft
                ? v3Copy(context, zh: '上一条', en: 'Previous', tw: '上一則')
                : v3Copy(context, zh: '下一条', en: 'Next', tw: '下一則'),
            child: Material(
              color: Colors.black.withValues(alpha: .55),
              shape: CircleBorder(
                side: BorderSide(color: Colors.white.withValues(alpha: .2))),
              child: InkWell(
                onTap: onTap,
                customBorder: const CircleBorder(),
                child: Center(
                  child: Icon(icon, color: Colors.white, size: 20),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
