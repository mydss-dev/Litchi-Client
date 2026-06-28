import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../models/app_models.dart';
import '../services/update_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_text_styles.dart';
import 'app_toast.dart';

/// Compact dismissible banner shown when a newer app version is available.
///
/// When the user taps "download", the app fetches the installer directly
/// (with an in-banner progress bar) and verifies its SHA-256 hash before
/// launching it — no browser round-trip.
class UpdateBanner extends StatefulWidget {
  const UpdateBanner({super.key, required this.info, required this.onDismiss});

  final UpdateInfo info;
  final VoidCallback onDismiss;

  @override
  State<UpdateBanner> createState() => _UpdateBannerState();
}

class _UpdateBannerState extends State<UpdateBanner> {
  bool _downloading = false;
  int _received = 0;
  int _total = -1;

  double get _progress =>
      _total > 0 ? (_received / _total).clamp(0.0, 1.0) : 0.0;

  Future<void> _download() async {
    if (_downloading) return;
    setState(() {
      _downloading = true;
      _received = 0;
      _total = -1;
    });

    try {
      await UpdateService.downloadAndInstall(
        widget.info,
        onProgress: (received, total) {
          if (mounted) setState(() { _received = received; _total = total; });
        },
      );
      if (mounted) {
        AppToast.show(context, '下载完成，正在打开安装包',
            type: AppToastType.success);
      }
    } catch (e) {
      if (mounted) {
        AppToast.show(
          context,
          e.toString().replaceFirst('Exception: ', ''),
          type: AppToastType.error,
        );
        setState(() { _downloading = false; _received = 0; _total = -1; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final info = widget.info;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 9, 10, 9),
      decoration: BoxDecoration(
        color: c.success.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: c.success.withValues(alpha: 0.30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
              if (info.downloadUrl.isNotEmpty && !_downloading)
                _TextBtn(
                  label: '立即下载',
                  color: c.success,
                  onTap: _download,
                ),
              if (_downloading)
                _TextBtn(
                  label: '${(_progress * 100).toStringAsFixed(0)}%',
                  color: c.success,
                  onTap: null,
                ),
              const SizedBox(width: 6),
              if (!_downloading)
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: widget.onDismiss,
                    child: Icon(LucideIcons.x, size: 14, color: c.textMuted),
                  ),
                ),
            ],
          ),
          if (_downloading) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: _total > 0 ? _progress : null,
                minHeight: 3,
                backgroundColor: c.success.withValues(alpha: 0.15),
                color: c.success,
              ),
            ),
          ],
        ],
      ),
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
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Text(
          label,
          style: AppTextStyles.button.copyWith(
            color: onTap == null ? color.withValues(alpha: 0.4) : color,
            fontSize: 12,
            decoration: TextDecoration.underline,
            decorationColor: color.withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }
}
