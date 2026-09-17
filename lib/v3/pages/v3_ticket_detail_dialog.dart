import 'dart:async';

import 'package:flutter/material.dart';

import '../../shared/models/api_models.dart';
import '../../shared/services/panel_api.dart';
import '../theme/v3_palette.dart';

/// The dialog keeps its outer bounds and title position while an async detail
/// request replaces the contents. The list's TicketModel supplies the title on
/// the first frame instead of showing a tiny spinner-only dialog first.
class V3TicketDetailDialog extends StatefulWidget {
  const V3TicketDetailDialog({
    super.key,
    required this.summary,
    required this.api,
    required this.onChanged,
  });

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
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _reply.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    // Keep the current messages visible during reply/close refreshes. Only
    // initial loading/retry without any content uses a placeholder.
    if (_ticket == null && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final ticket = await widget.api.getTicketDetail(widget.summary.id);
      if (!mounted) return;
      setState(() {
        _ticket = ticket;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _ticketError(error);
      });
    }
  }

  Future<void> _send() async {
    final text = _reply.text.trim();
    if (text.isEmpty || _sending || _closing) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await widget.api.replyTicket(
        ticketId: widget.summary.id,
        message: text,
      );
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
    setState(() {
      _closing = true;
      _error = null;
    });
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
            MediaQuery.viewInsetsOf(context).bottom -
            44.0)
        .clamp(260.0, 560.0);
    final ticket = _ticket ?? widget.summary;
    final open = ticket.isOpen;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(22),
      child: Container(
        key: const ValueKey('v3-ticket-dialog-frame'),
        width: 680,
        height: height,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Column(
          children: [
            // A permanent header: its top coordinate, height, and action slot
            // stay unchanged when the network request resolves.
            SizedBox(
              key: const ValueKey('v3-ticket-dialog-header'),
              height: 72,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'TICKET #${widget.summary.id}',
                          style: TextStyle(
                            color: p.lycheeInk,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          ticket.subject.trim().isEmpty
                              ? '未命名工单'
                              : ticket.subject,
                          key: const ValueKey('v3-ticket-dialog-title'),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.headlineLarge,
                        ),
                      ],
                    ),
                  ),
                  // Reserve the action's width even before the status loads.
                  SizedBox(
                    width: 94,
                    child: open
                        ? OutlinedButton(
                            onPressed: _loading || _closing || _sending
                                ? null
                                : _closeTicket,
                            child: Text(_closing ? '关闭中…' : '关闭工单'),
                          )
                        : null,
                  ),
                  IconButton(
                    tooltip: '关闭',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Expanded(
              child: Container(
                key: const ValueKey('v3-ticket-dialog-messages'),
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: p.surfaceRaised,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: _ticket == null && _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _ticket == null
                        ? _TicketLoadError(error: _error, retry: _load)
                        : _ticket!.messages.isEmpty
                            ? Center(
                                child: Text(
                                  '暂无消息',
                                  style: TextStyle(
                                    color: p.inkMuted,
                                    fontSize: 11,
                                  ),
                                ),
                              )
                            : ListView.separated(
                                itemCount: _ticket!.messages.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(height: 12),
                                itemBuilder: (context, index) {
                                  final message = _ticket!.messages[index];
                                  return Align(
                                    alignment: message.isAdmin
                                        ? Alignment.centerLeft
                                        : Alignment.centerRight,
                                    child: Container(
                                      constraints: const BoxConstraints(
                                        maxWidth: 470,
                                      ),
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: message.isAdmin
                                            ? p.surface
                                            : p.lycheeSoft,
                                        borderRadius: BorderRadius.circular(16),
                                        border: message.isAdmin
                                            ? Border.all(color: p.line)
                                            : null,
                                      ),
                                      child: Column(
                                        crossAxisAlignment: message.isAdmin
                                            ? CrossAxisAlignment.start
                                            : CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            message.message,
                                            style: TextStyle(
                                              color: p.ink,
                                              fontSize: 11,
                                              height: 1.45,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            '${message.isAdmin ? '客服' : '我'} · ${message.timeDisplay}',
                                            style: TextStyle(
                                              color: p.inkMuted,
                                              fontSize: 10,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
              ),
            ),
            if (_error != null && _ticket != null)
              SizedBox(
                height: 26,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _error!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: p.dangerInk, fontSize: 10),
                  ),
                ),
              ),
            if (open) ...[
              const SizedBox(height: 14),
              SizedBox(
                height: 48,
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _reply,
                        enabled: _ticket != null && !_closing,
                        maxLines: 1,
                        decoration:
                            const InputDecoration(hintText: '输入回复…'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      height: 48,
                      child: FilledButton.icon(
                        onPressed: _ticket == null || _sending || _closing
                            ? null
                            : _send,
                        icon: const Icon(Icons.send_rounded, size: 17),
                        label: Text(_sending ? '发送中' : '发送'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TicketLoadError extends StatelessWidget {
  const _TicketLoadError({required this.error, required this.retry});

  final String? error;
  final VoidCallback retry;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, color: p.dangerInk),
            const SizedBox(height: 10),
            const Text('无法打开工单'),
            const SizedBox(height: 8),
            if (error != null)
              Text(error!, textAlign: TextAlign.center,
                style: TextStyle(color: p.dangerInk, fontSize: 11)),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: retry, child: const Text('重试')),
          ],
        ),
      ),
    );
  }
}

String _ticketError(Object error) => error
    .toString()
    .replaceFirst('ApiException: ', '')
    .replaceFirst('Exception: ', '');
