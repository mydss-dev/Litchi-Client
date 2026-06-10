import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_text_styles.dart';
import 'app_toast.dart';

/// Scrollable log panel fed by a [Stream<String>].
///
/// Keeps the last [maxLines] entries. Auto-follows the tail unless the user
/// scrolls up. Toolbar buttons: follow-toggle, copy-all, clear.
class LogPanel extends StatefulWidget {
  const LogPanel({
    super.key,
    required this.logStream,
    this.maxLines = 300,
    this.height = 220,
  });

  final Stream<String> logStream;
  final int maxLines;
  final double height;

  @override
  State<LogPanel> createState() => _LogPanelState();
}

class _LogPanelState extends State<LogPanel> {
  final _lines = <String>[];
  StreamSubscription<String>? _sub;
  final _scrollCtrl = ScrollController();
  bool _follow = true;

  @override
  void initState() {
    super.initState();
    _sub = widget.logStream.listen(_onLine);
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(LogPanel old) {
    super.didUpdateWidget(old);
    if (old.logStream != widget.logStream) {
      _sub?.cancel();
      _sub = widget.logStream.listen(_onLine);
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onLine(String line) {
    setState(() {
      _lines.add(line);
      if (_lines.length > widget.maxLines) {
        _lines.removeAt(0);
      }
    });
    if (_follow) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }
  }

  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;
    final atBottom = _scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 8;
    if (_follow != atBottom) setState(() => _follow = atBottom);
  }

  void _scrollToBottom() {
    if (!_scrollCtrl.hasClients) return;
    _scrollCtrl.animateTo(
      _scrollCtrl.position.maxScrollExtent,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
    );
  }

  void _clear() => setState(() => _lines.clear());

  Future<void> _copyAll(BuildContext ctx) async {
    await Clipboard.setData(ClipboardData(text: _lines.join('\n')));
    if (ctx.mounted) {
      AppToast.show(ctx, '日志已复制到剪贴板', type: AppToastType.success);
    }
  }

  // Color-code a log line based on its severity keyword.
  Color _lineColor(AppColors c, String line) {
    final lower = line.toLowerCase();
    if (lower.contains('fatal') || lower.contains('error')) return c.danger;
    if (lower.contains('warn')) return c.warning;
    if (lower.contains('──')) return c.textMuted;
    return c.textSecondary;
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── toolbar ──────────────────────────────────────────────────────────
        Row(
          children: [
            Text('核心日志',
                style: AppTextStyles.sectionTitle.copyWith(color: c.textPrimary)),
            const Spacer(),
            _ToolbarBtn(
              icon: _follow ? LucideIcons.arrowDownToLine : LucideIcons.arrowDownToLine,
              label: _follow ? '跟随' : '跟随',
              active: _follow,
              onTap: () {
                setState(() => _follow = !_follow);
                if (_follow) _scrollToBottom();
              },
              c: c,
            ),
            const SizedBox(width: 6),
            _ToolbarBtn(
              icon: LucideIcons.copy,
              label: '复制',
              onTap: () => _copyAll(context),
              c: c,
            ),
            const SizedBox(width: 6),
            _ToolbarBtn(
              icon: LucideIcons.trash2,
              label: '清空',
              onTap: _clear,
              c: c,
            ),
          ],
        ),
        const SizedBox(height: 8),
        // ── log body ──────────────────────────────────────────────────────────
        Container(
          height: widget.height,
          decoration: BoxDecoration(
            color: c.surfaceMuted,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: c.softBorder),
          ),
          child: _lines.isEmpty
              ? Center(
                  child: Text(
                    '暂无日志，连接后将显示核心输出',
                    style: AppTextStyles.caption.copyWith(color: c.textMuted),
                  ),
                )
              : ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemCount: _lines.length,
                  itemBuilder: (_, i) => Text(
                    _lines[i],
                    style: TextStyle(
                      fontFamily: 'Consolas',
                      fontFamilyFallback: const ['Courier New', 'monospace'],
                      fontSize: 11,
                      height: 1.6,
                      color: _lineColor(c, _lines[i]),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

class _ToolbarBtn extends StatefulWidget {
  const _ToolbarBtn({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.c,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final AppColors c;
  final bool active;

  @override
  State<_ToolbarBtn> createState() => _ToolbarBtnState();
}

class _ToolbarBtnState extends State<_ToolbarBtn> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final color = widget.active
        ? c.primary
        : _hover
            ? c.textPrimary
            : c.textMuted;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _hover ? c.surfaceMuted : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.xs),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 13, color: color),
              const SizedBox(width: 4),
              Text(widget.label,
                  style: AppTextStyles.caption.copyWith(color: color)),
            ],
          ),
        ),
      ),
    );
  }
}
