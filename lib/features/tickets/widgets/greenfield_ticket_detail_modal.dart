import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/app_controller.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/models/api_models.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_radius.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_text_styles.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_modal.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/page_status_cards.dart';
import '../ticket_display.dart';

class GreenfieldTicketDetailModal extends StatefulWidget {
  const GreenfieldTicketDetailModal({
    super.key,
    required this.ticket,
    required this.onChanged,
  });

  final TicketModel ticket;
  final VoidCallback onChanged;

  @override
  State<GreenfieldTicketDetailModal> createState() =>
      _GreenfieldTicketDetailModalState();
}

class _GreenfieldTicketDetailModalState
    extends State<GreenfieldTicketDetailModal> {
  late TicketModel _ticket;
  final TextEditingController _replyController = TextEditingController();
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
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _loadDetail() async {
    setState(() => _loading = true);
    try {
      final detail = await AppScope.of(context).api.getTicketDetail(_ticket.id);
      if (!mounted) return;
      setState(() => _ticket = detail);
    } catch (error) {
      if (!mounted) return;
      AppToast.show(
        context,
        error.toString().replaceFirst('ApiException: ', ''),
        type: AppToastType.error,
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reply() async {
    if (_replying) return;
    final message = _replyController.text.trim();
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
      _replyController.clear();
      await _loadDetail();
      widget.onChanged();
      if (!mounted) return;
      AppToast.show(
        context,
        context.l10n.replySent,
        type: AppToastType.success,
      );
    } catch (error) {
      if (!mounted) return;
      AppToast.show(
        context,
        error.toString().replaceFirst('ApiException: ', ''),
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
    } catch (error) {
      if (!mounted) return;
      AppToast.show(
        context,
        error.toString().replaceFirst('ApiException: ', ''),
        type: AppToastType.error,
      );
    } finally {
      if (mounted) setState(() => _closing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final threadHeight = (MediaQuery.sizeOf(context).height * 0.38)
        .clamp(220.0, 420.0)
        .toDouble();
    return AppAdaptiveModal(
      title: _ticket.subject.trim().isEmpty
          ? context.l10n.ticketDetails
          : _ticket.subject.trim(),
      subtitle:
          '${ticketPriorityLabel(context, _ticket.level)} · ${ticketStatusLabel(context, _ticket.isOpen)}',
      maxHeightFactor: 0.92,
      maxWidth: 680,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: threadHeight,
            child: _loading
                ? Center(
                    child: CircularProgressIndicator(
                      color: AppColors.of(context).primary,
                    ),
                  )
                : _MessageThread(messages: _ticket.messages),
          ),
          if (_ticket.isOpen) ...[
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              controller: _replyController,
              hint: context.l10n.replyHint,
              maxLines: 3,
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: _closing
                        ? context.l10n.closing
                        : context.l10n.closeTicket,
                    leadingIcon: LucideIcons.archive,
                    variant: AppButtonVariant.outline,
                    loading: _closing,
                    onPressed: _closing ? null : _close,
                    expand: true,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  flex: 2,
                  child: AppButton(
                    label: _replying
                        ? context.l10n.sending
                        : context.l10n.sendReply,
                    leadingIcon: LucideIcons.send,
                    loading: _replying,
                    onPressed: _replying ? null : _reply,
                    expand: true,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

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
      padding: const EdgeInsets.only(right: AppSpacing.xs),
      itemCount: messages.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
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
    final fromSupport = message.isAdmin;
    return Column(
      crossAxisAlignment:
          fromSupport ? CrossAxisAlignment.start : CrossAxisAlignment.end,
      children: [
        Row(
          mainAxisAlignment:
              fromSupport ? MainAxisAlignment.start : MainAxisAlignment.end,
          children: [
            Text(
              fromSupport ? context.l10n.customerSupport : context.l10n.me,
              style: AppTextStyles.caption.copyWith(
                color: fromSupport ? c.primary : c.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (message.timeDisplay.isNotEmpty) ...[
              const SizedBox(width: AppSpacing.sm),
              Text(
                message.timeDisplay,
                style: AppTextStyles.caption.copyWith(color: c.textMuted),
              ),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: fromSupport ? c.primarySoft : c.surfaceMuted,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(
                color: fromSupport
                    ? c.primary.withValues(alpha: 0.12)
                    : c.softBorder,
              ),
            ),
            child: Text(
              message.message,
              style: AppTextStyles.body.copyWith(
                color: c.textPrimary,
                height: 1.45,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
