import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../shared/models/api_models.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_text_styles.dart';

/// Compact dismissible banner for a single notice.
/// The caller decides when to show/hide it via [AppController.hasUnreadNotice].
class NoticeBanner extends StatelessWidget {
  const NoticeBanner({
    super.key,
    required this.notice,
    required this.onDismiss,
  });

  final NoticeModel notice;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 9, 10, 9),
      decoration: BoxDecoration(
        color: c.primarySoft,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: c.primary.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.bellRing, size: 15, color: c.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              notice.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.body.copyWith(
                color: c.textPrimary,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 8),
          _TextBtn(
            label: '查看详情',
            color: c.primary,
            onTap: () => _showDetail(context),
          ),
          const SizedBox(width: 6),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: onDismiss,
              child: Icon(LucideIcons.x, size: 14, color: c.textMuted),
            ),
          ),
        ],
      ),
    );
  }

  void _showDetail(BuildContext context) {
    onDismiss(); // mark as read before showing detail
    showDialog(
      context: context,
      builder: (_) => _NoticeDetailDialog(notice: notice),
    );
  }
}

class _NoticeDetailDialog extends StatelessWidget {
  const _NoticeDetailDialog({required this.notice});

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
            '关闭',
            style: AppTextStyles.button.copyWith(color: c.primary),
          ),
        ),
      ],
    );
  }
}

class _TextBtn extends StatelessWidget {
  const _TextBtn({
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Text(
          label,
          style: AppTextStyles.button.copyWith(
            color: color,
            fontSize: 12,
            decoration: TextDecoration.underline,
            decorationColor: color.withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }
}
