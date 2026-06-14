import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/app_controller.dart';
import '../../shared/models/api_models.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_radius.dart';
import '../../shared/theme/app_text_styles.dart';
import '../../shared/widgets/app_badge.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_toast.dart';
import '../../shared/widgets/page_header.dart';
import '../../shared/widgets/page_status_cards.dart';

class TicketsPage extends StatefulWidget {
  const TicketsPage({super.key});

  @override
  State<TicketsPage> createState() => _TicketsPageState();
}

class _TicketsPageState extends State<TicketsPage> {
  bool _loading = true;
  String? _error;
  List<TicketModel> _tickets = [];
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final tickets = await AppScope.of(context).api.getTickets();
      if (mounted) setState(() => _tickets = tickets);
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e.toString().replaceFirst('ApiException: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: PageHeader(title: '工单', subtitle: '提交问题，与支持团队沟通'),
              ),
              if (!_loading) ...[
                RefreshIconButton(onTap: _load),
                const SizedBox(width: 8),
                _NewTicketButton(onCreated: _load),
              ],
            ],
          ),
          const SizedBox(height: 12),
          if (_loading)
            const PageLoadingCard()
          else if (_error != null)
            PageErrorCard(message: _error!, onRetry: _load)
          else if (_tickets.isEmpty)
            _EmptyState(onNew: _load)
          else
            _TicketList(tickets: _tickets, onRefresh: _load),
        ],
      ),
    );
  }
}

// ── New ticket button ─────────────────────────────────────────────────────────

class _NewTicketButton extends StatelessWidget {
  const _NewTicketButton({required this.onCreated});

  final VoidCallback onCreated;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => showDialog(
          context: context,
          builder: (_) => _NewTicketDialog(onCreated: onCreated),
        ),
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: c.primary,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(LucideIcons.plus, size: 14, color: Colors.white),
              const SizedBox(width: 6),
              Text(
                '新建工单',
                style: AppTextStyles.button.copyWith(
                  color: Colors.white,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Ticket list ───────────────────────────────────────────────────────────────

class _TicketList extends StatelessWidget {
  const _TicketList({required this.tickets, required this.onRefresh});

  final List<TicketModel> tickets;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (int i = 0; i < tickets.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          _TicketCard(ticket: tickets[i], onRefresh: onRefresh),
        ],
      ],
    );
  }
}

class _TicketCard extends StatelessWidget {
  const _TicketCard({required this.ticket, required this.onRefresh});

  final TicketModel ticket;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return AppCard(
      radius: AppRadius.card,
      padding: const EdgeInsets.all(16),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => showDialog(
            context: context,
            builder: (_) =>
                _TicketDetailDialog(ticket: ticket, onRefresh: onRefresh),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ticket.subject,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodyStrong.copyWith(
                        color: c.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      ticket.dateDisplay,
                      style: AppTextStyles.caption.copyWith(
                        color: c.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _LevelBadge(level: ticket.level),
              const SizedBox(width: 8),
              _StatusBadge(isOpen: ticket.isOpen),
              const SizedBox(width: 10),
              Icon(LucideIcons.chevronRight, size: 14, color: c.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _LevelBadge extends StatelessWidget {
  const _LevelBadge({required this.level});

  final int level;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final (label, bg, fg) = switch (level) {
      2 => ('紧急', c.dangerSoft, c.danger),
      1 => ('中等', c.warning.withValues(alpha: 0.12), c.warning),
      _ => ('低', c.surfaceMuted, c.textMuted),
    };
    return AppBadge(
      text: label,
      background: bg,
      textColor: fg,
      fontSize: 10,
      height: 20,
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.isOpen});

  final bool isOpen;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return AppBadge(
      text: isOpen ? '处理中' : '已关闭',
      background: isOpen ? c.primary.withValues(alpha: 0.1) : c.surfaceMuted,
      textColor: isOpen ? c.primary : c.textMuted,
      fontSize: 10,
      height: 20,
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onNew});

  final VoidCallback onNew;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return AppCard(
      radius: AppRadius.card,
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Center(
        child: Column(
          children: [
            Icon(LucideIcons.messageSquare, size: 36, color: c.textMuted),
            const SizedBox(height: 12),
            Text(
              '暂无工单',
              style: AppTextStyles.bodyStrong.copyWith(color: c.textPrimary),
            ),
            const SizedBox(height: 6),
            Text(
              '遇到问题？提交工单联系支持团队',
              style: AppTextStyles.body.copyWith(color: c.textMuted),
            ),
            const SizedBox(height: 20),
            _NewTicketButton(onCreated: onNew),
          ],
        ),
      ),
    );
  }
}

// ── New ticket dialog ─────────────────────────────────────────────────────────

class _NewTicketDialog extends StatefulWidget {
  const _NewTicketDialog({required this.onCreated});

  final VoidCallback onCreated;

  @override
  State<_NewTicketDialog> createState() => _NewTicketDialogState();
}

class _NewTicketDialogState extends State<_NewTicketDialog> {
  final _subjectCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  int _level = 0;
  bool _submitting = false;

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final subject = _subjectCtrl.text.trim();
    final message = _messageCtrl.text.trim();
    if (subject.isEmpty || message.isEmpty) {
      AppToast.show(context, '请填写标题和问题描述', type: AppToastType.warning);
      return;
    }
    if (subject.length < 5) {
      AppToast.show(context, '问题标题至少 5 个字符', type: AppToastType.warning);
      return;
    }
    if (message.length < 10) {
      AppToast.show(context, '问题描述至少 10 个字符', type: AppToastType.warning);
      return;
    }
    setState(() => _submitting = true);
    try {
      await AppScope.of(
        context,
      ).api.createTicket(subject: subject, level: _level, message: message);
      if (mounted) {
        Navigator.of(context).pop();
        widget.onCreated();
        AppToast.show(context, '工单已提交', type: AppToastType.success);
      }
    } catch (e) {
      if (mounted) {
        AppToast.show(context, e.toString(), type: AppToastType.error);
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return AlertDialog(
      backgroundColor: c.cardBg,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(color: c.softBorder),
      ),
      title: Row(
        children: [
          Icon(LucideIcons.messageSquarePlus, size: 18, color: c.primary),
          const SizedBox(width: 10),
          Text(
            '新建工单',
            style: AppTextStyles.bodyStrong.copyWith(
              color: c.textPrimary,
              fontSize: 15,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _FormLabel('问题标题', c),
            const SizedBox(height: 6),
            _InputField(controller: _subjectCtrl, hint: '用一句话描述你的问题', c: c),
            const SizedBox(height: 14),
            _FormLabel('优先级', c),
            const SizedBox(height: 6),
            _LevelSelector(
              value: _level,
              onChanged: (v) => setState(() => _level = v),
            ),
            const SizedBox(height: 14),
            _FormLabel('问题描述', c),
            const SizedBox(height: 6),
            _InputField(
              controller: _messageCtrl,
              hint: '详细描述你遇到的问题…',
              c: c,
              maxLines: 5,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            '取消',
            style: AppTextStyles.button.copyWith(color: c.textMuted),
          ),
        ),
        TextButton(
          onPressed: _submitting ? null : _submit,
          child: Text(
            _submitting ? '提交中…' : '提交',
            style: AppTextStyles.button.copyWith(color: c.primary),
          ),
        ),
      ],
    );
  }
}

// ── Ticket detail dialog ──────────────────────────────────────────────────────

class _TicketDetailDialog extends StatefulWidget {
  const _TicketDetailDialog({required this.ticket, required this.onRefresh});

  final TicketModel ticket;
  final VoidCallback onRefresh;

  @override
  State<_TicketDetailDialog> createState() => _TicketDetailDialogState();
}

class _TicketDetailDialogState extends State<_TicketDetailDialog> {
  late TicketModel _ticket;
  final _replyCtrl = TextEditingController();
  bool _loadingDetail = true;
  bool _replying = false;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _ticket = widget.ticket;
    _loadDetail();
  }

  @override
  void dispose() {
    _replyCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadDetail() async {
    setState(() => _loadingDetail = true);
    try {
      final detail = await AppScope.of(context).api.getTicketDetail(_ticket.id);
      if (mounted) setState(() => _ticket = detail);
    } catch (_) {
      // keep showing basic info if detail fetch fails
    } finally {
      if (mounted) setState(() => _loadingDetail = false);
    }
  }

  Future<void> _reply() async {
    final msg = _replyCtrl.text.trim();
    if (msg.isEmpty) return;
    setState(() => _replying = true);
    try {
      await AppScope.of(
        context,
      ).api.replyTicket(ticketId: _ticket.id, message: msg);
      _replyCtrl.clear();
      await _loadDetail();
      widget.onRefresh();
    } catch (e) {
      if (mounted) {
        AppToast.show(context, e.toString(), type: AppToastType.error);
      }
    } finally {
      if (mounted) setState(() => _replying = false);
    }
  }

  Future<void> _close() async {
    setState(() => _closing = true);
    try {
      await AppScope.of(context).api.closeTicket(_ticket.id);
      if (mounted) {
        Navigator.of(context).pop();
        widget.onRefresh();
        AppToast.show(context, '工单已关闭', type: AppToastType.success);
      }
    } catch (e) {
      if (mounted) {
        AppToast.show(context, e.toString(), type: AppToastType.error);
      }
    } finally {
      if (mounted) setState(() => _closing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return AlertDialog(
      backgroundColor: c.cardBg,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(color: c.softBorder),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              _ticket.subject,
              style: AppTextStyles.bodyStrong.copyWith(
                color: c.textPrimary,
                fontSize: 15,
              ),
            ),
          ),
          const SizedBox(width: 8),
          _StatusBadge(isOpen: _ticket.isOpen),
        ],
      ),
      content: SizedBox(
        width: 480,
        height: 340,
        child: _loadingDetail
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Expanded(
                    child: _MessageThread(messages: _ticket.messages, c: c),
                  ),
                  if (_ticket.isOpen) ...[
                    const SizedBox(height: 12),
                    Divider(color: c.softBorder, height: 1),
                    const SizedBox(height: 12),
                    _InputField(
                      controller: _replyCtrl,
                      hint: '输入回复…',
                      c: c,
                      maxLines: 3,
                    ),
                  ],
                ],
              ),
      ),
      actions: [
        if (_ticket.isOpen) ...[
          TextButton(
            onPressed: _closing ? null : _close,
            child: Text(
              _closing ? '关闭中…' : '关闭工单',
              style: AppTextStyles.button.copyWith(color: c.danger),
            ),
          ),
          const SizedBox(width: 4),
          TextButton(
            onPressed: _replying ? null : _reply,
            child: Text(
              _replying ? '发送中…' : '发送回复',
              style: AppTextStyles.button.copyWith(color: c.primary),
            ),
          ),
        ] else
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              '关闭',
              style: AppTextStyles.button.copyWith(color: c.textMuted),
            ),
          ),
      ],
    );
  }
}

class _MessageThread extends StatelessWidget {
  const _MessageThread({required this.messages, required this.c});

  final List<TicketMessageModel> messages;
  final AppColors c;

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) {
      return Center(
        child: Text(
          '暂无消息记录',
          style: AppTextStyles.body.copyWith(color: c.textMuted),
        ),
      );
    }
    return ListView.separated(
      itemCount: messages.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _MessageBubble(msg: messages[i], c: c),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.msg, required this.c});

  final TicketMessageModel msg;
  final AppColors c;

  @override
  Widget build(BuildContext context) {
    final isAdmin = msg.isAdmin;
    return Column(
      crossAxisAlignment: isAdmin
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.end,
      children: [
        Row(
          mainAxisAlignment: isAdmin
              ? MainAxisAlignment.start
              : MainAxisAlignment.end,
          children: [
            if (isAdmin) ...[
              Icon(LucideIcons.headphones, size: 12, color: c.primary),
              const SizedBox(width: 4),
              Text(
                '客服',
                style: AppTextStyles.caption.copyWith(
                  color: c.primary,
                  fontSize: 11,
                ),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              msg.timeDisplay,
              style: AppTextStyles.caption.copyWith(
                color: c.textMuted,
                fontSize: 10,
              ),
            ),
            if (!isAdmin) ...[
              const SizedBox(width: 6),
              Text(
                '我',
                style: AppTextStyles.caption.copyWith(
                  color: c.textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Container(
          constraints: const BoxConstraints(maxWidth: 360),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isAdmin ? c.primarySoft : c.surfaceMuted,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Text(
            msg.message,
            style: AppTextStyles.body.copyWith(
              color: c.textPrimary,
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Shared form helpers ───────────────────────────────────────────────────────

class _FormLabel extends StatelessWidget {
  const _FormLabel(this.label, this.c);

  final String label;
  final AppColors c;

  @override
  Widget build(BuildContext context) =>
      Text(label, style: AppTextStyles.caption.copyWith(color: c.textMuted));
}

class _InputField extends StatelessWidget {
  const _InputField({
    required this.controller,
    required this.hint,
    required this.c,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String hint;
  final AppColors c;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: AppTextStyles.body.copyWith(color: c.textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppTextStyles.body.copyWith(
          color: c.textMuted,
          fontSize: 13,
        ),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(color: c.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(color: c.primary),
        ),
        filled: true,
        fillColor: c.cardBg,
      ),
    );
  }
}

class _LevelSelector extends StatelessWidget {
  const _LevelSelector({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  static const _levels = [(0, '低'), (1, '中等'), (2, '紧急')];

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      height: 36,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: c.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: c.softBorder),
      ),
      child: Row(
        children: [
          for (final (lvl, label) in _levels)
            Expanded(
              child: _LevelChip(
                label: label,
                level: lvl,
                selected: value == lvl,
                onTap: () => onChanged(lvl),
              ),
            ),
        ],
      ),
    );
  }
}

class _LevelChip extends StatelessWidget {
  const _LevelChip({
    required this.label,
    required this.level,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int level;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final Color fg = selected
        ? switch (level) {
            3 => c.danger,
            2 => c.warning,
            _ => c.primary,
          }
        : c.textSecondary;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? c.cardBg : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.xs),
          ),
          child: Text(
            label,
            style: AppTextStyles.button.copyWith(
              color: fg,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
