import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../l10n/l10n.dart';
import '../models/api_models.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_text_styles.dart';

/// Browsable desktop notice detail dialog.
///
/// Unlike the must-read login popup, this is a normal dismissible dialog and
/// lets the user move through all currently loaded notices without waiting for
/// the ticker to rotate.
class NoticePagerDialog extends StatefulWidget {
  const NoticePagerDialog({
    super.key,
    required this.notices,
    required this.initialIndex,
  });

  final List<NoticeModel> notices;
  final int initialIndex;

  @override
  State<NoticePagerDialog> createState() => _NoticePagerDialogState();
}

class _NoticePagerDialogState extends State<NoticePagerDialog> {
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.notices.isEmpty
        ? 0
        : widget.initialIndex.clamp(0, widget.notices.length - 1);
  }

  void _previous() {
    if (_index <= 0) return;
    setState(() => _index--);
  }

  void _next() {
    if (_index >= widget.notices.length - 1) return;
    setState(() => _index++);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    if (widget.notices.isEmpty) return const SizedBox.shrink();

    final notice = widget.notices[_index];
    final hasMultiple = widget.notices.length > 1;

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
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
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
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      actions: [
        if (hasMultiple) ...[
          IconButton(
            onPressed: _index > 0 ? _previous : null,
            icon: const Icon(LucideIcons.chevronLeft),
            iconSize: 18,
            visualDensity: VisualDensity.compact,
          ),
          Text(
            '${_index + 1} / ${widget.notices.length}',
            style: AppTextStyles.caption.copyWith(
              color: c.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
          IconButton(
            onPressed: _index < widget.notices.length - 1 ? _next : null,
            icon: const Icon(LucideIcons.chevronRight),
            iconSize: 18,
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: 8),
        ],
        TextButton(
          onPressed: () => Navigator.of(context).pop(_index),
          child: Text(
            context.l10n.close,
            style: AppTextStyles.button.copyWith(color: c.primary),
          ),
        ),
      ],
    );
  }
}
