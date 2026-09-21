import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../shared/models/api_models.dart';
import '../../shared/services/api_client.dart';
import '../../shared/services/panel_api.dart';
import '../theme/v3_palette.dart';
import '../ui/v3_components.dart';
import '../ui/v3_layout.dart';
import '../ui/v3_locale_copy.dart';
import 'v3_ticket_detail_dialog.dart';

// Loading and loaded rows reserve the same space. Avoid the list shifting
// the page header or its neighboring content when asynchronous data arrives.
const double kV3TicketRowHeight = 76;
const int kV3TicketSkeletonCount = 3;
const double kV3TicketListMinHeight =
    kV3TicketRowHeight * kV3TicketSkeletonCount + kV3TicketSkeletonCount - 1;

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
    Future.microtask(AppScope.read(context).refreshTickets);
  }

  Future<void> _openTicket(TicketModel ticket) async {
    final controller = AppScope.read(context);
    await showDialog<void>(context: context,
      barrierColor: Colors.black.withValues(alpha: .5),
      builder: (_) => V3TicketDetailDialog(summary: ticket,
        api: controller.api, onChanged: controller.refreshTickets));
  }

  Future<void> _newTicket() async {
    final controller = AppScope.read(context);
    final created = await showDialog<bool>(context: context,
      barrierColor: Colors.black.withValues(alpha: .5),
      builder: (_) => _NewTicketDialog(api: controller.api));
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
    final skeleton = !controller.ticketsLoaded && error == null;
    return LayoutBuilder(builder: (context, constraints) {
      final compact = constraints.maxWidth < V3Layout.paneCompact;
      final createLabel = v3Copy(context, zh: '新建工单',
        en: 'New ticket', tw: '新增工單');
      return SingleChildScrollView(
        padding: V3Layout.pageInsets,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // No header height reserve: V3PageHeader bottoms-align its row, so
          // a minHeight box here pushed the heading 35dp below every other
          // page's first line.
          V3PageHeader(
            kicker: v3Copy(context, zh: '帮助与支持',
              en: 'HELP & SUPPORT', tw: '協助與支援'),
            title: v3Copy(context, zh: '支持工单',
              en: 'Support tickets', tw: '支援工單'),
            description: v3Copy(context,
              zh: '问题、回复和处理状态都集中在同一个支持收件箱。',
              en: 'Keep questions, replies and ticket statuses in one inbox.',
              tw: '問題、回覆及處理狀態都集中在同一個支援收件匣。'),
            trailing: Row(mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end, children: [
                if (!compact)
                  FilledButton.icon(onPressed: _newTicket,
                    icon: const Icon(Icons.add_rounded), label: Text(createLabel)),
                IconButton(tooltip: v3Copy(context, zh: '刷新工单',
                    en: 'Refresh tickets', tw: '重新整理工單'),
                  onPressed: controller.ticketsLoading
                    ? null : controller.refreshTickets,
                  icon: const Icon(Icons.refresh_rounded)),
              ])),
          if (compact) ...[
            const SizedBox(height: 16),
            SizedBox(width: double.infinity,
              child: FilledButton.icon(onPressed: _newTicket,
                icon: const Icon(Icons.add_rounded), label: Text(createLabel))),
          ],
          const SizedBox(height: 18),
          Row(children: [
            Expanded(child: _TicketMetric(label: v3Copy(context,
                zh: '全部工单', en: 'All tickets', tw: '全部工單'),
              value: '${tickets.length}', accent: p.lychee, loading: skeleton)),
            const SizedBox(width: 12),
            Expanded(child: _TicketMetric(label: v3Copy(context,
                zh: '处理中', en: 'Open', tw: '處理中'),
              value: '$openCount', accent: p.warning, loading: skeleton)),
            const SizedBox(width: 12),
            Expanded(child: _TicketMetric(label: v3Copy(context,
                zh: '已关闭', en: 'Closed', tw: '已關閉'),
              value: '$closedCount', accent: p.success, loading: skeleton)),
          ]),
          const SizedBox(height: 16),
          Container(width: double.infinity, padding: const EdgeInsets.all(18),
            constraints: const BoxConstraints(minHeight: kV3TicketListMinHeight + 36),
            decoration: BoxDecoration(color: p.surface,
              borderRadius: BorderRadius.circular(V3Radius.panel),
              border: Border.all(color: p.line)),
            child: skeleton
              ? const _TicketsSkeleton()
              : error != null
                ? _TicketEmptyState(icon: Icons.error_outline_rounded,
                    title: v3Copy(context, zh: '工单加载失败',
                      en: 'Could not load tickets', tw: '工單載入失敗'),
                    subtitle: error,
                    actionLabel: v3Copy(context, zh: '重试', en: 'Retry', tw: '重試'),
                    onAction: controller.refreshTickets)
                : tickets.isEmpty
                  ? _TicketEmptyState(icon: Icons.support_agent_rounded,
                      title: v3Copy(context, zh: '还没有工单',
                        en: 'No tickets yet', tw: '尚無工單'),
                      subtitle: v3Copy(context,
                        zh: '遇到问题时，可以直接从这里联系支持。',
                        en: 'Contact support here whenever you need help.',
                        tw: '遇到問題時，可直接在此聯絡支援。'),
                      actionLabel: v3Copy(context, zh: '创建第一张工单',
                        en: 'Create your first ticket', tw: '建立第一張工單'),
                      onAction: _newTicket)
                  : Column(children: [
                      for (var i = 0; i < tickets.length; i++) ...[
                        _TicketRow(ticket: tickets[i],
                          wide: constraints.maxWidth >= V3Layout.paneCompact,
                          onTap: () => _openTicket(tickets[i])),
                        if (i != tickets.length - 1)
                          Divider(color: p.line, height: 1),
                      ],
                    ])),
        ]),
      );
    });
  }
}

class _TicketMetric extends StatelessWidget {
  const _TicketMetric({required this.label, required this.value,
    required this.accent, this.loading = false});
  final String label;
  final String value;
  final Color accent;
  final bool loading;
  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return Container(height: 96, padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(color: p.surfaceRaised,
        borderRadius: BorderRadius.circular(V3Radius.panel)),
      child: Row(children: [
        Container(width: 4, height: 44,
          decoration: BoxDecoration(color: accent,
            borderRadius: BorderRadius.circular(V3Radius.control))),
        const SizedBox(width: 12),
        Column(mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(color: p.inkMuted, fontSize: 10)),
            const SizedBox(height: 4),
            if (loading)
              const V3SkeletonBlock(width: 30, height: 16)
            else Text(value, style: TextStyle(color: p.ink,
              fontSize: 19, fontWeight: FontWeight.w900)),
          ]),
      ]));
  }
}

class _TicketsSkeleton extends StatelessWidget {
  const _TicketsSkeleton();
  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return Column(children: [
      for (var i = 0; i < kV3TicketSkeletonCount; i++) ...[
        const _TicketSkeletonRow(),
        if (i != kV3TicketSkeletonCount - 1)
          Divider(color: p.line, height: 1),
      ],
    ]);
  }
}

class _TicketSkeletonRow extends StatelessWidget {
  const _TicketSkeletonRow();
  @override
  Widget build(BuildContext context) {
    return const SizedBox(height: kV3TicketRowHeight,
      child: Padding(padding: EdgeInsets.symmetric(horizontal: 4),
        child: Row(children: [
          V3SkeletonBlock(width: 44, height: 44, radius: V3Radius.field),
          SizedBox(width: 13),
          Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start, children: [
              FractionallySizedBox(widthFactor: .72,
                alignment: Alignment.centerLeft,
                child: V3SkeletonBlock(height: 12)),
              SizedBox(height: 7),
              FractionallySizedBox(widthFactor: .45,
                alignment: Alignment.centerLeft,
                child: V3SkeletonBlock(height: 9)),
            ])),
          SizedBox(width: 12),
          V3SkeletonBlock(width: 44, height: 20, radius: V3Radius.control),
        ])));
  }
}

class _TicketRow extends StatelessWidget {
  const _TicketRow({required this.ticket, required this.wide,
    required this.onTap});
  final TicketModel ticket;
  final bool wide;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    final statusColor = ticket.isOpen ? p.warningInk : p.successInk;
    final levelColor = switch (ticket.level) {
      2 => p.dangerInk, 1 => p.warningInk, _ => p.aqua,
    };
    final levelLabel = switch (ticket.level) {
      2 => v3Copy(context, zh: ticket.levelLabel,
        en: 'Urgent', tw: '緊急'),
      1 => v3Copy(context, zh: ticket.levelLabel,
        en: 'Medium', tw: '中等'),
      _ => v3Copy(context, zh: ticket.levelLabel,
        en: 'Low', tw: '低'),
    };
    if (!wide) {
      return InkWell(borderRadius: BorderRadius.circular(V3Radius.card), onTap: onTap,
        child: SizedBox(height: 102,
          child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: Text(ticket.subject.trim().isEmpty
                      ? v3Copy(context, zh: '未命名工单', en: 'Untitled ticket',
                        tw: '未命名工單') : ticket.subject,
                    maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: p.ink, fontSize: 13,
                      fontWeight: FontWeight.w800))),
                  const SizedBox(width: 9),
                  Text(v3Copy(context, zh: ticket.statusLabel,
                    en: ticket.isOpen ? 'Open' : 'Closed',
                    tw: ticket.isOpen ? '處理中' : '已關閉'),
                    style: TextStyle(color: statusColor, fontSize: 10,
                      fontWeight: FontWeight.w800)),
                ]),
                const SizedBox(height: 9),
                Row(children: [
                  Text(levelLabel, style: TextStyle(color: levelColor,
                    fontSize: 10, fontWeight: FontWeight.w800)),
                  const SizedBox(width: 9),
                  Expanded(child: Text('#${ticket.id} · ${ticket.dateDisplay}',
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: TextStyle(color: p.inkMuted, fontSize: 10))),
                ]),
              ]))));
    }
    return InkWell(borderRadius: BorderRadius.circular(V3Radius.card), onTap: onTap,
      child: SizedBox(height: kV3TicketRowHeight,
        child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(children: [
            Container(width: 44, height: 44,
              decoration: BoxDecoration(color: statusColor.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(V3Radius.field)),
              child: Icon(Icons.forum_rounded, color: statusColor, size: 20)),
            const SizedBox(width: 13),
            Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(ticket.subject.trim().isEmpty
                    ? v3Copy(context, zh: '未命名工单',
                        en: 'Untitled ticket', tw: '未命名工單')
                    : ticket.subject, maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: p.ink, fontSize: 12,
                    fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text('#${ticket.id} · ${ticket.dateDisplay}', maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: p.inkMuted, fontSize: 10)),
              ])),
            const SizedBox(width: 12),
            Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
              decoration: BoxDecoration(color: levelColor.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(V3Radius.control)),
              child: Text(levelLabel, style: TextStyle(color: levelColor,
                fontSize: 10, fontWeight: FontWeight.w800))),
            const SizedBox(width: 9),
            Text(v3Copy(context, zh: ticket.statusLabel,
                en: ticket.isOpen ? 'Open' : 'Closed',
                tw: ticket.isOpen ? '處理中' : '已關閉'),
              style: TextStyle(color: statusColor, fontSize: 10,
                fontWeight: FontWeight.w800)),
            const SizedBox(width: 5),
            Icon(Icons.chevron_right_rounded, color: p.inkMuted, size: 18),
          ]))));
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
    _subject.dispose(); _messageController.dispose(); super.dispose();
  }

  Future<void> _submit() async {
    final subject = _subject.text.trim();
    final message = _messageController.text.trim();
    if (subject.isEmpty || message.isEmpty) {
      setState(() => _error = v3Copy(context,
        zh: '请填写主题和问题描述',
        en: 'Enter a subject and describe your issue',
        tw: '請填寫主題及問題描述'));
      return;
    }
    if (_submitting) return;
    setState(() { _submitting = true; _error = null; });
    try {
      await widget.api.createTicket(subject: subject,
        level: _level, message: message);
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      // An unconfigured API base is a dev-review state, not user-facing
      // feedback: close quietly instead of showing the raw config string.
      if (error is ApiNotConfiguredException) {
        Navigator.of(context).pop(false);
        return;
      }
      setState(() { _submitting = false; _error = _message(error); });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return AlertDialog(backgroundColor: p.surface,
      title: Text(v3Copy(context, zh: '新建工单',
        en: 'New ticket', tw: '新增工單')),
      content: SizedBox(width: 520,
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            TextField(controller: _subject,
              decoration: InputDecoration(labelText: v3Copy(context,
                zh: '主题', en: 'Subject', tw: '主題'))),
            const SizedBox(height: 16),
            Text(v3Copy(context, zh: '优先级',
              en: 'Priority', tw: '優先級'),
              style: TextStyle(color: p.inkMuted, fontSize: 10)),
            const SizedBox(height: 8),
            SegmentedButton<int>(segments: [
              ButtonSegment(value: 0, label: Text(v3Copy(context,
                zh: '低', en: 'Low', tw: '低'))),
              ButtonSegment(value: 1, label: Text(v3Copy(context,
                zh: '中等', en: 'Medium', tw: '中等'))),
              ButtonSegment(value: 2, label: Text(v3Copy(context,
                zh: '紧急', en: 'Urgent', tw: '緊急'))),
            ], selected: {_level}, showSelectedIcon: false,
              onSelectionChanged: (value) => setState(() => _level = value.first)),
            const SizedBox(height: 16),
            TextField(controller: _messageController,
              minLines: 5, maxLines: 8,
              decoration: InputDecoration(labelText: v3Copy(context,
                zh: '问题描述', en: 'Issue description', tw: '問題描述'),
                alignLabelWithHint: true)),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: p.dangerInk, fontSize: 11)),
            ],
          ]))),
      actions: [
        TextButton(onPressed: _submitting ? null
          : () => Navigator.of(context).pop(false),
          child: Text(v3Copy(context, zh: '取消', en: 'Cancel', tw: '取消'))),
        FilledButton(onPressed: _submitting ? null : _submit,
          child: Text(_submitting ? v3Copy(context, zh: '提交中…',
              en: 'Submitting…', tw: '提交中…')
            : v3Copy(context, zh: '提交工单',
              en: 'Submit ticket', tw: '提交工單'))),
      ]);
  }
}

class _TicketEmptyState extends StatelessWidget {
  const _TicketEmptyState({required this.icon, required this.title,
    required this.subtitle, this.actionLabel, this.onAction});
  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return Padding(padding: const EdgeInsets.symmetric(vertical: 34),
      child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: p.inkMuted, size: 28),
        const SizedBox(height: 12),
        Text(title, style: TextStyle(color: p.ink, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text(subtitle, textAlign: TextAlign.center,
          style: TextStyle(color: p.inkMuted, fontSize: 10)),
        if (actionLabel != null && onAction != null) ...[
          const SizedBox(height: 16),
          OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ])));
  }
}

String _message(Object error) => error.toString()
    .replaceFirst('ApiException: ', '')
    .replaceFirst('Exception: ', '');
