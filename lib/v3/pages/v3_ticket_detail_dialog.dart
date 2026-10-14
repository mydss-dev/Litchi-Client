import 'dart:async';

import 'package:flutter/material.dart';

import '../../shared/models/api_models.dart';
import '../../shared/services/panel_api.dart';
import '../theme/v3_palette.dart';
import '../ui/v3_empty_state.dart';
import '../ui/v3_locale_copy.dart';
import '../ui/v3_sheet.dart';
import '../ui/v3_components.dart';
import '../ui/v3_toast.dart';

/// Stable outer bounds and title position while detail requests complete.
class V3TicketDetailDialog extends StatefulWidget {
  const V3TicketDetailDialog({super.key, required this.summary,
    required this.api, required this.onChanged});
  final TicketModel summary;
  final PanelApi api;
  final Future<void> Function() onChanged;
  @override
  State<V3TicketDetailDialog> createState() => _V3TicketDetailDialogState();
}

class _V3TicketDetailDialogState extends State<V3TicketDetailDialog> {
  final _reply = TextEditingController();
  TicketModel? _ticket;
  bool _loading = true;
  bool _sending = false;
  bool _closing = false;
  String? _error;

  @override
  void initState() { super.initState(); unawaited(_load()); }
  @override
  void dispose() { _reply.dispose(); super.dispose(); }

  Future<void> _load() async {
    if (_ticket == null && mounted) {
      setState(() { _loading = true; _error = null; });
    }
    try {
      final ticket = await widget.api.getTicketDetail(widget.summary.id);
      if (!mounted) return;
      setState(() { _ticket = ticket; _loading = false; _error = null; });
    } catch (error) {
      if (!mounted) return;
      setState(() { _loading = false; _error = v3ErrorMessage(error); });
    }
  }

  Future<void> _send() async {
    final text = _reply.text.trim();
    if (text.isEmpty || _sending || _closing) return;
    // Captured before the await so the toast outlives the dialog route.
    final overlay = Overlay.of(context, rootOverlay: true);
    setState(() => _sending = true);
    try {
      await widget.api.replyTicket(ticketId: widget.summary.id, message: text);
      _reply.clear();
      await _load();
      await widget.onChanged();
    } catch (error) {
      // Async result errors are transient toasts; only field validation stays
      // inline (M3). _error is reserved for the initial load.
      V3Toast.showInOverlay(overlay, v3ErrorMessage(error),
        type: V3ToastType.error);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _closeTicket() async {
    if (_closing || _sending) return;
    // Closing ends the conversation: the reply field disappears for the
    // ticket and a follow-up needs a new one. Confirm before the call.
    final confirmed = await showV3ConfirmDialog(context,
      title: v3Copy(context, zh: '关闭这个工单？',
        en: 'Close this ticket?', tw: '關閉這個工單？'),
      body: v3Copy(context,
        zh: '关闭后将无法继续回复；如仍有问题，需要重新创建工单。',
        en: 'A closed ticket cannot be replied to. Open a new one if the issue comes back.',
        tw: '關閉後將無法繼續回覆；如仍有問題，需要重新建立工單。'),
      confirmLabel: v3Copy(context, zh: '关闭工单',
        en: 'Close ticket', tw: '關閉工單'),
      destructive: true);
    if (!confirmed || !mounted) return;
    final overlay = Overlay.of(context, rootOverlay: true);
    setState(() => _closing = true);
    try {
      await widget.api.closeTicket(widget.summary.id);
      await _load();
      await widget.onChanged();
    } catch (error) {
      V3Toast.showInOverlay(overlay, v3ErrorMessage(error),
        type: V3ToastType.error);
    } finally {
      if (mounted) setState(() => _closing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    final height = (MediaQuery.sizeOf(context).height -
      MediaQuery.paddingOf(context).vertical -
      MediaQuery.viewInsetsOf(context).bottom - 44.0).clamp(260.0, 560.0);
    final ticket = _ticket ?? widget.summary;
    final open = ticket.isOpen;
    return Dialog(backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(22),
      child: Container(key: const ValueKey('v3-ticket-dialog-frame'),
        width: 680, height: height, padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: p.surface,
          borderRadius: BorderRadius.circular(V3Radius.panel)),
        child: Column(children: [
          SizedBox(key: const ValueKey('v3-ticket-dialog-header'), height: 72,
            child: Row(children: [
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(v3Copy(context,
                    zh: '工单 #${widget.summary.id}',
                    en: 'TICKET #${widget.summary.id}',
                    tw: '工單 #${widget.summary.id}'),
                    style: TextStyle(color: p.lycheeInk, fontSize: 11,
                      fontWeight: FontWeight.w900, letterSpacing: 1.5,
                      fontFeatures: const [FontFeature.tabularFigures()])),
                  const SizedBox(height: 5),
                  Text(ticket.subject.trim().isEmpty
                      ? v3Copy(context, zh: '未命名工单',
                          en: 'Untitled ticket', tw: '未命名工單')
                      : ticket.subject,
                    key: const ValueKey('v3-ticket-dialog-title'),
                    maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.headlineLarge),
                ])),
              SizedBox(width: 94,
                child: open ? OutlinedButton(
                  onPressed: _loading || _closing || _sending ? null : _closeTicket,
                  // The fixed 94px slot absorbs the spinner: no width jump.
                  child: _closing
                    ? SizedBox(width: 14, height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2,
                          color: p.lychee))
                    : Text(v3Copy(context, zh: '关闭工单',
                        en: 'Close ticket', tw: '關閉工單'))) : null),
              IconButton(tooltip: v3Copy(context, zh: '关闭',
                  en: 'Close', tw: '關閉'),
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded)),
            ])),
          const SizedBox(height: 18),
          Expanded(child: Container(
            key: const ValueKey('v3-ticket-dialog-messages'),
            width: double.infinity, padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: p.surfaceRaised,
              borderRadius: BorderRadius.circular(V3Radius.card)),
            child: _ticket == null && _loading
              ? const Padding(padding: EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min, children: [
                    V3SkeletonBlock(width: 160, height: 12),
                    SizedBox(height: 10),
                    V3SkeletonBlock(width: 260, height: 12),
                    SizedBox(height: 10),
                    V3SkeletonBlock(width: 200, height: 12),
                  ]))
              : _ticket == null
                ? Center(child: SingleChildScrollView(
                    child: V3EmptyState(icon: Icons.error_outline_rounded,
                      title: v3Copy(context, zh: '无法打开工单',
                        en: 'Cannot open ticket', tw: '無法開啟工單'),
                      subtitle: _error ??
                        v3Copy(context, zh: '请求未能完成，请重试。',
                          en: 'The request did not complete. Try again.',
                          tw: '請求未能完成，請重試。'),
                      actionLabel: v3Copy(context, zh: '重试',
                        en: 'Retry', tw: '重試'),
                      onAction: _load)))
                : _ticket!.messages.isEmpty
                  ? V3EmptyState(icon: Icons.chat_bubble_outline_rounded,
                      title: v3Copy(context, zh: '暂无消息',
                        en: 'No messages yet', tw: '暫無訊息'),
                      subtitle: v3Copy(context,
                        zh: '客服回复后会出现在这里。',
                        en: 'Replies from support appear here.',
                        tw: '客服回覆後會出現在這裡。'))
                  : ListView.separated(
                      itemCount: _ticket!.messages.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final message = _ticket!.messages[index];
                        return Align(
                          alignment: message.isAdmin
                            ? Alignment.centerLeft : Alignment.centerRight,
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 470),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: message.isAdmin
                                ? p.surfaceRaised : p.lycheeSoft,
                              borderRadius:
                                BorderRadius.circular(V3Radius.card)),
                            child: Column(
                              crossAxisAlignment: message.isAdmin
                                ? CrossAxisAlignment.start : CrossAxisAlignment.end,
                              children: [
                                Text(message.message, style: TextStyle(
                                  color: p.ink, fontSize: 11, height: 1.45)),
                                const SizedBox(height: 6),
                                Text('${message.isAdmin
                                    ? v3Copy(context, zh: '客服',
                                        en: 'Support', tw: '客服')
                                    : v3Copy(context, zh: '我',
                                        en: 'Me', tw: '我')} · ${message.timeDisplay}',
                                  style: TextStyle(color: p.inkMuted, fontSize: 11,
                                    fontFeatures: const [FontFeature.tabularFigures()])),
                              ])));
                      }))),
          if (open) ...[
            const SizedBox(height: 14),
            SizedBox(height: 48, child: Row(children: [
              Expanded(child: TextField(controller: _reply,
                enabled: _ticket != null && !_closing, maxLines: 1,
                decoration: InputDecoration(hintText: v3Copy(context,
                  zh: '输入回复…', en: 'Write a reply…', tw: '輸入回覆…')))),
              const SizedBox(width: 10),
              SizedBox(height: 48, child: FilledButton.icon(
                onPressed: _ticket == null || _sending || _closing ? null : _send,
                // The spinner rides the 17px icon slot: no geometry shift.
                icon: _sending
                  ? SizedBox(width: 17, height: 17,
                      child: CircularProgressIndicator(strokeWidth: 2,
                        color: p.onLychee))
                  : const Icon(Icons.send_rounded, size: 17),
                label: Text(v3Copy(context, zh: '发送', en: 'Send', tw: '傳送')))),
            ])),
          ],
        ])));
  }
}

