import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../shared/models/api_models.dart';
import '../theme/v3_palette.dart';
import 'v3_locale_copy.dart';

/// Backend notice titles and bodies are supplied by the server. Only the
/// surrounding application controls are translated here.
String v3NoticeText(String source) => source
    .replaceAll(RegExp(r'<\s*br\s*/?\s*>', caseSensitive: false), '\n')
    .replaceAll(RegExp(r'</\s*(p|div|li|tr|h[1-6])\s*>', caseSensitive: false), '\n')
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

/// The ticker never previews or concatenates the body. Readers access full
/// content (including images) only after opening the notice dialog.
String v3NoticeHeadline(NoticeModel notice) {
  final title = notice.title.trim();
  return title.isEmpty ? '公告' : title;
}

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
      context, notices: _notices, initialIndex: index);
    if (!mounted) return;
    if (viewed != null && _notices.isNotEmpty) {
      _index = viewed.clamp(0, _notices.length - 1);
      _progress.value = 0;
    }
    _reading = false;
    _syncPlayback();
  }

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    final notices = _notices;
    if (notices.isEmpty) return const SizedBox.shrink();
    final safeIndex = _index.clamp(0, notices.length - 1);
    final notice = notices[safeIndex];
    final multiple = notices.length > 1;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: MouseRegion(
        onEnter: (_) => _setHovering(true),
        onExit: (_) => _setHovering(false),
        child: Material(color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => unawaited(_open(safeIndex)),
            child: Ink(
              padding: const EdgeInsets.fromLTRB(8, 8, 10, 8),
              decoration: BoxDecoration(color: p.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: p.line)),
              child: Row(children: [
                Container(width: 28, height: 28, alignment: Alignment.center,
                  decoration: BoxDecoration(color: p.lycheeSoft,
                    borderRadius: BorderRadius.circular(9)),
                  child: Icon(Icons.campaign_rounded, size: 15,
                    color: p.lycheeInk)),
                const SizedBox(width: 10),
                Expanded(child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  layoutBuilder: (current, previous) => Stack(
                    alignment: Alignment.centerLeft,
                    children: [...previous, ?current]),
                  child: Text(v3NoticeHeadline(notice), key: ValueKey(notice.id),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: p.ink, fontSize: 12.5)))),
                if (multiple && MediaQuery.sizeOf(context).width >= 520) ...[
                  const SizedBox(width: 10),
                  _NavButton(icon: Icons.chevron_left_rounded,
                    tooltip: v3Copy(context, zh: '上一条公告',
                      en: 'Previous notice', tw: '上一則公告'),
                    onPressed: () => _goTo(safeIndex - 1)),
                  SizedBox(width: 42, child: Text(
                    '${safeIndex + 1} / ${notices.length}',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: p.inkMuted, fontSize: 10.5,
                      fontWeight: FontWeight.w600))),
                  _NavButton(icon: Icons.chevron_right_rounded,
                    tooltip: v3Copy(context, zh: '下一条公告',
                      en: 'Next notice', tw: '下一則公告'),
                    onPressed: () => _goTo(safeIndex + 1)),
                ],
                const SizedBox(width: 8),
                Padding(padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Text(v3Copy(context, zh: '查看', en: 'View', tw: '查看'),
                    style: TextStyle(color: p.lycheeInk, fontSize: 11.5,
                      fontWeight: FontWeight.w700))),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({required this.icon, required this.tooltip,
    required this.onPressed});
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return IconButton(
      tooltip: tooltip, onPressed: onPressed, icon: Icon(icon),
      iconSize: 15, padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints.tightFor(width: 24, height: 24),
      style: IconButton.styleFrom(foregroundColor: p.ink,
        backgroundColor: p.surfaceRaised, side: BorderSide(color: p.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))));
  }
}

class V3NoticeDialog extends StatefulWidget {
  const V3NoticeDialog.reader({super.key, required this.notices,
    required this.initialIndex}) : mustRead = false;

  V3NoticeDialog.mustRead({super.key, required NoticeModel notice})
      : notices = [notice], initialIndex = 0, mustRead = true;

  final List<NoticeModel> notices;
  final int initialIndex;
  final bool mustRead;

  static Future<int?> showReader(BuildContext context, {
    required List<NoticeModel> notices,
    required int initialIndex,
  }) => showDialog<int>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: .48),
    builder: (_) => V3NoticeDialog.reader(
      notices: notices, initialIndex: initialIndex));

  static Future<void> showMustRead(BuildContext context, NoticeModel notice) =>
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.black.withValues(alpha: .58),
        builder: (_) => V3NoticeDialog.mustRead(notice: notice));

  @override
  State<V3NoticeDialog> createState() => _V3NoticeDialogState();
}

class _V3NoticeDialogState extends State<V3NoticeDialog> {
  late int _index = widget.notices.isEmpty ? 0
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
        width: 520, constraints: const BoxConstraints(maxHeight: 640),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(color: p.surface,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: p.line)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(padding: const EdgeInsets.fromLTRB(22, 18, 12, 10),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.mustRead) ...[
                  Container(width: 30, height: 30, alignment: Alignment.center,
                    decoration: BoxDecoration(color: p.lycheeSoft,
                      borderRadius: BorderRadius.circular(10)),
                    child: Icon(Icons.campaign_rounded, size: 16,
                      color: p.lycheeInk)),
                  const SizedBox(width: 12),
                ],
                Expanded(child: Padding(
                  padding: EdgeInsets.only(top: widget.mustRead ? 4 : 2),
                  child: Text(notice.title.trim().isEmpty
                    ? v3Copy(context, zh: '公告', en: 'Notice', tw: '公告')
                    : notice.title,
                    maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: p.ink, fontSize: 17,
                      fontWeight: FontWeight.w800, height: 1.3,
                      letterSpacing: -.2)))),
                if (!widget.mustRead) IconButton(
                  tooltip: v3Copy(context, zh: '关闭', en: 'Close', tw: '關閉'),
                  onPressed: () => Navigator.of(context).pop(_index),
                  icon: const Icon(Icons.close_rounded, size: 20),
                  color: p.inkMuted),
              ])),
          Flexible(child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 4),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(notice.dateDisplay, style: TextStyle(color: p.inkMuted,
                  fontSize: 11, fontWeight: FontWeight.w600)),
                if (image.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  ClipRRect(borderRadius: BorderRadius.circular(14),
                    child: Image.network(image, width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const SizedBox.shrink())),
                ],
                const SizedBox(height: 14),
                Text(body.isEmpty ? v3Copy(context,
                  zh: '（本条公告没有正文）',
                  en: 'This notice has no body.',
                  tw: '（本則公告沒有正文）') : body,
                  style: TextStyle(color: p.ink, fontSize: 13, height: 1.7)),
              ]))),
          Padding(padding: const EdgeInsets.fromLTRB(22, 14, 22, 18),
            child: Row(children: [
              if (multiple) ...[
                _NavButton(icon: Icons.chevron_left_rounded,
                  tooltip: v3Copy(context, zh: '上一条公告',
                    en: 'Previous notice', tw: '上一則公告'),
                  onPressed: _index > 0
                    ? () => setState(() => _index--) : null),
                SizedBox(width: 46, child: Text(
                  '${_index + 1} / ${widget.notices.length}',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: p.inkMuted, fontSize: 11,
                    fontWeight: FontWeight.w600))),
                _NavButton(icon: Icons.chevron_right_rounded,
                  tooltip: v3Copy(context, zh: '下一条公告',
                    en: 'Next notice', tw: '下一則公告'),
                  onPressed: _index < widget.notices.length - 1
                    ? () => setState(() => _index++) : null),
              ],
              const Spacer(),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(_index),
                style: FilledButton.styleFrom(
                  backgroundColor: p.lychee,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14))),
                child: Text(widget.mustRead
                  ? v3Copy(context, zh: '我知道了',
                      en: 'Understood', tw: '我知道了')
                  : v3Copy(context, zh: '关闭', en: 'Close', tw: '關閉'))),
            ])),
        ]),
      ),
    );
  }
}

class V3NoticeHost extends StatefulWidget {
  const V3NoticeHost({super.key, required this.child});
  final Widget child;

  @override
  State<V3NoticeHost> createState() => _V3NoticeHostState();
}

class _V3NoticeHostState extends State<V3NoticeHost> {
  bool _showing = false;
  bool _scheduled = false;
  final Set<int> _shown = <int>{};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
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
        final pending = AppScope.read(context).pendingNoticePopups
          .where((n) => !_shown.contains(n.id)).toList();
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
    if (mounted) _schedule();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
