import 'dart:async';

import 'package:flutter/material.dart';

import '../../shared/models/api_models.dart';
import '../../shared/services/panel_api.dart';
import '../theme/v3_palette.dart';
import '../ui/v3_locale_copy.dart';

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
      setState(() { _loading = false; _error = _ticketError(error); });
    }
  }

  Future<void> _send() async {
    final text = _reply.text.trim();
    if (text.isEmpty || _sending || _closing) return;
    setState(() { _sending = true; _error = null; });
    try {
      await widget.api.replyTicket(ticketId: widget.summary.id, message: text);
      _reply.clear();
      await _load();
      await widget.onChanged();
    } catch (error) {
      if (mounted) setState(() => _error = _ticketError(error));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _closeTicket() async {
    if (_closing || _sending) return;
    setState(() { _closing = true; _error = null; });
    try {
      await widget.api.closeTicket(widget.summary.id);
      await _load();
      await widget.onChanged();
    } catch (error) {
      if (mounted) setState(() => _error = _ticketError(error));
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
                    style: TextStyle(color: p.lycheeInk, fontSize: 10,
                      fontWeight: FontWeight.w900, letterSpacing: 1.5)),
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
                  child: Text(_closing
                    ? v3Copy(context, zh: '关闭中…',
                        en: 'Closing…', tw: '關閉中…')
                    : v3Copy(context, zh: '关闭工单',
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
              ? const Center(child: CircularProgressIndicator())
              : _ticket == null
                ? _TicketLoadError(error: _error, retry: _load)
                : _ticket!.messages.isEmpty
                  ? Center(child: Text(v3Copy(context, zh: '暂无消息',
                      en: 'No messages yet', tw: '暫無訊息'),
                    style: TextStyle(color: p.inkMuted, fontSize: 11)))
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
                              color: message.isAdmin ? p.surface : p.lycheeSoft,
                              borderRadius: BorderRadius.circular(V3Radius.card),
                              border: message.isAdmin
                                ? Border.all(color: p.line) : null),
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
                                  style: TextStyle(color: p.inkMuted, fontSize: 10)),
                              ])));
                      }))),
          if (_error != null && _ticket != null)
            SizedBox(height: 26,
              child: Align(alignment: Alignment.centerLeft,
                child: Text(_error!, maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: p.dangerInk, fontSize: 10)))),
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
                icon: const Icon(Icons.send_rounded, size: 17),
                label: Text(_sending
                  ? v3Copy(context, zh: '发送中', en: 'Sending', tw: '傳送中')
                  : v3Copy(context, zh: '发送', en: 'Send', tw: '傳送')))),
            ])),
          ],
        ])));
  }
}

class _TicketLoadError extends StatelessWidget {
  const _TicketLoadError({required this.error, required this.retry});
  final String? error;
  final VoidCallback retry;
  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return Center(child: SingleChildScrollView(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.error_outline_rounded, color: p.dangerInk),
        const SizedBox(height: 10),
        Text(v3Copy(context, zh: '无法打开工单',
          en: 'Cannot open ticket', tw: '無法開啟工單')),
        const SizedBox(height: 8),
        if (error != null)
          Text(error!, textAlign: TextAlign.center,
            style: TextStyle(color: p.dangerInk, fontSize: 11)),
        const SizedBox(height: 12),
        OutlinedButton(onPressed: retry, child: Text(v3Copy(context,
          zh: '重试', en: 'Retry', tw: '重試'))),
      ])));
  }
}

String _ticketError(Object error) => error.toString()
    .replaceFirst('ApiException: ', '')
    .replaceFirst('Exception: ', '');