import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../l10n/l10n.dart';
import '../../../shared/layout/app_platform.dart';
import '../../../shared/models/api_models.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_radius.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_text_styles.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../ticket_display.dart';

class GreenfieldTicketsSurface extends StatelessWidget {
  const GreenfieldTicketsSurface({
    super.key,
    required this.tickets,
    required this.onOpenTicket,
    required this.onCreateTicket,
  });

  final List<TicketModel> tickets;
  final ValueChanged<TicketModel> onOpenTicket;
  final VoidCallback onCreateTicket;

  @override
  Widget build(BuildContext context) {
    final open = tickets.where((ticket) => ticket.isOpen).length;
    final closed = tickets.length - open;
    final touch = AppPlatform.usesTouch;

    return Column(
      key: const ValueKey('greenfield-tickets-surface'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SupportSummary(
          touch: touch,
          open: open,
          closed: closed,
          total: tickets.length,
          onCreateTicket: onCreateTicket,
        ),
        const SizedBox(height: AppSpacing.lg),
        _TicketInbox(
          tickets: tickets,
          onOpenTicket: onOpenTicket,
        ),
        if (touch) const SizedBox(height: AppSpacing.xxl),
      ],
    );
  }
}

class _SupportSummary extends StatelessWidget {
  const _SupportSummary({
    required this.touch,
    required this.open,
    required this.closed,
    required this.total,
    required this.onCreateTicket,
  });

  final bool touch;
  final int open;
  final int closed;
  final int total;
  final VoidCallback onCreateTicket;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final metrics = [
      _SummaryMetric(
        icon: LucideIcons.clock3,
        label: context.l10n.processing,
        value: open,
      ),
      _SummaryMetric(
        icon: LucideIcons.circleCheck,
        label: context.l10n.ticketClosedStatus,
        value: closed,
      ),
      _SummaryMetric(
        icon: LucideIcons.messageSquare,
        label: context.l10n.tickets,
        value: total,
      ),
    ];

    return AppCard(
      padding: EdgeInsets.all(touch ? AppSpacing.lg : AppSpacing.xl),
      color: c.primarySoft.withValues(alpha: 0.42),
      borderColor: c.primary.withValues(alpha: 0.14),
      shadow: AppCardShadow.soft,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stackHeader = touch || constraints.maxWidth < 560;
          final intro = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: c.primary,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: const Icon(
                  LucideIcons.messageSquare,
                  size: 20,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.ticketSupport,
                      style: AppTextStyles.sectionTitle.copyWith(
                        color: c.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      context.l10n.ticketSupportSubtitle,
                      style: AppTextStyles.caption.copyWith(color: c.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          );
          final createButton = AppButton(
            label: context.l10n.newTicket,
            leadingIcon: LucideIcons.plus,
            onPressed: onCreateTicket,
            expand: stackHeader,
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (stackHeader) ...[
                intro,
                const SizedBox(height: AppSpacing.lg),
                createButton,
              ] else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: intro),
                    const SizedBox(width: AppSpacing.lg),
                    createButton,
                  ],
                ),
              const SizedBox(height: AppSpacing.xl),
              LayoutBuilder(
                builder: (context, metricConstraints) {
                  final stackMetrics =
                      touch && metricConstraints.maxWidth < 420;
                  if (stackMetrics) {
                    return Column(
                      children: [
                        for (var index = 0; index < metrics.length; index++) ...[
                          _MetricTile(data: metrics[index]),
                          if (index != metrics.length - 1)
                            const SizedBox(height: AppSpacing.sm),
                        ],
                      ],
                    );
                  }
                  return Row(
                    children: [
                      for (var index = 0; index < metrics.length; index++) ...[
                        Expanded(child: _MetricTile(data: metrics[index])),
                        if (index != metrics.length - 1)
                          const SizedBox(width: AppSpacing.sm),
                      ],
                    ],
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SummaryMetric {
  const _SummaryMetric({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final int value;
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.data});

  final _SummaryMetric data;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: c.cardBg.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: c.softBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: c.primarySoft,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(data.icon, size: 17, color: c.primary),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${data.value}',
                  style: AppTextStyles.bodyStrong.copyWith(
                    color: c.textPrimary,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  data.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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

class _TicketInbox extends StatelessWidget {
  const _TicketInbox({
    required this.tickets,
    required this.onOpenTicket,
  });

  final List<TicketModel> tickets;
  final ValueChanged<TicketModel> onOpenTicket;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return AppCard(
      padding: EdgeInsets.zero,
      shadow: AppCardShadow.soft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            child: Row(
              children: [
                Icon(LucideIcons.messageSquare, size: 18, color: c.primary),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    context.l10n.tickets,
                    style: AppTextStyles.sectionTitle.copyWith(
                      color: c.textPrimary,
                    ),
                  ),
                ),
                Text(
                  '${tickets.length}',
                  style: AppTextStyles.caption.copyWith(
                    color: c.textMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: c.softBorder),
          for (var index = 0; index < tickets.length; index++) ...[
            _TicketInboxRow(
              ticket: tickets[index],
              onTap: () => onOpenTicket(tickets[index]),
            ),
            if (index != tickets.length - 1)
              Divider(height: 1, color: c.softBorder),
          ],
        ],
      ),
    );
  }
}

class _TicketInboxRow extends StatelessWidget {
  const _TicketInboxRow({required this.ticket, required this.onTap});

  final TicketModel ticket;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final touch = AppPlatform.usesTouch;
    final title = ticket.subject.trim().isEmpty
        ? context.l10n.untitledTicket
        : ticket.subject.trim();
    final statusColor = ticket.isOpen ? c.primary : c.textMuted;
    final statusLabel = ticketStatusLabel(context, ticket.isOpen);
    final priorityLabel = ticketPriorityLabel(context, ticket.level);

    return Semantics(
      button: true,
      label: title,
      child: InkWell(
        onTap: onTap,
        mouseCursor: SystemMouseCursors.click,
        child: Padding(
          padding: EdgeInsets.all(touch ? AppSpacing.md : AppSpacing.lg),
          child: touch
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.bodyStrong.copyWith(
                              color: c.textPrimary,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        _StatusPill(label: statusLabel, color: statusColor),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            priorityLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.caption.copyWith(
                              color: c.textSecondary,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Text(
                          ticket.dateDisplay,
                          style: AppTextStyles.caption.copyWith(
                            color: c.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ],
                )
              : Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: ticket.isOpen ? c.primarySoft : c.surfaceMuted,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Icon(
                        LucideIcons.messageSquare,
                        size: 17,
                        color: statusColor,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      flex: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.bodyStrong.copyWith(
                              color: c.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            priorityLabel,
                            style: AppTextStyles.caption.copyWith(
                              color: c.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(
                      flex: 2,
                      child: Text(
                        ticket.dateDisplay,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.caption.copyWith(
                          color: c.textMuted,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    _StatusPill(label: statusLabel, color: statusColor),
                    const SizedBox(width: AppSpacing.sm),
                    Icon(
                      LucideIcons.chevronRight,
                      size: 17,
                      color: c.iconMuted,
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTextStyles.caption.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 10.5,
        ),
      ),
    );
  }
}
