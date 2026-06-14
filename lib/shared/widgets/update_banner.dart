import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../models/app_models.dart';
import '../services/url_opener.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_text_styles.dart';

/// Compact dismissible banner shown when a newer app version is available.
class UpdateBanner extends StatelessWidget {
  const UpdateBanner({
    super.key,
    required this.info,
    required this.onDismiss,
  });

  final UpdateInfo info;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 9, 10, 9),
      decoration: BoxDecoration(
        color: c.success.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: c.success.withValues(alpha: 0.30)),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.arrowUpCircle, size: 15, color: c.success),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '发现新版本 v${info.version}，点击下载最新版本',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.body.copyWith(
                color: c.textPrimary,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (info.downloadUrl.isNotEmpty)
            _TextBtn(
              label: '立即下载',
              color: c.success,
              onTap: () => _openDownload(info.downloadUrl),
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

  Future<void> _openDownload(String url) async {
    await UrlOpener.open(url);
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
