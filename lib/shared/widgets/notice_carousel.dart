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
  const NoticeCarousel({super.key, required this.notices});

  final List<NoticeModel> notices;

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

  @override
  Widget build(BuildContext context) {
    if (widget.notices.isEmpty) return const SizedBox.shrink();
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
        child: Stack(
          fit: StackFit.expand,
          children: [
            PageView.builder(
              controller: _controller,
              itemCount: widget.notices.length,
              onPageChanged: _onPageChanged,
              itemBuilder: (context, i) =>
                  _NoticeSlide(notice: widget.notices[i]),
            ),
            if (widget.notices.length > 1)
              Positioned(
                right: 12,
                bottom: 10,
                child: _Dots(count: widget.notices.length, index: _index),
              ),
          ],
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
            left: 16,
            right: 48,
            bottom: 12,
            child: Row(
              children: [
                const Icon(
                  LucideIcons.megaphone,
                  size: 14,
                  color: Colors.white,
                ),
                const SizedBox(width: 8),
                Expanded(
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
