import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/app_controller.dart';
import '../../shared/models/api_models.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_radius.dart';
import '../../shared/theme/app_shadows.dart';
import '../../shared/theme/app_text_styles.dart';
import '../../shared/widgets/app_bottom_sheet.dart';
import '../../shared/widgets/app_toast.dart';
import 'mobile_back_button.dart';

class MobileTicketsPage extends StatefulWidget {
  const MobileTicketsPage({super.key});

  @override
  State<MobileTicketsPage> createState() => _MobileTicketsPageState();
}

class _MobileTicketsPageState extends State<MobileTicketsPage> {
  bool _loading = true;
  String? _error;
  List<TicketModel> _tickets = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_load());
    });
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

  Future<void> _handlePullRefresh() async {
    await _load();
    if (!mounted || _error != null) return;
    AppToast.show(context, '已刷新', type: AppToastType.success);
  }

  void _showNewTicketSheet() {
    showAppBottomSheet<void>(
      context: context,
      builder: (_) => _NewTicketSheet(onCreated: _load),
    );
  }

  void _showTicketDetail(TicketModel ticket) {
    showAppBottomSheet<void>(
      context: context,
      builder: (_) => _TicketDetailSheet(ticket: ticket, onChanged: _load),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return RefreshIndicator(
      onRefresh: _handlePullRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        children: [
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
                onPressed: _showNewTicketSheet,
                icon: Icon(LucideIcons.messageSquarePlus, color: c.primary),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_loading)
            Padding(
              padding: const EdgeInsets.only(top: 80),
              child: Center(child: CircularProgressIndicator(color: c.primary)),
            )
          else if (_error != null)
            _StateCard(
              icon: LucideIcons.circleAlert,
              title: '工单加载失败',
              subtitle: _error!,
            )
          else if (_tickets.isEmpty)
            const _StateCard(
              icon: LucideIcons.messageSquare,
              title: '暂无工单',
              subtitle: '有问题可以新建工单联系客服',
            )
          else
            for (final ticket in _tickets) ...[
              _TicketCard(
                ticket: ticket,
                onTap: () => _showTicketDetail(ticket),
              ),
              const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }
}

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
        const _SheetLabel('问题标题'),
        const SizedBox(height: 6),
        _SheetTextField(controller: _subjectCtrl, hint: '用一句话描述你的问题'),
        const SizedBox(height: 14),
        const _SheetLabel('优先级'),
        const SizedBox(height: 8),
        _PrioritySelector(
          value: _level,
          onChanged: (value) => setState(() => _level = value),
        ),
        const SizedBox(height: 14),
        const _SheetLabel('问题描述'),
        const SizedBox(height: 6),
        _SheetTextField(
          controller: _messageCtrl,
          hint: '详细描述你遇到的问题',
          maxLines: 5,
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 44,
          child: FilledButton(
            onPressed: _submitting ? null : _submit,
            child: Text(_submitting ? '提交中...' : '提交工单'),
          ),
        ),
      ],
    );
  }
}

class _SheetLabel extends StatelessWidget {
  const _SheetLabel(this.text);

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

class _SheetTextField extends StatelessWidget {
  const _SheetTextField({
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
          if (item != _items.last) const SizedBox(width: 8),
        ],
      ],
    );
  }
}

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
    final c = AppColors.of(context);
    return AppBottomSheet(
      title: _ticket.subject.isEmpty ? '工单详情' : _ticket.subject,
      subtitle: '${_ticket.levelLabel} · ${_ticket.statusLabel}',
      maxHeightFactor: 0.92,
      children: [
        SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.38,
          child: _loading
              ? Center(child: CircularProgressIndicator(color: c.primary))
              : _MessageThread(messages: _ticket.messages),
        ),
        if (_ticket.isOpen) ...[
          const SizedBox(height: 12),
          _SheetTextField(controller: _replyCtrl, hint: '输入回复内容', maxLines: 3),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 42,
                  child: OutlinedButton.icon(
                    onPressed: _closing ? null : _close,
                    icon: const Icon(LucideIcons.archive, size: 16),
                    label: Text(_closing ? '关闭中...' : '关闭工单'),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 42,
                  child: FilledButton.icon(
                    onPressed: _replying ? null : _reply,
                    icon: _replying
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(LucideIcons.send, size: 16),
                    label: Text(_replying ? '发送中...' : '发送回复'),
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
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.72,
          ),
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

class _StateCard extends StatelessWidget {
  const _StateCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: c.cardBg,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: c.softBorder),
      ),
      child: Row(
        children: [
          Icon(icon, color: c.iconMuted, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.bodyStrong),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: AppTextStyles.caption.copyWith(color: c.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
