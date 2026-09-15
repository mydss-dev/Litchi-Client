import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/app_controller.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/services/ticket_access.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_modal.dart';
import '../../../shared/widgets/app_select.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/app_toast.dart';
import '../ticket_display.dart';

class GreenfieldNewTicketModal extends StatefulWidget {
  const GreenfieldNewTicketModal({super.key, required this.onCreated});

  final VoidCallback onCreated;

  @override
  State<GreenfieldNewTicketModal> createState() =>
      _GreenfieldNewTicketModalState();
}

class _GreenfieldNewTicketModalState
    extends State<GreenfieldNewTicketModal> {
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  int _level = 0;
  bool _submitting = false;

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final subject = _subjectController.text.trim();
    final message = _messageController.text.trim();

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
    final api = AppScope.of(context).api;
    final userFuture = ticketBestEffort(api.getUserInfo());
    final subscribeFuture = ticketBestEffort(api.getSubscribeInfo());
    final freshUser = await userFuture;
    final freshSubscribe = await subscribeFuture;
    if (!mounted) return;

    try {
      await api.createTicket(subject: subject, level: _level, message: message);
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onCreated();
      AppToast.show(
        context,
        context.l10n.ticketSubmitted,
        type: AppToastType.success,
      );
    } catch (error) {
      if (!mounted) return;
      final userMessage =
          isTicketSubscriptionRequiredError(error) &&
              ticketAccountHasActiveSubscription(
                user: freshUser,
                subscribe: freshSubscribe,
              )
          ? context.l10n.ticketSubscriptionMismatch
          : error.toString().replaceFirst('ApiException: ', '');
      AppToast.show(context, userMessage, type: AppToastType.error);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppAdaptiveModal(
      title: context.l10n.newTicket,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppFieldLabel(context.l10n.issueSubject),
          const SizedBox(height: AppSpacing.sm),
          AppTextField(
            controller: _subjectController,
            hint: context.l10n.issueSubjectHint,
          ),
          const SizedBox(height: AppSpacing.lg),
          AppFieldLabel(context.l10n.priority),
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: AppSelect<int>(
              value: _level,
              items: const [0, 1, 2],
              labelOf: (value) => ticketPriorityLabel(context, value),
              onChanged: _submitting
                  ? null
                  : (value) => setState(() => _level = value),
              minWidth: 150,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppFieldLabel(context.l10n.issueDescription),
          const SizedBox(height: AppSpacing.sm),
          AppTextField(
            controller: _messageController,
            hint: context.l10n.issueDescriptionHint,
            maxLines: 5,
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: _submitting
                ? context.l10n.submitting
                : context.l10n.submitTicket,
            leadingIcon: LucideIcons.send,
            loading: _submitting,
            onPressed: _submitting ? null : _submit,
            expand: true,
          ),
        ],
      ),
    );
  }
}
