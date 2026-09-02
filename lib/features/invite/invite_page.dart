import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/app_controller.dart';
import '../../app/core_platform_support.dart';
import '../../l10n/l10n.dart';
import '../../shared/models/api_models.dart';
import '../../shared/models/app_models.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_radius.dart';
import '../../shared/theme/app_shadows.dart';
import '../../shared/theme/app_text_styles.dart';
import '../../shared/widgets/app_toast.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/page_status_cards.dart';

/// Invite and referral commission page.
///
/// Desktop uses a full-width carousel/statistics layout; compact platforms keep
/// the peeking invite-code carousel and pull-to-refresh presentation.
class InvitePage extends StatefulWidget {
  const InvitePage({super.key});

  @override
  State<InvitePage> createState() => _InvitePageState();
}

class _InvitePageState extends State<InvitePage> {
  late final PageController _compactPageController;
  late final PageController _desktopPageController;
  int _selected = 0;
  bool _creating = false;

  @override
  void initState() {
    super.initState();
    _compactPageController = PageController(viewportFraction: 0.9);
    _desktopPageController = PageController();
  }

  @override
  void dispose() {
    _compactPageController.dispose();
    _desktopPageController.dispose();
    super.dispose();
  }

  Future<void> _createInviteCode() async {
    if (_creating) return;
    setState(() => _creating = true);
    final error = await AppScope.of(context).createInviteCode();
    if (!mounted) return;
    setState(() => _creating = false);
    AppToast.show(
      context,
      error ?? context.l10n.inviteCodeCreated,
      type: error == null ? AppToastType.success : AppToastType.error,
    );
  }

  List<InviteCodeModel> _invites(AppController ctrl) {
    if (ctrl.inviteCodes.isNotEmpty) return ctrl.inviteCodes;
    return [
      InviteCodeModel(
        code: ctrl.inviteCode.isEmpty ? '--' : ctrl.inviteCode,
        link: ctrl.inviteLink,
      ),
    ];
  }

  void _switchTo(int index, int inviteCount, PageController controller) {
    final next = index % inviteCount;
    controller.animateToPage(
      next,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
    setState(() => _selected = next);
  }

  @override
  Widget build(BuildContext context) {
    if (CorePlatformSupport.isDesktop) return _buildDesktop(context);
    return _buildCompact(context);
  }

  Widget _buildDesktop(BuildContext context) {
    final ctrl = AppScope.of(context);
    final invites = _invites(ctrl);
    final safeSelected = _selected.clamp(0, invites.length - 1);

    Widget invitePanel() => _InviteLinkPanel(
      invites: invites,
      selected: safeSelected,
      creating: _creating,
      controller: _desktopPageController,
      compact: false,
      onChanged: (index) => setState(() => _selected = index),
      onPrevious: () => _switchTo(
        safeSelected - 1 + invites.length,
        invites.length,
        _desktopPageController,
      ),
      onNext: () =>
          _switchTo(safeSelected + 1, invites.length, _desktopPageController),
      onCreate: _createInviteCode,
    );

    final records = _CommissionRecords(
      records: ctrl.inviteRecords,
      currencySymbol: ctrl.currencySymbol,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 860;
            final panel = invitePanel();
            if (wide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: panel),
                  const SizedBox(width: 16),
                  Expanded(flex: 2, child: records),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [panel, const SizedBox(height: 12), records],
            );
          },
        ),
        const SizedBox(height: 14),
        _InviteStatsGrid(
          registeredUsers: ctrl.invitedCount,
          pendingCommission:
              '${ctrl.currencySymbol}${ctrl.pendingCommission.toStringAsFixed(2)}',
          earnedCommission:
              '${ctrl.currencySymbol}${ctrl.earnedCommission.toStringAsFixed(2)}',
          commissionRate: '${ctrl.commissionRate.toStringAsFixed(0)}%',
          compact: false,
        ),
      ],
    );
  }

  // ── Compact (bottom-nav) layout ────────────────────────────────────────
  Widget _buildCompact(BuildContext context) {
    final ctrl = AppScope.of(context);
    final invites = _invites(ctrl);
    final safeSelected = _selected.clamp(0, invites.length - 1);
    final asChild = ctrl.mobileProfileChildPage;

    return RefreshIndicator(
      onRefresh: _handlePullRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        children: [
          if (asChild) ...[
            Row(
              children: [
                PageBackButton(onTap: () => ctrl.goToPage(AppPage.account)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    context.l10n.inviteCommission,
                    style: AppTextStyles.pageTitle.copyWith(fontSize: 26),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          _InviteLinkPanel(
            invites: invites,
            selected: safeSelected,
            creating: _creating,
            controller: _compactPageController,
            compact: true,
            onChanged: (index) => setState(() => _selected = index),
            onPrevious: () => _switchTo(
              safeSelected - 1 + invites.length,
              invites.length,
              _compactPageController,
            ),
            onNext: () => _switchTo(
              safeSelected + 1,
              invites.length,
              _compactPageController,
            ),
            onCreate: _createInviteCode,
          ),
          const SizedBox(height: 14),
          _InviteStatsGrid(
            registeredUsers: ctrl.invitedCount,
            pendingCommission:
                '${ctrl.currencySymbol}${ctrl.pendingCommission.toStringAsFixed(2)}',
            earnedCommission:
                '${ctrl.currencySymbol}${ctrl.earnedCommission.toStringAsFixed(2)}',
            commissionRate: '${ctrl.commissionRate.toStringAsFixed(0)}%',
            compact: true,
          ),
          const SizedBox(height: 12),
          _CommissionRecords(
            records: ctrl.inviteRecords,
            currencySymbol: ctrl.currencySymbol,
          ),
        ],
      ),
    );
  }

  // ── Compact pull-to-refresh ────────────────────────────────────────────
  Future<void> _handlePullRefresh() async {
    final ctrl = AppScope.of(context);
    await ctrl.refreshData();
    if (!mounted || ctrl.dataLoadError != null) return;
    AppToast.show(context, context.l10n.refreshed, type: AppToastType.success);
  }
}

// ── Shared invite widgets ─────────────────────────────────────────────────

class _InviteLinkPanel extends StatelessWidget {
  const _InviteLinkPanel({
    required this.invites,
    required this.selected,
    required this.creating,
    required this.controller,
    required this.onChanged,
    required this.onPrevious,
    required this.onNext,
    required this.onCreate,
    this.compact = false,
  });

  final List<InviteCodeModel> invites;
  final int selected;
  final bool creating;
  final PageController controller;
  final ValueChanged<int> onChanged;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onCreate;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final invite = invites[selected];
    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 16),
      radius: AppRadius.lg,
      shadow: AppCardShadow.soft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  context.l10n.inviteLink,
                  style: AppTextStyles.bodyStrong.copyWith(
                    color: c.textPrimary,
                    fontSize: 15,
                  ),
                ),
              ),
              _CreateCodeButton(
                creating: creating,
                onTap: creating ? null : onCreate,
              ),
            ],
          ),
          SizedBox(height: compact ? 26 : 18),
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                height: compact ? 164 : 150,
                child: PageView.builder(
                  itemCount: invites.length,
                  onPageChanged: onChanged,
                  controller: controller,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: compact ? 5 : 0,
                      ),
                      child: _InviteCodeCard(
                        code: invites[index].code,
                        index: index + 1,
                        compact: compact,
                      ),
                    );
                  },
                ),
              ),
              if (invites.length > 1) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: _ArrowButton(
                    icon: LucideIcons.chevronLeft,
                    onTap: onPrevious,
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: _ArrowButton(
                    icon: LucideIcons.chevronRight,
                    onTap: onNext,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          _PageDots(count: invites.length, selected: selected),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(child: _LinkBox(link: invite.link)),
              const SizedBox(width: 10),
              _CopyButton(
                label: context.l10n.copyLink,
                value: invite.link,
                filled: true,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ShareButton(
                label: context.l10n.wechat,
                icon: LucideIcons.messageCircle,
                onTap: () =>
                    _shareInvite(context, invite.link, _ShareTarget.wechat),
              ),
              _ShareButton(
                label: 'QQ',
                icon: LucideIcons.messageCircleMore,
                onTap: () =>
                    _shareInvite(context, invite.link, _ShareTarget.qq),
              ),
              _ShareButton(
                label: 'Twitter',
                icon: LucideIcons.share2,
                onTap: () =>
                    _shareInvite(context, invite.link, _ShareTarget.twitter),
              ),
              _ShareButton(
                label: 'Telegram',
                icon: LucideIcons.send,
                onTap: () =>
                    _shareInvite(context, invite.link, _ShareTarget.telegram),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CreateCodeButton extends StatelessWidget {
  const _CreateCodeButton({required this.creating, required this.onTap});

  final bool creating;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return MouseRegion(
      cursor: onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 11),
          decoration: BoxDecoration(
            color: c.primarySoft,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (creating)
                SizedBox(
                  width: 13,
                  height: 13,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: c.primary,
                  ),
                )
              else
                Icon(LucideIcons.plus, color: c.primary, size: 15),
              const SizedBox(width: 5),
              Text(
                creating
                    ? context.l10n.creating
                    : context.l10n.createInviteCode,
                style: AppTextStyles.caption.copyWith(
                  color: c.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InviteCodeCard extends StatelessWidget {
  const _InviteCodeCard({
    required this.code,
    required this.index,
    this.compact = false,
  });

  final String code;
  final int index;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 17, 20, 17),
      decoration: BoxDecoration(
        gradient: c.brandGradient,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: [
          BoxShadow(
            color: c.primary.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: compact
            ? MainAxisAlignment.start
            : MainAxisAlignment.center,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.ticket, color: Colors.white, size: 16),
              const SizedBox(width: 8),
              Text(
                context.l10n.inviteCodeIndex(index),
                style: AppTextStyles.bodyStrong.copyWith(color: Colors.white),
              ),
            ],
          ),
          SizedBox(height: compact ? 18 : 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Text(
              code,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.largeNumber(fontSize: 24)
                  .copyWith(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _ArrowButton extends StatelessWidget {
  const _ArrowButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: c.cardBg,
            shape: BoxShape.circle,
            border: Border.all(color: c.softBorder),
            boxShadow: AppShadows.soft(c),
          ),
          child: Icon(icon, color: c.primary, size: 18),
        ),
      ),
    );
  }
}

class _PageDots extends StatelessWidget {
  const _PageDots({required this.count, required this.selected});

  final int count;
  final int selected;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < count; i++) ...[
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: selected == i ? 22 : 8,
              height: selected == i ? 7 : 8,
              decoration: BoxDecoration(
                color: selected == i ? c.primary : c.softBorder,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
            if (i != count - 1) const SizedBox(width: 7),
          ],
        ],
      ),
    );
  }
}

class _LinkBox extends StatelessWidget {
  const _LinkBox({required this.link});

  final String link;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final value = link.trim();
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: c.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: c.softBorder),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.link, color: c.textMuted, size: 15),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value.isEmpty ? context.l10n.inviteLinkUnavailable : value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption.copyWith(color: c.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShareButton extends StatelessWidget {
  const _ShareButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: c.cardBg,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: c.softBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: c.textPrimary, size: 15),
              const SizedBox(width: 7),
              Text(
                label,
                style: AppTextStyles.caption.copyWith(
                  color: c.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InviteStatsGrid extends StatelessWidget {
  const _InviteStatsGrid({
    required this.registeredUsers,
    required this.pendingCommission,
    required this.earnedCommission,
    required this.commissionRate,
    this.compact = false,
  });

  final int registeredUsers;
  final String pendingCommission;
  final String earnedCommission;
  final String commissionRate;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = !compact && constraints.maxWidth >= 760 ? 4 : 2;
        return GridView.count(
          crossAxisCount: cols,
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: compact
              ? 1.92
              : cols == 4
              ? 2.25
              : 3.35,
          children: [
            _InviteStatTile(
              label: context.l10n.registeredUsers,
              value: context.l10n.peopleCount(registeredUsers),
              icon: LucideIcons.users,
            ),
            _InviteStatTile(
              label: context.l10n.pendingCommission,
              value: pendingCommission,
              icon: LucideIcons.circleDollarSign,
            ),
            _InviteStatTile(
              label: context.l10n.totalCommission,
              value: earnedCommission,
              icon: LucideIcons.walletCards,
            ),
            _InviteStatTile(
              label: context.l10n.commissionRate,
              value: commissionRate,
              icon: LucideIcons.chartNoAxesColumnIncreasing,
            ),
          ],
        );
      },
    );
  }
}

class _InviteStatTile extends StatelessWidget {
  const _InviteStatTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return AppCard(
      padding: const EdgeInsets.all(13),
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
            child: Icon(icon, color: c.primary, size: 20),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyStrong.copyWith(
                    color: c.textPrimary,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  maxLines: 2,
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

class _CommissionRecords extends StatelessWidget {
  const _CommissionRecords({
    required this.records,
    required this.currencySymbol,
  });

  final List<RemoteInviteRecord> records;
  final String currencySymbol;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return AppCard(
      padding: const EdgeInsets.all(16),
      shadow: AppCardShadow.soft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.receiptText, color: c.primary, size: 18),
              const SizedBox(width: 8),
              Text(
                context.l10n.commissionRecords,
                style: AppTextStyles.bodyStrong,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (records.isEmpty)
            Text(
              context.l10n.noCommissionRecords,
              style: AppTextStyles.caption.copyWith(color: c.textMuted),
            )
          else
            for (final record in records.take(10)) ...[
              _CommissionRecordTile(
                record: record,
                currencySymbol: currencySymbol,
              ),
              if (record != records.take(10).last)
                Divider(height: 16, color: c.softBorder),
            ],
        ],
      ),
    );
  }
}

class _CommissionRecordTile extends StatelessWidget {
  const _CommissionRecordTile({
    required this.record,
    required this.currencySymbol,
  });

  final RemoteInviteRecord record;
  final String currencySymbol;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final name = record.userName.isEmpty
        ? context.l10n.invitedUser
        : record.userName;
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: c.primarySoft,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Icon(LucideIcons.coins, color: c.primary, size: 17),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodyStrong.copyWith(color: c.textPrimary),
              ),
              const SizedBox(height: 3),
              Text(
                context.l10n.recordOrderAmount(
                  record.dateDisplay,
                  record.amountDisplay(currencySymbol),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption.copyWith(color: c.textMuted),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Text(
          '+${record.commissionDisplay(currencySymbol)}',
          style: AppTextStyles.bodyStrong.copyWith(color: c.primary),
        ),
      ],
    );
  }
}

class _CopyButton extends StatelessWidget {
  const _CopyButton({
    required this.label,
    required this.value,
    this.filled = false,
  });

  final String label;
  final String value;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () async {
          final text = value.trim();
          if (text.isEmpty) {
            AppToast.show(
              context,
              context.l10n.inviteLinkUnavailable,
              type: AppToastType.warning,
            );
            return;
          }
          await Clipboard.setData(ClipboardData(text: text));
          if (context.mounted) {
            AppToast.show(
              context,
              context.l10n.copied,
              type: AppToastType.success,
            );
          }
        },
        child: Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: filled ? c.primary : c.primarySoft,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                LucideIcons.copy,
                size: 15,
                color: filled ? Colors.white : c.primary,
              ),
              const SizedBox(width: 7),
              Text(
                label,
                style: AppTextStyles.button.copyWith(
                  color: filled ? Colors.white : c.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _ShareTarget { wechat, qq, twitter, telegram }

Future<void> _shareInvite(
  BuildContext context,
  String link,
  _ShareTarget target,
) async {
  final text = link.trim();
  if (text.isEmpty) {
    AppToast.show(
      context,
      context.l10n.inviteLinkUnavailable,
      type: AppToastType.warning,
    );
    return;
  }

  await Clipboard.setData(ClipboardData(text: text));
  if (!context.mounted) return;
  final name = switch (target) {
    _ShareTarget.wechat => context.l10n.wechat,
    _ShareTarget.qq => 'QQ',
    _ShareTarget.twitter => 'Twitter',
    _ShareTarget.telegram => 'Telegram',
  };
  AppToast.show(
    context,
    context.l10n.linkCopiedForApp(name),
    type: AppToastType.success,
  );
}
