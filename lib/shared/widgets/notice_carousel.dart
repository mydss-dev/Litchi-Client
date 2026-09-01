import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../l10n/l10n.dart';
import '../models/api_models.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_text_styles.dart';

/// Auto-rotating announcement carousel (§24): a PageView-backed banner that
/// advances through every notice on a timer, with dot indicators. Each slide
/// uses the notice image (when the backend supplies one) over a gradient
/// fallback, and opens the full notice on tap.
///
/// Replaces the old single-notice [NoticeBanner].
class NoticeCarousel extends StatefulWidget {
  const NoticeCarousel({
    super.key,
    required this.notices,
    this.isLoading = false,
  });

  final List<NoticeModel> notices;
  final bool isLoading;

  @override
  State<NoticeCarousel> createState() => _NoticeCarouselState();
}

class _NoticeCarouselState extends State<NoticeCarousel> {
  static const _bannerHeight = 132.0;
  static const _interval = Duration(seconds: 4);

  final PageController _controller = PageController();
  Timer? _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _startAutoPlay();
  }

  @override
  void didUpdateWidget(covariant NoticeCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Notices load asynchronously; start auto-play once there are >= 2.
    if (widget.notices.length >= 2 && _timer == null) _startAutoPlay();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _startAutoPlay() {
    if (widget.notices.length < 2) return;
    _timer = Timer.periodic(_interval, (_) {
      if (!_controller.hasClients) return;
      final next = (_index + 1) % widget.notices.length;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeInOut,
      );
    });
  }

  void _onPageChanged(int index) => setState(() => _index = index);

  void _goTo(int page) {
    if (!_controller.hasClients) return;
    _controller.animateToPage(
      page,
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeInOut,
    );
  }

  void _previous() =>
      _goTo((_index - 1 + widget.notices.length) % widget.notices.length);

  void _next() => _goTo((_index + 1) % widget.notices.length);

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return SizedBox(
      width: double.infinity,
      height: _bannerHeight,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: c.softBorder),
        ),
        child: widget.isLoading
            ? const _NoticeSkeleton()
            : widget.notices.isEmpty
                ? const _NoticePlaceholder()
                : Stack(
                    fit: StackFit.expand,
                    children: [
                      PageView.builder(
                        controller: _controller,
                        itemCount: widget.notices.length,
                        onPageChanged: _onPageChanged,
                        itemBuilder: (context, i) =>
                            _NoticeSlide(notice: widget.notices[i]),
                      ),
                      if (widget.notices.length > 1) ...[
                        Positioned(
                          left: 6,
                          top: 0,
                          bottom: 0,
                          child: Center(
                            child: _NavArrow(left: true, onTap: _previous),
                          ),
                        ),
                        Positioned(
                          right: 6,
                          top: 0,
                          bottom: 0,
                          child: Center(
                            child: _NavArrow(left: false, onTap: _next),
                          ),
                        ),
                        Positioned(
                          right: 12,
                          bottom: 10,
                          child: _Dots(
                            count: widget.notices.length,
                            index: _index,
                          ),
                        ),
                      ],
                    ],
                  ),
      ),
    );
  }
}

/// Quiet placeholder shown while notices are loading (or when none exist), so
/// the banner slot keeps its fixed height and the layout below never jumps.
class _NoticePlaceholder extends StatelessWidget {
  const _NoticePlaceholder();

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return ColoredBox(
      color: c.surfaceMuted,
      child: Center(
        child: Icon(
          LucideIcons.megaphone,
          size: 22,
          color: c.textMuted.withValues(alpha: 0.35),
        ),
      ),
    );
  }
}

/// Shimmer-style placeholder shown while notices load and nothing is cached.
class _NoticeSkeleton extends StatefulWidget {
  const _NoticeSkeleton();

  @override
  State<_NoticeSkeleton> createState() => _NoticeSkeletonState();
}

class _NoticeSkeletonState extends State<_NoticeSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = Curves.easeInOut.transform(_controller.value);
        return Container(
          color: Color.lerp(
            c.surfaceMuted,
            c.primary.withValues(alpha: 0.14),
            t,
          ),
          alignment: Alignment.bottomLeft,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Container(
            width: 220,
            height: 14,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.30),
              borderRadius: BorderRadius.circular(7),
            ),
          ),
        );
      },
    );
  }
}

/// Circular left/right buttons that let the user page the carousel manually.
class _NavArrow extends StatelessWidget {
  const _NavArrow({required this.left, required this.onTap});

  final bool left;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.28),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(7),
          child: Icon(
            left ? LucideIcons.chevronLeft : LucideIcons.chevronRight,
            size: 18,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _NoticeSlide extends StatelessWidget {
  const _NoticeSlide({required this.notice});

  final NoticeModel notice;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final hasImage = notice.imgUrl != null && notice.imgUrl!.isNotEmpty;

    return GestureDetector(
      onTap: () => _showDetail(context),
      child: Stack(
        fit: StackFit.expand,
        children: [
          _fallback(c),
          if (hasImage)
            Image.network(
              notice.imgUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          // Bottom scrim keeps the title readable over any image.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Color(0x66000000)],
              ),
            ),
          ),
          Positioned(
            left: 12,
            top: 12,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.25),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                LucideIcons.megaphone,
                size: 15,
                color: Colors.white,
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 48,
            bottom: 12,
            child: Text(
              notice.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodyStrong.copyWith(
                color: Colors.white,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fallback(AppColors c) {
    return DecoratedBox(decoration: BoxDecoration(gradient: c.brandGradient));
  }

  void _showDetail(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => NoticeDetailDialog(notice: notice),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < count; i++) ...[
          if (i > 0) const SizedBox(width: 5),
          AnimatedContainer(
            duration: const Duration(milliseconds: 240),
            width: i == index ? 16 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: i == index
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ],
      ],
    );
  }
}

/// Full notice shown in a dialog when a carousel slide is tapped.
class NoticeDetailDialog extends StatelessWidget {
  const NoticeDetailDialog({super.key, required this.notice});

  final NoticeModel notice;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return AlertDialog(
      backgroundColor: c.cardBg,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(color: c.softBorder),
      ),
      title: Row(
        children: [
          Icon(LucideIcons.megaphone, size: 18, color: c.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              notice.title,
              style: AppTextStyles.bodyStrong.copyWith(
                color: c.textPrimary,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                notice.dateDisplay,
                style: AppTextStyles.caption.copyWith(color: c.textMuted),
              ),
              const SizedBox(height: 12),
              Text(
                notice.content,
                style: AppTextStyles.body.copyWith(
                  color: c.textSecondary,
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            context.l10n.close,
            style: AppTextStyles.button.copyWith(color: c.primary),
          ),
        ),
      ],
    );
  }
}
