import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../shared/models/api_models.dart';
import '../../shared/services/panel_api.dart';
import '../theme/v3_palette.dart';

class V3TicketsPage extends StatefulWidget {
  const V3TicketsPage({super.key});

  @override
  State<V3TicketsPage> createState() => _V3TicketsPageState();
}

class _V3TicketsPageState extends State<V3TicketsPage> {
  bool _initialized = false;
  bool _loading = true;
  String? _error;
  List<TicketModel> _tickets = const [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    unawaited(_load());
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final tickets = await AppScope.read(context).api.getTickets();
      if (!mounted) return;
      setState(() {
        _tickets = tickets;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _message(error);
      });
    }
  }

  Future<void> _openTicket(TicketModel ticket) async {
    final controller = AppScope.read(context);
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (_) => _TicketDetailDialog(
        ticketId: ticket.id,
        api: controller.api,
        onChanged: _load,
      ),
    );
  }

  Future<void> _newTicket() async {
    final controller = AppScope.read(context);
    final created = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (_) => _NewTicketDialog(api: controller.api),
    );
    if (created == true && mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    final openCount = _tickets.where((ticket) => ticket.isOpen).length;
    final closedCount = _tickets.length - openCount;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 26, 24, 36),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '帮助与支持',
                          style: TextStyle(
                            color: p.lycheeInk,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2.2,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          '支持工单',
                          style: Theme.of(context).textTheme.displayMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '问题、回复和处理状态都集中在同一个支持收件箱。',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  if (!compact)
                    FilledButton.icon(
                      onPressed: _newTicket,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('新建工单'),
                    ),
                  IconButton(
                    tooltip: '刷新工单',
                    onPressed: _loading ? null : _load,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
              if (compact) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _newTicket,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('新建工单'),
                  ),
                ),
              ],
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: _TicketMetric(
                      label: '全部工单',
                      value: '${_tickets.length}',
                      accent: p.lychee,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _TicketMetric(
                      label: '处理中',
                      value: '$openCount',
                      accent: p.warning,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _TicketMetric(
                      label: '已关闭',
                      value: '$closedCount',
                      accent: p.success,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: p.surface,
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(color: p.line),
                ),
                child: _loading
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(40),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    : _error != null
                    ? _TicketEmptyState(
                        icon: Icons.error_outline_rounded,
                        title: '工单加载失败',
                        subtitle: _error!,
                        actionLabel: '重试',
                        onAction: _load,
                      )
                    : _tickets.isEmpty
                    ? _TicketEmptyState(
                        icon: Icons.support_agent_rounded,
                        title: '还没有工单',
                        subtitle: '遇到问题时，可以直接从这里联系支持。',
                        actionLabel: '创建第一张工单',
                        onAction: _newTicket,
                      )
                    : Column(
                        children: [
                          for (var i = 0; i < _tickets.length; i++) ...[
                            _TicketRow(
                              ticket: _tickets[i],
                              onTap: () => _openTicket(_tickets[i]),
                            ),
                            if (i != _tickets.length - 1)
                              Divider(color: p.line, height: 1),
                          ],
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TicketMetric extends StatelessWidget {
  const _TicketMetric({
    required this.label,
    required this.value,
    required this.accent,
  });

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return Container(
      height: 96,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: p.surfaceRaised,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 44,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: p.inkMuted, fontSize: 9)),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  color: p.ink,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TicketRow extends StatelessWidget {
  const _TicketRow({required this.ticket, required this.onTap});

  final TicketModel ticket;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    // Ink variants: both drive small status labels, and the tints they paint at
    // 10% alpha only gain depth from the darker base.
    final statusColor = ticket.isOpen ? p.warningInk : p.successInk;
    final levelColor = switch (ticket.level) {
      2 => p.dangerInk,
      1 => p.warningInk,
      _ => p.aqua,
    };
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 15),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(Icons.forum_rounded, color: statusColor, size: 20),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ticket.subject.trim().isEmpty ? '未命名工单' : ticket.subject,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: p.ink,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '#${ticket.id} · ${ticket.dateDisplay}',
                    style: TextStyle(color: p.inkMuted, fontSize: 9),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
              decoration: BoxDecoration(
                color: levelColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                ticket.levelLabel,
                style: TextStyle(
                  color: levelColor,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 9),
            Text(
              ticket.statusLabel,
              style: TextStyle(
                color: statusColor,
                fontSize: 9,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 5),
            Icon(Icons.chevron_right_rounded, color: p.inkMuted, size: 18),
          ],
        ),
      ),
    );
  }
}

class _NewTicketDialog extends StatefulWidget {
  const _NewTicketDialog({required this.api});

  final PanelApi api;

  @override
  State<_NewTicketDialog> createState() => _NewTicketDialogState();
}

class _NewTicketDialogState extends State<_NewTicketDialog> {
  final _subject = TextEditingController();
  final _messageController = TextEditingController();
  int _level = 1;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _subject.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final subject = _subject.text.trim();
    final message = _messageController.text.trim();
    if (subject.isEmpty || message.isEmpty) {
      setState(() => _error = '请填写主题和问题描述');
      return;
    }
    if (_submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await widget.api.createTicket(
        subject: subject,
        level: _level,
        message: message,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _error = _message(error);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return AlertDialog(
      backgroundColor: p.surface,
      title: const Text('新建工单'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _subject,
                decoration: const InputDecoration(labelText: '主题'),
              ),
              const SizedBox(height: 16),
              Text('优先级', style: TextStyle(color: p.inkMuted, fontSize: 10)),
              const SizedBox(height: 8),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 0, label: Text('低')),
                  ButtonSegment(value: 1, label: Text('中等')),
                  ButtonSegment(value: 2, label: Text('紧急')),
                ],
                selected: {_level},
                showSelectedIcon: false,
                onSelectionChanged: (value) =>
                    setState(() => _level = value.first),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _messageController,
                minLines: 5,
                maxLines: 8,
                decoration: const InputDecoration(
                  labelText: '问题描述',
                  alignLabelWithHint: true,
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: TextStyle(color: p.dangerInk, fontSize: 11)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting
              ? null
              : () => Navigator.of(context).pop(false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: Text(_submitting ? '提交中…' : '提交工单'),
        ),
      ],
    );
  }
}

class _TicketDetailDialog extends StatefulWidget {
  const _TicketDetailDialog({
    required this.ticketId,
    required this.api,
    required this.onChanged,
  });

  final int ticketId;
  final PanelApi api;
  final Future<void> Function() onChanged;

  @override
  State<_TicketDetailDialog> createState() => _TicketDetailDialogState();
}

class _TicketDetailDialogState extends State<_TicketDetailDialog> {
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
    try {
      final ticket = await widget.api.getTicketDetail(widget.ticketId);
      if (!mounted) return;
      setState(() {
        _ticket = ticket;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = _message(error);
        });
      }
    }
  }

  Future<void> _send() async {
    final text = _reply.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await widget.api.replyTicket(ticketId: widget.ticketId, message: text);
      _reply.clear();
      await _load();
      await widget.onChanged();
    } catch (error) {
      if (mounted) setState(() => _error = _message(error));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _closeTicket() async {
    if (_closing) return;
    setState(() {
      _closing = true;
      _error = null;
    });
    try {
      await widget.api.closeTicket(widget.ticketId);
      await _load();
      await widget.onChanged();
    } catch (error) {
      if (mounted) setState(() => _error = _message(error));
    } finally {
      if (mounted) setState(() => _closing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(22),
      child: Container(
        width: 680,
        constraints: const BoxConstraints(maxHeight: 720),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(30),
        ),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null && _ticket == null
            ? _TicketEmptyState(
                icon: Icons.error_outline_rounded,
                title: '无法打开工单',
                subtitle: _error!,
                actionLabel: '重试',
                onAction: _load,
              )
            : _detail(context),
      ),
    );
  }

  Widget _detail(BuildContext context) {
    final p = V3Palette.of(context);
    final ticket = _ticket!;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TICKET #${ticket.id}',
                    style: TextStyle(
                      color: p.lycheeInk,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    ticket.subject,
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                ],
              ),
            ),
            if (ticket.isOpen)
              OutlinedButton(
                onPressed: _closing ? null : _closeTicket,
                child: Text(_closing ? '关闭中…' : '关闭工单'),
              ),
            IconButton(
              tooltip: '关闭',
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Expanded(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: p.surfaceRaised,
              borderRadius: BorderRadius.circular(20),
            ),
            child: ticket.messages.isEmpty
                ? Center(
                    child: Text(
                      '暂无消息',
                      style: TextStyle(color: p.inkMuted, fontSize: 11),
                    ),
                  )
                : ListView.separated(
                    itemCount: ticket.messages.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final message = ticket.messages[index];
                      return Align(
                        alignment: message.isAdmin
                            ? Alignment.centerLeft
                            : Alignment.centerRight,
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 470),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: message.isAdmin ? p.surface : p.lycheeSoft,
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
                                  fontSize: 8,
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
        if (_error != null) ...[
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              _error!,
              style: TextStyle(color: p.dangerInk, fontSize: 10),
            ),
          ),
        ],
        if (ticket.isOpen) ...[
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _reply,
                  minLines: 1,
                  maxLines: 4,
                  decoration: const InputDecoration(hintText: '输入回复…'),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 48,
                child: FilledButton.icon(
                  onPressed: _sending ? null : _send,
                  icon: const Icon(Icons.send_rounded, size: 17),
                  label: Text(_sending ? '发送中' : '发送'),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _TicketEmptyState extends StatelessWidget {
  const _TicketEmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 34),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: p.inkMuted, size: 28),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(color: p.ink, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(color: p.inkMuted, fontSize: 10),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

String _message(Object error) => error
    .toString()
    .replaceFirst('ApiException: ', '')
    .replaceFirst('Exception: ', '');
