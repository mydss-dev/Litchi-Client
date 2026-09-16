import 'dart:io';

import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../shared/models/app_models.dart';
import '../../shared/services/update_service.dart';
import '../../shared/services/url_opener.dart';
import '../theme/v3_palette.dart';

/// "A newer version exists", on the dashboard, until it is dismissed.
///
/// [UpdateService.check] has been running since the rebuild but nothing showed
/// its result, so an available update was invisible. The banner is the whole
/// of the presentation: the version, what changed, and a way to act on it.
///
/// Downloading in place is desktop-only — [UpdateService.downloadAndInstall]
/// refuses on anything else, deliberately, because Android updates arrive
/// through the store or an APK the user installs. Android therefore opens the
/// release page instead, which is what this did before the rebuild.
class V3UpdateBanner extends StatefulWidget {
  const V3UpdateBanner({super.key});

  @override
  State<V3UpdateBanner> createState() => _V3UpdateBannerState();
}

class _V3UpdateBannerState extends State<V3UpdateBanner> {
  bool _downloading = false;
  int _received = 0;
  int _total = -1;

  static bool get _canInstallInPlace => Platform.isWindows || Platform.isMacOS;

  /// Everything else opens the release page: [UpdateService.downloadAndInstall]
  /// is desktop-only and refuses outright elsewhere, so the alternative to a
  /// browser is no way to update at all.
  static bool get _canOpenReleasePage => Platform.isAndroid || Platform.isLinux;

  double get _progress => _total > 0 ? (_received / _total).clamp(0.0, 1.0) : 0;

  Future<void> _download(UpdateInfo info) async {
    if (_downloading) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _downloading = true;
      _received = 0;
      _total = -1;
    });
    try {
      if (_canInstallInPlace) {
        await UpdateService.downloadAndInstall(
          info,
          onProgress: (received, total) {
            if (mounted) {
              setState(() {
                _received = received;
                _total = total;
              });
            }
          },
        );
        if (!mounted) return;
        setState(() => _downloading = false);
        _notify(messenger, '安装包已下载，正在启动安装程序…');
      } else {
        final opened = await UrlOpener.open(info.downloadUrl);
        if (!mounted) return;
        setState(() => _downloading = false);
        if (!opened) throw StateError('无法打开下载页面');
        _notify(messenger, '已打开下载页面');
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _downloading = false;
        _received = 0;
        _total = -1;
      });
      _notify(
        messenger,
        error
            .toString()
            .replaceFirst('Exception: ', '')
            .replaceFirst('StateError: ', ''),
      );
    }
  }

  void _notify(ScaffoldMessengerState messenger, String message) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    // Subscribes: the check finishes well after the first frame, and this is
    // mounted on a page that may not rebuild for any other reason.
    final controller = AppScope.of(context);
    final info = controller.updateInfo;
    if (info == null) return const SizedBox.shrink();

    final changelog = info.changelog.replaceAll(RegExp(r'\s+'), ' ').trim();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
        decoration: BoxDecoration(
          // A success tint rather than a plain card: an available update is
          // the one piece of news on this page that is neither the user's
          // doing nor a problem. The accents on it are the Ink variant,
          // because a tinted ground is what the base fills fail on.
          color: p.success.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: p.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.arrow_circle_up_rounded,
                  size: 17,
                  color: p.successInk,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '发现新版本 ${info.version}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: p.ink,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (changelog.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          changelog,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: p.inkMuted, fontSize: 11),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (_downloading)
                  Text(
                    '${(_progress * 100).toStringAsFixed(0)}%',
                    style: TextStyle(
                      color: p.successInk,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  )
                else if (_canInstallInPlace || _canOpenReleasePage)
                  TextButton(
                    onPressed: () => _download(info),
                    style: TextButton.styleFrom(
                      foregroundColor: p.successInk,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      minimumSize: const Size(0, 34),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      textStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    child: Text(_canInstallInPlace ? '立即更新' : '前往下载'),
                  ),
                IconButton(
                  tooltip: '暂不提示',
                  onPressed: _downloading ? null : controller.dismissUpdate,
                  icon: const Icon(Icons.close_rounded, size: 17),
                  color: p.inkMuted,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            if (_downloading) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  // Indeterminate until the server says how large the file is.
                  value: _total > 0 ? _progress : null,
                  minHeight: 3,
                  color: p.successInk,
                  backgroundColor: p.ink.withValues(alpha: 0.08),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
