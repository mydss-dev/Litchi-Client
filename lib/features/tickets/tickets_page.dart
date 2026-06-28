import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/app_controller.dart';
import '../../app/nav_destinations.dart';
import '../../shared/models/api_models.dart';
import '../../shared/responsive/breakpoints.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_radius.dart';
import '../../shared/theme/app_shadows.dart';
import '../../shared/theme/app_text_styles.dart';
import '../../shared/widgets/app_bottom_sheet.dart';
import '../../shared/widgets/app_toast.dart';
import '../../shared/widgets/page_header.dart';
import '../../shared/widgets/page_status_cards.dart';
import '../mobile/mobile_back_button.dart';
import '../mobile/mobile_page_header.dart';

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
    AppToast.show(context, '已刷新', type: AppToastType.success);
  }

  void _openNewTicket() {
    if (context.isCompact) {
      showAppBottomSheet<void>(
        context: context,
        builder: (_) => _NewTicketSheet(onCreated: _load),
      );
    } else {
      showDialog<void>(
        context: context,
        barrierColor: Colors.black.withValues(alpha: 0.42),
        builder: (_) => _NewTicketDialog(onCreated: _load),
      );
    }
  }

  void _openTicketDetail(TicketModel ticket) {
    if (context.isCompact) {
      showAppBottomSheet<void>(
        context: context,
        builder: (_) => _TicketDetailSheet(ticket: ticket, onChanged: _load),
      );
    } else {
      showDialog<void>(
        context: context,
        barrierColor: Colors.black.withValues(alpha: 0.42),
        builder: (_) => _TicketDetailDialog(ticket: ticket, onChanged: _load),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (Breakpoints.isCompactWidth(constraints.maxWidth)) {
          return _buildCompact(context);
        }
        return _buildWide(context);
      },
    );
  }

  // ── Wide (sidebar) layout ──────────────────────────────────────────────────

  Widget _buildWide(BuildContext context) {
    final ctrl = AppScope.of(context);
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PageBackButton(
                onTap: () => ctrl.goToPage(AppPage.account),
                tooltip: '返回我的',
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: PageHeader(title: '工单支持', subtitle: '提交问题并查看回复'),
              ),
              if (!_loading) ...[
                const SizedBox(width: 10),
                RefreshIconButton(onTap: _handleRefresh),
                const SizedBox(width: 8),
                PageIconButton(
                  tooltip: '新建工单',
                  icon: LucideIcons.messageSquarePlus,
                  filled: true,
                  onTap: _openNewTicket,
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          ..._bodyChildren(context),
        ],
      ),
    );
  }

  // ── Compact (bottom-nav) layout ────────────────────────────────────────────

  Widget _buildCompact(BuildContext context) {
    final c = AppColors.of(context);
    final asPrimary = isPrimaryCompactTab(AppPage.tickets);
    return RefreshIndicator(
      onRefresh: _handleRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        children: [
          if (asPrimary)
            MobilePageHeader(
              title: '工单',
              subtitle: '提交问题并查看客服回复',
              trailing: IconButton(
                tooltip: '新建工单',
                onPressed: _openNewTicket,
                icon: Icon(LucideIcons.messageSquarePlus, color: c.primary),
              ),
            )
          else
            Row(
              children: [
                MobileBackButton(
                  onTap: () => AppScope.of(context).goToPage(AppPage.account),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '工单支持',
                    style: AppTextStyles.pageTitle.copyWith(fontSize: 26),
                  ),
                ),
                IconButton(
                  tooltip: '新建工单',
                  onPressed: _openNewTicket,
                  icon: Icon(LucideIcons.messageSquarePlus, color: c.primary),
                ),
              ],
            ),
          const SizedBox(height: 16),
          ..._bodyChildren(context),
        ],
      ),
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
          title: '工单加载失败',
          subtitle: _error!,
          onTap: _load,
        ),
      ];
    }
    if (_tickets.isEmpty) {
      return [
        PageStateCard(
          icon: LucideIcons.messageSquare,
          title: '暂无工单',
          subtitle: '有问题可以新建工单联系客服',
          onTap: _openNewTicket,
        ),
      ];
    }
    return [
      for (final ticket in _tickets) ...[
        _TicketCard(
          ticket: ticket,
          onTap: () => _openTicketDetail(ticket),
        ),
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: c.cardBg,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: c.softBorder),
            boxShadow: AppShadows.soft(c),
          ),
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
                      ticket.subject.isEmpty ? '未命名工单' : ticket.subject,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodyStrong.copyWith(
                        color: c.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${ticket.levelLabel} · ${ticket.dateDisplay}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption.copyWith(color: c.textMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                ticket.statusLabel,
                style: AppTextStyles.caption.copyWith(
                  color: statusColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 6),
              Icon(LucideIcons.chevronRight, color: c.iconMuted, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

// ── New ticket: dialog (wide) ──────────────────────────────────────────────────

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
    if (_submitting) return;
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
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onCreated();
      AppToast.show(context, '工单已提交', type: AppToastType.success);
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
    return _DialogShell(
      title: '新建工单',
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

// ── New ticket: bottom sheet (compact) ─────────────────────────────────────────

class _NewTicketSheet extends StatefulWidget {
  const _NewTicketSheet({required this.onCreated});

  final VoidCallback onCreated;

  @override
  State<_NewTicketSheet> createState() => _NewTicketSheetState();
}

class _NewTicketSheetState extends State<_NewTicketSheet> {
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
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onCreated();
      AppToast.show(context, '工单已提交', type: AppToastType.success);
    } catch (e) {
      if (mounted) {
        AppToast.show(
          context,
          e.toString().replaceFirst('ApiException: ', ''),
          type: AppToastType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppBottomSheet(
      title: '新建工单',
      children: [
        _NewTicketForm(
          subjectCtrl: _subjectCtrl,
          messageCtrl: _messageCtrl,
          level: _level,
          onLevelChanged: (value) => setState(() => _level = value),
          submitting: _submitting,
          onSubmit: _submit,
        ),
      ],
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
        const _FormLabel('问题标题'),
        const SizedBox(height: 6),
        _FormTextField(controller: subjectCtrl, hint: '用一句话描述你的问题'),
        const SizedBox(height: 14),
        const _FormLabel('优先级'),
        const SizedBox(height: 8),
        _PrioritySelector(value: level, onChanged: onLevelChanged),
        const SizedBox(height: 14),
        const _FormLabel('问题描述'),
        const SizedBox(height: 6),
        _FormTextField(
          controller: messageCtrl,
          hint: '详细描述你遇到的问题',
          maxLines: 5,
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 44,
          child: FilledButton(
            onPressed: submitting ? null : onSubmit,
            child: Text(submitting ? '提交中...' : '提交工单'),
          ),
        ),
      ],
    );
  }
}

// ── Ticket detail: dialog (wide) ───────────────────────────────────────────────

class _TicketDetailDialog extends StatefulWidget {
  const _TicketDetailDialog({required this.ticket, required this.onChanged});

  final TicketModel ticket;
  final VoidCallback onChanged;

  @override
  State<_TicketDetailDialog> createState() => _TicketDetailDialogState();
}

class _TicketDetailDialogState extends State<_TicketDetailDialog> {
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
      AppToast.show(context, '请输入回复内容', type: AppToastType.warning);
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
      AppToast.show(context, '回复已发送', type: AppToastType.success);
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
      AppToast.show(context, '工单已关闭', type: AppToastType.success);
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
    return _DialogShell(
      title: _ticket.subject.isEmpty ? '工单详情' : _ticket.subject,
      subtitle: '${_ticket.levelLabel} · ${_ticket.statusLabel}',
      icon: LucideIcons.messageSquare,
      maxWidth: 520,
      child: _TicketDetailBody(
        loading: _loading,
        messages: _ticket.messages,
        isOpen: _ticket.isOpen,
        replyCtrl: _replyCtrl,
        replying: _replying,
        closing: _closing,
        onReply: _reply,
        onClose: _close,
        messageThreadHeight: 300,
      ),
    );
  }
}

// ── Ticket detail: bottom sheet (compact) ──────────────────────────────────────

class _TicketDetailSheet extends StatefulWidget {
  const _TicketDetailSheet({required this.ticket, required this.onChanged});

  final TicketModel ticket;
  final VoidCallback onChanged;

  @override
  State<_TicketDetailSheet> createState() => _TicketDetailSheetState();
}

class _TicketDetailSheetState extends State<_TicketDetailSheet> {
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
      AppToast.show(context, '请输入回复内容', type: AppToastType.warning);
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
      AppToast.show(context, '回复已发送', type: AppToastType.success);
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
      AppToast.show(context, '工单已关闭', type: AppToastType.success);
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
    return AppBottomSheet(
      title: _ticket.subject.isEmpty ? '工单详情' : _ticket.subject,
      subtitle: '${_ticket.levelLabel} · ${_ticket.statusLabel}',
      maxHeightFactor: 0.92,
      children: [
        _TicketDetailBody(
          loading: _loading,
          messages: _ticket.messages,
          isOpen: _ticket.isOpen,
          replyCtrl: _replyCtrl,
          replying: _replying,
          closing: _closing,
          onReply: _reply,
          onClose: _close,
          messageThreadHeight: MediaQuery.sizeOf(context).height * 0.38,
        ),
      ],
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
          _FormTextField(controller: replyCtrl, hint: '输入回复内容', maxLines: 3),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 42,
                  child: OutlinedButton.icon(
                    onPressed: closing ? null : onClose,
                    icon: const Icon(LucideIcons.archive, size: 16),
                    label: Text(closing ? '关闭中...' : '关闭工单'),
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
                    label: Text(replying ? '发送中...' : '发送回复'),
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

// ── Dialog shell (wide) ────────────────────────────────────────────────────────

class _DialogShell extends StatelessWidget {
  const _DialogShell({
    required this.title,
    required this.icon,
    required this.child,
    this.subtitle,
    this.maxWidth = 460,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          decoration: BoxDecoration(
            color: c.cardBg,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(color: c.softBorder),
            boxShadow: AppShadows.card(c),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 18, color: c.primary),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.sectionTitle.copyWith(
                            color: c.textPrimary,
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 3),
                          Text(
                            subtitle!,
                            style: AppTextStyles.caption.copyWith(
                              color: c.textMuted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Icon(LucideIcons.x, size: 17, color: c.textMuted),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

// ── Form widgets (shared) ──────────────────────────────────────────────────────

class _FormLabel extends StatelessWidget {
  const _FormLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Text(
      text,
      style: AppTextStyles.caption.copyWith(
        color: c.textMuted,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _FormTextField extends StatelessWidget {
  const _FormTextField({
    required this.controller,
    required this.hint,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String hint;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: AppTextStyles.input.copyWith(color: c.textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppTextStyles.input.copyWith(color: c.textMuted),
        filled: true,
        fillColor: c.surfaceMuted,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: c.softBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: c.primary),
        ),
      ),
    );
  }
}

class _PrioritySelector extends StatelessWidget {
  const _PrioritySelector({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  static const _items = [(0, '低'), (1, '中'), (2, '紧急')];

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
                onTap: () => onChanged(item.$1),
                child: Container(
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: value == item.$1 ? c.primary : c.surfaceMuted,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(
                      color: value == item.$1 ? c.primary : c.softBorder,
                    ),
                  ),
                  child: Text(
                    item.$2,
                    style: AppTextStyles.button.copyWith(
                      color: value == item.$1 ? Colors.white : c.textSecondary,
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
    final c = AppColors.of(context);
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
              isAdmin ? '客服' : '我',
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
