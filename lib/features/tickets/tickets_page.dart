import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/app_controller.dart';
import '../../app/nav_destinations.dart';
import '../../l10n/l10n.dart';
import '../../shared/models/api_models.dart';
import '../../shared/services/app_error_message_service.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_radius.dart';
import '../../shared/theme/app_text_styles.dart';
import '../../shared/widgets/app_modal.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_text_field.dart';
import '../../shared/widgets/app_toast.dart';
import '../../shared/widgets/page_status_cards.dart';
import '../../shared/widgets/responsive_page_scaffold.dart';

class TicketsPage extends StatefulWidget {
  const TicketsPage({super.key});

  @override
  State<TicketsPage> createState() => _TicketsPageState();
}

class _TicketsPageState extends State<TicketsPage> {
  bool _loading = true;
  String? _error;
  List<TicketModel> _tickets = const [];
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      unawaited(_load());
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final tickets = await AppScope.of(context).api.getTickets();
      if (!mounted) return;
      setState(() {
        _tickets = tickets;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('ApiException: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _handleRefresh() async {
    await _load();
    if (!mounted || _error != null) return;
    AppToast.show(context, context.l10n.refreshed, type: AppToastType.success);
  }

  void _openNewTicket() {
    showAppAdaptiveModal<void>(
      context: context,
      builder: (_, compact) =>
          _NewTicketModal(compact: compact, onCreated: _load),
    );
  }

  void _openTicketDetail(TicketModel ticket) {
    showAppAdaptiveModal<void>(
      context: context,
      builder: (_, compact) => _TicketDetailModal(
        compact: compact,
        ticket: ticket,
        onChanged: _load,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ResponsivePageScaffold(
      title: context.l10n.ticketSupport,
      subtitle: context.l10n.ticketSupportSubtitle,
      compactTitle: context.l10n.tickets,
      compactSubtitle: context.l10n.ticketSupportCompactSubtitle,
      primaryCompact: isPrimaryCompactTab(AppPage.tickets),
      onRefresh: _handleRefresh,
      onBack: () => AppScope.of(context).goToPage(AppPage.account),
      showWideRefresh: !_loading,
      showWideTrailing: !_loading,
      trailing: PageIconButton(
        tooltip: context.l10n.newTicket,
        icon: LucideIcons.messageSquarePlus,
        filled: true,
        onTap: _openNewTicket,
      ),
      children: _bodyChildren(context),
    );
  }

  // ── Shared body (loading / error / empty / ticket list) ────────────────────

  List<Widget> _bodyChildren(BuildContext context) {
    if (_loading) {
      return const [PageLoadingCard()];
    }
    if (_error != null) {
      return [
        PageStateCard(
          icon: LucideIcons.circleAlert,
          title: context.l10n.ticketLoadFailed,
          subtitle: AppErrorMessageService.userFacing(_error!, context.l10n),
          onTap: _load,
        ),
      ];
    }
    if (_tickets.isEmpty) {
      return [
        PageStateCard(
          icon: LucideIcons.messageSquare,
          title: context.l10n.noTickets,
          subtitle: context.l10n.noTicketsSubtitle,
          onTap: _openNewTicket,
        ),
      ];
    }
    return [
      for (final ticket in _tickets) ...[
        _TicketCard(ticket: ticket, onTap: () => _openTicketDetail(ticket)),
        const SizedBox(height: 10),
      ],
    ];
  }
}

// ── Ticket card (shared) ───────────────────────────────────────────────────────

class _TicketCard extends StatelessWidget {
  const _TicketCard({required this.ticket, required this.onTap});

  final TicketModel ticket;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final statusColor = ticket.isOpen ? c.primary : c.textMuted;
    return AppCard(
      onTap: onTap,
      shadow: AppCardShadow.soft,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: ticket.isOpen ? c.primarySoft : c.surfaceMuted,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(
              LucideIcons.messageSquare,
              color: statusColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ticket.subject.isEmpty
                      ? context.l10n.untitledTicket
                      : ticket.subject,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyStrong.copyWith(
                    color: c.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${_ticketPriority(context, ticket.level)} · ${ticket.dateDisplay}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(color: c.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            _ticketStatus(context, ticket.isOpen),
            style: AppTextStyles.caption.copyWith(
              color: statusColor,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 6),
          Icon(LucideIcons.chevronRight, color: c.iconMuted, size: 18),
        ],
      ),
    );
  }
}

// ── New ticket modal ──────────────────────────────────────────────────────────

class _NewTicketModal extends StatefulWidget {
  const _NewTicketModal({required this.compact, required this.onCreated});

  final bool compact;
  final VoidCallback onCreated;

  @override
  State<_NewTicketModal> createState() => _NewTicketModalState();
}

class _NewTicketModalState extends State<_NewTicketModal> {
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
    if (_submitting) return;
    final subject = _subjectCtrl.text.trim();
    final message = _messageCtrl.text.trim();
    if (subject.isEmpty || message.isEmpty) {
      AppToast.show(
        context,
        context.l10n.ticketFieldsRequired,
        type: AppToastType.warning,
      );
      return;
    }
    if (subject.length < 5) {
      AppToast.show(
        context,
        context.l10n.ticketSubjectTooShort,
        type: AppToastType.warning,
      );
      return;
    }
    if (message.length < 10) {
      AppToast.show(
        context,
        context.l10n.ticketMessageTooShort,
        type: AppToastType.warning,
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      await AppScope.of(
        context,
      ).api.createTicket(subject: subject, level: _level, message: message);
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onCreated();
      AppToast.show(
        context,
        context.l10n.ticketSubmitted,
        type: AppToastType.success,
      );
    } catch (e) {
      if (!mounted) return;
      AppToast.show(
        context,
        e.toString().replaceFirst('ApiException: ', ''),
        type: AppToastType.error,
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppAdaptiveModal(
      compact: widget.compact,
      title: context.l10n.newTicket,
      icon: LucideIcons.messageSquarePlus,
      child: _NewTicketForm(
        subjectCtrl: _subjectCtrl,
        messageCtrl: _messageCtrl,
        level: _level,
        onLevelChanged: (value) => setState(() => _level = value),
        submitting: _submitting,
        onSubmit: _submit,
      ),
    );
  }
}

// ── New ticket form body (shared between dialog and sheet) ─────────────────────

class _NewTicketForm extends StatelessWidget {
  const _NewTicketForm({
    required this.subjectCtrl,
    required this.messageCtrl,
    required this.level,
    required this.onLevelChanged,
    required this.submitting,
    required this.onSubmit,
  });

  final TextEditingController subjectCtrl;
  final TextEditingController messageCtrl;
  final int level;
  final ValueChanged<int> onLevelChanged;
  final bool submitting;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppFieldLabel(context.l10n.issueSubject),
        const SizedBox(height: 6),
        AppTextField(
          controller: subjectCtrl,
          hint: context.l10n.issueSubjectHint,
        ),
        const SizedBox(height: 14),
        AppFieldLabel(context.l10n.priority),
        const SizedBox(height: 8),
        _PrioritySelector(value: level, onChanged: onLevelChanged),
        const SizedBox(height: 14),
        AppFieldLabel(context.l10n.issueDescription),
        const SizedBox(height: 6),
        AppTextField(
          controller: messageCtrl,
          hint: context.l10n.issueDescriptionHint,
          maxLines: 5,
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 44,
          child: FilledButton(
            onPressed: submitting ? null : onSubmit,
            child: Text(
              submitting ? context.l10n.submitting : context.l10n.submitTicket,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Ticket detail modal ───────────────────────────────────────────────────────

class _TicketDetailModal extends StatefulWidget {
  const _TicketDetailModal({
    required this.compact,
    required this.ticket,
    required this.onChanged,
  });

  final bool compact;
  final TicketModel ticket;
  final VoidCallback onChanged;

  @override
  State<_TicketDetailModal> createState() => _TicketDetailModalState();
}

class _TicketDetailModalState extends State<_TicketDetailModal> {
  late TicketModel _ticket;
  final _replyCtrl = TextEditingController();
  bool _loading = true;
  bool _replying = false;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _ticket = widget.ticket;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_loadDetail());
    });
  }

  @override
  void dispose() {
    _replyCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadDetail() async {
    setState(() => _loading = true);
    try {
      final detail = await AppScope.of(context).api.getTicketDetail(_ticket.id);
      if (!mounted) return;
      setState(() => _ticket = detail);
    } catch (e) {
      if (!mounted) return;
      AppToast.show(
        context,
        e.toString().replaceFirst('ApiException: ', ''),
        type: AppToastType.error,
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reply() async {
    if (_replying) return;
    final message = _replyCtrl.text.trim();
    if (message.isEmpty) {
      AppToast.show(
        context,
        context.l10n.replyRequired,
        type: AppToastType.warning,
      );
      return;
    }
    setState(() => _replying = true);
    try {
      await AppScope.of(
        context,
      ).api.replyTicket(ticketId: _ticket.id, message: message);
      _replyCtrl.clear();
      await _loadDetail();
      widget.onChanged();
      if (!mounted) return;
      AppToast.show(
        context,
        context.l10n.replySent,
        type: AppToastType.success,
      );
    } catch (e) {
      if (!mounted) return;
      AppToast.show(
        context,
        e.toString().replaceFirst('ApiException: ', ''),
        type: AppToastType.error,
      );
    } finally {
      if (mounted) setState(() => _replying = false);
    }
  }

  Future<void> _close() async {
    if (_closing) return;
    setState(() => _closing = true);
    try {
      await AppScope.of(context).api.closeTicket(_ticket.id);
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onChanged();
      AppToast.show(
        context,
        context.l10n.ticketClosed,
        type: AppToastType.success,
      );
    } catch (e) {
      if (!mounted) return;
      AppToast.show(
        context,
        e.toString().replaceFirst('ApiException: ', ''),
        type: AppToastType.error,
      );
    } finally {
      if (mounted) setState(() => _closing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppAdaptiveModal(
      compact: widget.compact,
      title: _ticket.subject.isEmpty
          ? context.l10n.ticketDetails
          : _ticket.subject,
      subtitle:
          '${_ticketPriority(context, _ticket.level)} · ${_ticketStatus(context, _ticket.isOpen)}',
      icon: LucideIcons.messageSquare,
      maxWidth: 520,
      maxHeightFactor: 0.92,
      child: _TicketDetailBody(
        loading: _loading,
        messages: _ticket.messages,
        isOpen: _ticket.isOpen,
        replyCtrl: _replyCtrl,
        replying: _replying,
        closing: _closing,
        onReply: _reply,
        onClose: _close,
        messageThreadHeight: widget.compact
            ? MediaQuery.sizeOf(context).height * 0.38
            : 300,
      ),
    );
  }
}

// ── Ticket detail body (shared between dialog and sheet) ───────────────────────

class _TicketDetailBody extends StatelessWidget {
  const _TicketDetailBody({
    required this.loading,
    required this.messages,
    required this.isOpen,
    required this.replyCtrl,
    required this.replying,
    required this.closing,
    required this.onReply,
    required this.onClose,
    required this.messageThreadHeight,
  });

  final bool loading;
  final List<TicketMessageModel> messages;
  final bool isOpen;
  final TextEditingController replyCtrl;
  final bool replying;
  final bool closing;
  final VoidCallback onReply;
  final VoidCallback onClose;
  final double messageThreadHeight;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: messageThreadHeight,
          child: loading
              ? Center(child: CircularProgressIndicator(color: c.primary))
              : _MessageThread(messages: messages),
        ),
        if (isOpen) ...[
          const SizedBox(height: 12),
          AppTextField(
            controller: replyCtrl,
            hint: context.l10n.replyHint,
            maxLines: 3,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 42,
                  child: OutlinedButton.icon(
                    onPressed: closing ? null : onClose,
                    icon: const Icon(LucideIcons.archive, size: 16),
                    label: Text(
                      closing ? context.l10n.closing : context.l10n.closeTicket,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 42,
                  child: FilledButton.icon(
                    onPressed: replying ? null : onReply,
                    icon: replying
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(LucideIcons.send, size: 16),
                    label: Text(
                      replying ? context.l10n.sending : context.l10n.sendReply,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _PrioritySelector extends StatelessWidget {
  const _PrioritySelector({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  static const _items = [0, 1, 2];

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Row(
      children: [
        for (final item in _items) ...[
          Expanded(
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () => onChanged(item),
                child: Container(
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: value == item ? c.primary : c.surfaceMuted,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(
                      color: value == item ? c.primary : c.softBorder,
                    ),
                  ),
                  child: Text(
                    _ticketPriority(context, item),
                    style: AppTextStyles.button.copyWith(
                      color: value == item ? Colors.white : c.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (item != _items.last) const SizedBox(width: 8),
        ],
      ],
    );
  }
}

// ── Message thread (shared) ────────────────────────────────────────────────────

class _MessageThread extends StatelessWidget {
  const _MessageThread({required this.messages});

  final List<TicketMessageModel> messages;

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) {
      return AppEmptyState(
        icon: LucideIcons.messageCircle,
        title: context.l10n.noTicketMessages,
        padding: EdgeInsets.zero,
      );
    }
    return ListView.separated(
      itemCount: messages.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, index) => _MessageBubble(message: messages[index]),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final TicketMessageModel message;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final isAdmin = message.isAdmin;
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
            Text(
              isAdmin ? context.l10n.customerSupport : context.l10n.me,
              style: AppTextStyles.caption.copyWith(
                color: isAdmin ? c.primary : c.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (message.timeDisplay.isNotEmpty) ...[
              const SizedBox(width: 6),
              Text(
                message.timeDisplay,
                style: AppTextStyles.caption.copyWith(color: c.textMuted),
              ),
            ],
          ],
        ),
        const SizedBox(height: 5),
        Container(
          constraints: const BoxConstraints(maxWidth: 360),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: isAdmin ? c.primarySoft : c.surfaceMuted,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Text(
            message.message,
            style: AppTextStyles.body.copyWith(
              color: c.textPrimary,
              height: 1.45,
            ),
          ),
        ),
      ],
    );
  }
}

String _ticketPriority(BuildContext context, int level) => switch (level) {
  2 => context.l10n.priorityUrgent,
  1 => context.l10n.priorityMedium,
  _ => context.l10n.priorityLow,
};

String _ticketStatus(BuildContext context, bool isOpen) =>
    isOpen ? context.l10n.processing : context.l10n.ticketClosedStatus;
