import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../shared/models/api_models.dart';
import '../theme/v3_palette.dart';

/// Turns a notice body into something a [Text] can show.
///
/// Panels send HTML — `<p>`, `<br>`, `<a>`, entity escapes — and this app has
/// no HTML renderer, so the tags have to go. Block ends and `<br>` become
/// newlines rather than spaces, which keeps the paragraphing the sender
/// intended; everything else is dropped. Rich HTML (links, lists, images in
/// the body) is therefore flattened to text, which is a real limitation and
/// the reason the notice's own [NoticeModel.imgUrl] is shown as an image
/// instead of being left inline.
String v3NoticeText(String source) {
  return source
      .replaceAll(RegExp(r'<\s*br\s*/?\s*>', caseSensitive: false), '\n')
      .replaceAll(
        RegExp(r'</\s*(p|div|li|tr|h[1-6])\s*>', caseSensitive: false),
        '\n',
      )
      .replaceAll(RegExp(r'<[^>]*>'), '')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll(RegExp(r'[ \t]+\n'), '\n')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
}

/// The announcements ticker: one slim line at the top of the dashboard.
///
/// Notices are news rather than alerts, so this never removes one — reading a
/// notice does not clear the bar, and the bar is absent (not empty-looking)
/// when the server has nothing to say. Several notices rotate every eight
/// seconds; hovering or having the reader open pauses the rotation, which
/// matters because the thing being replaced is the thing being read.
class V3NoticeBar extends StatefulWidget {
  const V3NoticeBar({super.key, required this.controller});

  final AppController controller;

  @override
  State<V3NoticeBar> createState() => _V3NoticeBarState();
}

class _V3NoticeBarState extends State<V3NoticeBar>
    with SingleTickerProviderStateMixin {
  static const _interval = Duration(seconds: 8);

  late final AnimationController _progress;
  int _index = 0;
  bool _hovering = false;
  bool _reading = false;

  List<NoticeModel> get _notices => widget.controller.notices;

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
  void didUpdateWidget(covariant V3NoticeBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The list changes under the ticker: the disk cache lands first and the
    // fetch replaces it a moment later. Following the *slot* across that would
    // swap the announcement out from under someone mid-read, so the notice on
    // screen is followed by id and only falls back to the slot when it is gone.
    final oldIds = oldWidget.controller.notices.map((n) => n.id).toList();
    final newIds = _notices.map((n) => n.id).toList();
    if (_notices.isEmpty) {
      _index = 0;
    } else if (!listEquals(oldIds, newIds)) {
      final currentId = oldIds.isEmpty
          ? null
          : oldIds[_index.clamp(0, oldIds.length - 1)];
      final found = currentId == null ? -1 : newIds.indexOf(currentId);
      _index = found >= 0 ? found : _index.clamp(0, _notices.length - 1);
    } else {
      _index = _index.clamp(0, _notices.length - 1);
    }
    _syncPlayback();
  }

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  void _advance() {
    if (!mounted || _notices.length < 2) return;
    setState(() => _index = (_index + 1) % _notices.length);
    _syncPlayback(restart: true);
  }

  void _goTo(int index) {
    if (_notices.isEmpty) return;
    _progress.stop();
    _progress.value = 0;
    setState(() => _index = index % _notices.length);
    _syncPlayback();
  }

  void _syncPlayback({bool restart = false}) {
    if (_notices.length < 2 || _hovering || _reading) {
      _progress.stop();
      if (_notices.length < 2) _progress.value = 0;
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

  Future<void> _open(int index) async {
    _reading = true;
    _syncPlayback();
    final viewed = await V3NoticeDialog.showReader(
      context,
      notices: _notices,
      initialIndex: index,
    );
    if (!mounted) return;
    if (viewed != null && _notices.isNotEmpty) {
      _index = viewed.clamp(0, _notices.length - 1);
      _progress.value = 0;
    }
    _reading = false;
    _syncPlayback();
  }

  String _summary(NoticeModel notice) {
    final title = notice.title.trim();
    final body = v3NoticeText(
      notice.content,
    ).replaceAll(RegExp(r'\s+'), ' ').trim();
    if (title.isEmpty) return body;
    if (body.isEmpty || body == title) return title;
    return '$title  ·  $body';
  }

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    final notices = _notices;

    // Loading and empty both render nothing rather than a placeholder: the
    // dashboard has no room to hold a slot open for news that may not come,
    // and an empty ticker reads as a broken one.
    if (notices.isEmpty) return const SizedBox.shrink();

    final safeIndex = _index.clamp(0, notices.length - 1);
    final notice = notices[safeIndex];
    final multiple = notices.length > 1;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: MouseRegion(
        onEnter: (_) => _setHovering(true),
        onExit: (_) => _setHovering(false),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => unawaited(_open(safeIndex)),
            child: Ink(
              padding: const EdgeInsets.fromLTRB(8, 8, 10, 8),
              decoration: BoxDecoration(
                color: p.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: p.line),
              ),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: p.lycheeSoft,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(
                      Icons.campaign_rounded,
                      size: 15,
                      color: p.lycheeInk,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      // Left-aligned and stacked, so the outgoing line does not
                      // drag the incoming one around as it fades.
                      layoutBuilder: (current, previous) => Stack(
                        alignment: Alignment.centerLeft,
                        children: [...previous, ?current],
                      ),
                      child: Text(
                        _summary(notice),
                        key: ValueKey(notice.id),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: p.ink, fontSize: 12.5),
                      ),
                    ),
                  ),
                  // The pager needs room; on a phone the line itself matters
                  // more, and the reader dialog can page anyway.
                  if (multiple && MediaQuery.sizeOf(context).width >= 520) ...[
                    const SizedBox(width: 10),
                    _NavButton(
                      icon: Icons.chevron_left_rounded,
                      tooltip: '上一条公告',
                      onPressed: () => _goTo(safeIndex - 1),
                    ),
                    SizedBox(
                      width: 42,
                      child: Text(
                        '${safeIndex + 1} / ${notices.length}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: p.inkMuted,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    _NavButton(
                      icon: Icons.chevron_right_rounded,
                      tooltip: '下一条公告',
                      onPressed: () => _goTo(safeIndex + 1),
                    ),
                  ],
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Text(
                      '查看',
                      style: TextStyle(
                        // lycheeInk, not lychee: this is 11.5px text on the
                        // card, where the base fill is only a 3:1 graphic.
                        color: p.lycheeInk,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
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

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon),
      iconSize: 15,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints.tightFor(width: 24, height: 24),
      style: IconButton.styleFrom(
        foregroundColor: p.ink,
        backgroundColor: p.surfaceRaised,
        side: BorderSide(color: p.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

/// One notice, read.
///
/// Two callers, one presentation: the ticker's 查看 opens it as a reader that
/// pages through everything loaded, and a must-read notice opens it alone with
/// no way out but the button.
class V3NoticeDialog extends StatefulWidget {
  const V3NoticeDialog.reader({
    super.key,
    required this.notices,
    required this.initialIndex,
  }) : mustRead = false;

  // Not const: the single notice is wrapped into a list at construction.
  V3NoticeDialog.mustRead({super.key, required NoticeModel notice})
    : notices = [notice],
      initialIndex = 0,
      mustRead = true;

  final List<NoticeModel> notices;
  final int initialIndex;
  final bool mustRead;

  /// Paging reader; resolves to the index left on screen, so the ticker can
  /// carry on from wherever the user stopped reading.
  static Future<int?> showReader(
    BuildContext context, {
    required List<NoticeModel> notices,
    required int initialIndex,
  }) => showDialog<int>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.48),
    builder: (_) =>
        V3NoticeDialog.reader(notices: notices, initialIndex: initialIndex),
  );

  /// Must-read notice; only the button closes it.
  static Future<void> showMustRead(BuildContext context, NoticeModel notice) =>
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.black.withValues(alpha: 0.58),
        builder: (_) => V3NoticeDialog.mustRead(notice: notice),
      );

  @override
  State<V3NoticeDialog> createState() => _V3NoticeDialogState();
}

class _V3NoticeDialogState extends State<V3NoticeDialog> {
  late int _index = widget.notices.isEmpty
      ? 0
      : widget.initialIndex.clamp(0, widget.notices.length - 1);

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    if (widget.notices.isEmpty) return const SizedBox.shrink();

    final notice = widget.notices[_index];
    final multiple = widget.notices.length > 1;
    final body = v3NoticeText(notice.content);
    final image = notice.imgUrl?.trim() ?? '';

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        width: 520,
        constraints: const BoxConstraints(maxHeight: 640),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: p.line),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 18, 12, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.mustRead) ...[
                    Container(
                      width: 30,
                      height: 30,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: p.lycheeSoft,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.campaign_rounded,
                        size: 16,
                        color: p.lycheeInk,
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(top: widget.mustRead ? 4 : 2),
                      child: Text(
                        notice.title.trim().isEmpty ? '公告' : notice.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: p.ink,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          height: 1.3,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                  ),
                  if (!widget.mustRead)
                    IconButton(
                      tooltip: '关闭',
                      onPressed: () => Navigator.of(context).pop(_index),
                      icon: const Icon(Icons.close_rounded, size: 20),
                      color: p.inkMuted,
                    ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 0, 22, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notice.dateDisplay,
                      style: TextStyle(
                        color: p.inkMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (image.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.network(
                          image,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          // A notice is text first; an image that will not load
                          // must not leave a hole where the text should be.
                          errorBuilder: (_, _, _) => const SizedBox.shrink(),
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    Text(
                      body.isEmpty ? '（本条公告没有正文）' : body,
                      style: TextStyle(color: p.ink, fontSize: 13, height: 1.7),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 14, 22, 18),
              child: Row(
                children: [
                  if (multiple) ...[
                    _NavButton(
                      icon: Icons.chevron_left_rounded,
                      tooltip: '上一条公告',
                      onPressed: _index > 0
                          ? () => setState(() => _index--)
                          : null,
                    ),
                    SizedBox(
                      width: 46,
                      child: Text(
                        '${_index + 1} / ${widget.notices.length}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: p.inkMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    _NavButton(
                      icon: Icons.chevron_right_rounded,
                      tooltip: '下一条公告',
                      onPressed: _index < widget.notices.length - 1
                          ? () => setState(() => _index++)
                          : null,
                    ),
                  ],
                  const Spacer(),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(_index),
                    style: FilledButton.styleFrom(
                      backgroundColor: p.lychee,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(widget.mustRead ? '我知道了' : '关闭'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shows the must-read notices that have not been dismissed yet.
///
/// The controller has always tracked them; nothing was rendering them, so a
/// panel's `弹窗` tag had no effect. Sits above the workspace and owns no
/// layout — it only schedules dialogs, one at a time, and records each one as
/// seen so it is never shown twice.
class V3NoticeHost extends StatefulWidget {
  const V3NoticeHost({super.key, required this.child});

  final Widget child;

  @override
  State<V3NoticeHost> createState() => _V3NoticeHostState();
}

class _V3NoticeHostState extends State<V3NoticeHost> {
  bool _showing = false;
  bool _scheduled = false;

  /// Ids this host has already put on screen.
  ///
  /// Held for the widget's lifetime rather than per drain: the controller drops
  /// a notice from `pendingNoticePopups` when it is marked seen, but that is the
  /// controller's business and this must not depend on it landing in time —
  /// a second drain that still saw the notice would show it again, forever.
  final Set<int> _shown = <int>{};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Notices arrive after the first frame, and every arrival notifies, so
    // this is where a popup-tagged one first becomes visible.
    _schedule();
  }

  void _schedule() {
    if (_scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (mounted) unawaited(_drain());
    });
  }

  Future<void> _drain() async {
    if (_showing || !mounted) return;
    _showing = true;
    try {
      while (mounted) {
        final pending = AppScope.read(
          context,
        ).pendingNoticePopups.where((n) => !_shown.contains(n.id)).toList();
        if (pending.isEmpty) break;
        final notice = pending.first;
        _shown.add(notice.id);
        await V3NoticeDialog.showMustRead(context, notice);
        if (!mounted) break;
        AppScope.read(context).markNoticePopupSeen(notice.id);
      }
    } finally {
      _showing = false;
    }
    // A notice that landed while a dialog was open was not in the list when
    // the loop last looked, and the check that its arrival triggered bailed
    // out on `_showing`. Look once more.
    if (mounted) _schedule();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
