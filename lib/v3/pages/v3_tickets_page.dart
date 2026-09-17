import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../shared/models/api_models.dart';
import '../../shared/services/panel_api.dart';
import '../theme/v3_palette.dart';
import '../ui/v3_components.dart';
import 'v3_ticket_detail_dialog.dart';

class V3TicketsPage extends StatefulWidget {
  const V3TicketsPage({super.key});

  @override
  State<V3TicketsPage> createState() => _V3TicketsPageState();
}

class _V3TicketsPageState extends State<V3TicketsPage> {
  bool _refreshed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_refreshed) return;
    _refreshed = true;
    // Refresh after the first build: controller notifications during a build
    // would otherwise dirty the parent shell and shift its layout.
    Future.microtask(AppScope.read(context).refreshTickets);
  }

  Future<void> _openTicket(TicketModel ticket) async {
    final controller = AppScope.read(context);
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (_) => V3TicketDetailDialog(
        summary: ticket,
        api: controller.api,
        onChanged: controller.refreshTickets,
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
    if (created == true && mounted) await controller.refreshTickets();
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final p = V3Palette.of(context);
    final tickets = controller.tickets;
    final openCount = tickets.where((ticket) => ticket.isOpen).length;
    final closedCount = tickets.length - openCount;
    final error = controller.ticketsError;
    // A cached list stays visible during subsequent background refreshes.
    final skeleton = !controller.ticketsLoaded && error == null;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 26, 24, 36),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              V3PageHeader(
                kicker: '帮助与支持',
                title: '支持工单',
                description: '问题、回复和处理状态都集中在同一个支持收件箱。',
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (!compact)
                      FilledButton.icon(
                        onPressed: _newTicket,
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('新建工单'),
                      ),
                    IconButton(
                      tooltip: '刷新工单',
                      onPressed: controller.ticketsLoading
                          ? null
                          : controller.refreshTickets,
                      icon: const Icon(Icons.refresh_rounded),
                    ),
                  ],
                ),
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
                      value: '${tickets.length}',
                      accent: p.lychee,
                      loading: skeleton,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _TicketMetric(
                      label: '处理中',
                      value: '$openCount',
                      accent: p.warning,
                      loading: skeleton,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _TicketMetric(
                      label: '已关闭',
                      value: '$closedCount',
                      accent: p.success,
                      loading: skeleton,
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
                child: skeleton
                    ? const _TicketsSkeleton()
                    : error != null
                        ? _TicketEmptyState(
                            icon: Icons.error_outline_rounded,
                            title: '工单加载失败',
                            subtitle: error,
                            actionLabel: '重试',
                            onAction: controller.refreshTickets,
                          )
                        : tickets.isEmpty
                            ? _TicketEmptyState(
                                icon: Icons.support_agent_rounded,
                                title: '还没有工单',
                                subtitle: '遇到问题时，可以直接从这里联系支持。',
                                actionLabel: '创建第一张工单',
                                onAction: _newTicket,
                              )
                            : Column(
                                children: [
                                  for (var i = 0; i < tickets.length; i++) ...[
                                    _TicketRow(
                                      ticket: tickets[i],
                                      onTap: () => _openTicket(tickets[i]),
                                    ),
                                    if (i != tickets.length - 1)
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
    this.loading = false,
  });

  final String label;
  final String value;
  final Color accent;
  final bool loading;

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
              Text(label, style: TextStyle(color: p.inkMuted, fontSize: 10)),
              const SizedBox(height: 4),
              if (loading)
                const V3SkeletonBlock(width: 30, height: 16)
              else
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

/// Skeleton rows match the horizontal geometry of loaded ticket rows.
class _TicketsSkeleton extends StatelessWidget {
  const _TicketsSkeleton();

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return Column(
      children: [
        for (var i = 0; i < 3; i++) ...[
          const _TicketSkeletonRow(),
          if (i != 2) Divider(color: p.line, height: 1),
        ],
      ],
    );
  }
}

class _TicketSkeletonRow extends StatelessWidget {
  const _TicketSkeletonRow();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 15),
      child: Row(
        children: [
          V3SkeletonBlock(width: 44, height: 44, radius: 15),
          SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FractionallySizedBox(
                  widthFactor: 0.72,
                  alignment: Alignment.centerLeft,
                  child: V3SkeletonBlock(height: 12),
                ),
                SizedBox(height: 7),
                FractionallySizedBox(
                  widthFactor: 0.45,
                  alignment: Alignment.centerLeft,
                  child: V3SkeletonBlock(height: 9),
                ),
              ],
            ),
          ),
          SizedBox(width: 12),
          V3SkeletonBlock(width: 44, height: 20, radius: 10),
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
                    style: TextStyle(color: p.inkMuted, fontSize: 10),
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
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 9),
            Text(
              ticket.statusLabel,
              style: TextStyle(
                color: statusColor,
                fontSize: 10,
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
                Text(
                  _error!,
                  style: TextStyle(color: p.dangerInk, fontSize: 11),
                ),
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
