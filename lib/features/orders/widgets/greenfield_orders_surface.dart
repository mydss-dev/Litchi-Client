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

class GreenfieldOrdersSurface extends StatelessWidget {
  const GreenfieldOrdersSurface({
    super.key,
    required this.orders,
    required this.currencySymbol,
    required this.activeTradeNo,
    required this.onPay,
    required this.onCancel,
  });

  final List<RemoteOrder> orders;
  final String currencySymbol;
  final String? activeTradeNo;
  final ValueChanged<RemoteOrder> onPay;
  final ValueChanged<RemoteOrder> onCancel;

  @override
  Widget build(BuildContext context) {
    final pending = orders.where((order) => order.status == 0).length;
    final processing = orders.where((order) => order.status == 1).length;
    final completed = orders
        .where((order) => order.status == 3 || order.status == 4)
        .length;

    return Column(
      key: const ValueKey('greenfield-orders-surface'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _OrderSummary(
          pending: pending,
          processing: processing,
          completed: completed,
        ),
        const SizedBox(height: AppSpacing.lg),
        _OrderLedger(
          orders: orders,
          currencySymbol: currencySymbol,
          activeTradeNo: activeTradeNo,
          onPay: onPay,
          onCancel: onCancel,
        ),
        if (AppPlatform.usesTouch) const SizedBox(height: AppSpacing.xxl),
      ],
    );
  }
}

class _OrderSummary extends StatelessWidget {
  const _OrderSummary({
    required this.pending,
    required this.processing,
    required this.completed,
  });

  final int pending;
  final int processing;
  final int completed;

  @override
  Widget build(BuildContext context) {
    final items = [
      _SummaryData(
        icon: LucideIcons.clock3,
        label: context.l10n.orderPending,
        value: pending,
      ),
      _SummaryData(
        icon: LucideIcons.loaderCircle,
        label: context.l10n.orderProcessing,
        value: processing,
      ),
      _SummaryData(
        icon: LucideIcons.circleCheck,
        label: context.l10n.orderCompleted,
        value: completed,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final stack = AppPlatform.usesTouch && constraints.maxWidth < 420;
        if (stack) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var index = 0; index < items.length; index++) ...[
                _SummaryCard(data: items[index]),
                if (index != items.length - 1)
                  const SizedBox(height: AppSpacing.sm),
              ],
            ],
          );
        }
        return Row(
          children: [
            for (var index = 0; index < items.length; index++) ...[
              Expanded(child: _SummaryCard(data: items[index])),
              if (index != items.length - 1)
                const SizedBox(width: AppSpacing.sm),
            ],
          ],
        );
      },
    );
  }
}

class _SummaryData {
  const _SummaryData({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final int value;
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.data});

  final _SummaryData data;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      shadow: AppCardShadow.soft,
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
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

class _OrderLedger extends StatelessWidget {
  const _OrderLedger({
    required this.orders,
    required this.currencySymbol,
    required this.activeTradeNo,
    required this.onPay,
    required this.onCancel,
  });

  final List<RemoteOrder> orders;
  final String currencySymbol;
  final String? activeTradeNo;
  final ValueChanged<RemoteOrder> onPay;
  final ValueChanged<RemoteOrder> onCancel;

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
                Icon(LucideIcons.receiptText, size: 18, color: c.primary),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    context.l10n.orders,
                    style: AppTextStyles.sectionTitle.copyWith(
                      color: c.textPrimary,
                    ),
                  ),
                ),
                Text(
                  '${orders.length}',
                  style: AppTextStyles.caption.copyWith(
                    color: c.textMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: c.softBorder),
          for (var index = 0; index < orders.length; index++) ...[
            _OrderLedgerRow(
              order: orders[index],
              currencySymbol: currencySymbol,
              busy: activeTradeNo == orders[index].tradeNo,
              actionsLocked: activeTradeNo != null,
              onPay: () => onPay(orders[index]),
              onCancel: () => onCancel(orders[index]),
            ),
            if (index != orders.length - 1)
              Divider(height: 1, color: c.softBorder),
          ],
        ],
      ),
    );
  }
}

class _OrderLedgerRow extends StatelessWidget {
  const _OrderLedgerRow({
    required this.order,
    required this.currencySymbol,
    required this.busy,
    required this.actionsLocked,
    required this.onPay,
    required this.onCancel,
  });

  final RemoteOrder order;
  final String currencySymbol;
  final bool busy;
  final bool actionsLocked;
  final VoidCallback onPay;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final touch = AppPlatform.usesTouch;
    final c = AppColors.of(context);
    final orderNo = order.tradeNo.isEmpty ? '--' : order.tradeNo;
    final isDeposit = order.period == 'deposit';
    final billing = isDeposit
        ? context.l10n.accountTopUp
        : _localizedPeriod(context, order.period, order.periodLabel);
    final planName = order.planName?.trim() ?? '';
    final title = isDeposit
        ? context.l10n.accountTopUp
        : planName.isNotEmpty
        ? planName
        : billing;
    final status = _localizedOrderStatus(context, order.status);
    final statusColor = _statusColor(c, order.status);
    final pending = order.status == 0;

    return Padding(
      padding: EdgeInsets.all(touch ? AppSpacing.md : AppSpacing.lg),
      child: touch
          ? _TouchOrderContent(
              title: title,
              orderNo: orderNo,
              billing: billing,
              date: order.dateDisplay,
              amount: order.amountDisplay(currencySymbol),
              status: status,
              statusColor: statusColor,
              pending: pending,
              busy: busy,
              actionsLocked: actionsLocked,
              onPay: onPay,
              onCancel: onCancel,
            )
          : _DesktopOrderContent(
              title: title,
              orderNo: orderNo,
              billing: billing,
              date: order.dateDisplay,
              amount: order.amountDisplay(currencySymbol),
              status: status,
              statusColor: statusColor,
              pending: pending,
              busy: busy,
              actionsLocked: actionsLocked,
              onPay: onPay,
              onCancel: onCancel,
            ),
    );
  }
}

class _DesktopOrderContent extends StatelessWidget {
  const _DesktopOrderContent({
    required this.title,
    required this.orderNo,
    required this.billing,
    required this.date,
    required this.amount,
    required this.status,
    required this.statusColor,
    required this.pending,
    required this.busy,
    required this.actionsLocked,
    required this.onPay,
    required this.onCancel,
  });

  final String title;
  final String orderNo;
  final String billing;
  final String date;
  final String amount;
  final String status;
  final Color statusColor;
  final bool pending;
  final bool busy;
  final bool actionsLocked;
  final VoidCallback onPay;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: c.primarySoft,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(LucideIcons.receipt, size: 17, color: c.primary),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
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
                    context.l10n.orderNumber(orderNo),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(color: c.textMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Text(
              amount,
              style: AppTextStyles.bodyStrong.copyWith(
                color: c.textPrimary,
                fontSize: 16,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            _StatusPill(label: status, color: statusColor),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        LayoutBuilder(
          builder: (context, constraints) {
            final actions = pending
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AppButton(
                        label: context.l10n.cancelOrder,
                        leadingIcon: LucideIcons.x,
                        size: AppControlSize.compact,
                        variant: AppButtonVariant.outline,
                        onPressed: actionsLocked ? null : onCancel,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      AppButton(
                        label: context.l10n.continuePayment,
                        leadingIcon: LucideIcons.creditCard,
                        size: AppControlSize.compact,
                        loading: busy,
                        onPressed: actionsLocked ? null : onPay,
                      ),
                    ],
                  )
                : const SizedBox.shrink();
            final meta = Wrap(
              spacing: AppSpacing.lg,
              runSpacing: AppSpacing.sm,
              children: [
                _MetaText(label: context.l10n.type, value: billing),
                _MetaText(label: context.l10n.date, value: date),
              ],
            );
            if (!pending || constraints.maxWidth >= 520) {
              return Row(
                children: [
                  Expanded(child: meta),
                  if (pending) ...[
                    const SizedBox(width: AppSpacing.md),
                    actions,
                  ],
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                meta,
                const SizedBox(height: AppSpacing.md),
                Align(alignment: Alignment.centerRight, child: actions),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _TouchOrderContent extends StatelessWidget {
  const _TouchOrderContent({
    required this.title,
    required this.orderNo,
    required this.billing,
    required this.date,
    required this.amount,
    required this.status,
    required this.statusColor,
    required this.pending,
    required this.busy,
    required this.actionsLocked,
    required this.onPay,
    required this.onCancel,
  });

  final String title;
  final String orderNo;
  final String billing;
  final String date;
  final String amount;
  final String status;
  final Color statusColor;
  final bool pending;
  final bool busy;
  final bool actionsLocked;
  final VoidCallback onPay;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyStrong.copyWith(
                      color: c.textPrimary,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    context.l10n.orderNumber(orderNo),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(color: c.textMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            _StatusPill(label: status, color: statusColor),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(child: _MetaBlock(label: context.l10n.type, value: billing)),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: _MetaBlock(label: context.l10n.date, value: date)),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        _MetaBlock(label: context.l10n.amount, value: amount, strong: true),
        if (pending) ...[
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: context.l10n.cancelOrder,
                  leadingIcon: LucideIcons.x,
                  variant: AppButtonVariant.outline,
                  onPressed: actionsLocked ? null : onCancel,
                  expand: true,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                flex: 2,
                child: AppButton(
                  label: context.l10n.continuePayment,
                  leadingIcon: LucideIcons.creditCard,
                  loading: busy,
                  onPressed: actionsLocked ? null : onPay,
                  expand: true,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _MetaText extends StatelessWidget {
  const _MetaText({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Text(
      '$label  ${value.isEmpty ? '--' : value}',
      style: AppTextStyles.caption.copyWith(color: c.textSecondary),
    );
  }
}

class _MetaBlock extends StatelessWidget {
  const _MetaBlock({
    required this.label,
    required this.value,
    this.strong = false,
  });

  final String label;
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: c.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: c.textMuted,
              fontSize: 10.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value.isEmpty ? '--' : value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: (strong ? AppTextStyles.bodyStrong : AppTextStyles.caption)
                .copyWith(
                  color: c.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTextStyles.caption.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

Color _statusColor(AppColors colors, int status) => switch (status) {
  0 => colors.warning,
  1 => colors.primary,
  2 => colors.textMuted,
  3 || 4 => colors.success,
  _ => colors.textMuted,
};

String _localizedOrderStatus(BuildContext context, int status) => switch (status) {
  0 => context.l10n.orderPending,
  1 => context.l10n.orderProcessing,
  2 => context.l10n.orderCancelledStatus,
  3 => context.l10n.orderCompleted,
  4 => context.l10n.orderDiscounted,
  _ => context.l10n.unknown,
};

String _localizedPeriod(BuildContext context, String period, String fallback) =>
    switch (period) {
      'month_price' => context.l10n.monthly,
      'quarter_price' => context.l10n.quarterly,
      'half_year_price' => context.l10n.halfYear,
      'year_price' => context.l10n.yearly,
      'two_year_price' => context.l10n.twoYears,
      'three_year_price' => context.l10n.threeYears,
      'onetime_price' => context.l10n.buyout,
      _ => fallback,
    };
