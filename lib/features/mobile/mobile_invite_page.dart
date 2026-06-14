import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/app_controller.dart';
import '../../shared/models/api_models.dart';
import '../../shared/models/app_models.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_radius.dart';
import '../../shared/theme/app_shadows.dart';
import '../../shared/theme/app_text_styles.dart';
import '../../shared/widgets/app_toast.dart';

class MobileInvitePage extends StatefulWidget {
  const MobileInvitePage({super.key});

  @override
  State<MobileInvitePage> createState() => _MobileInvitePageState();
}

class _MobileInvitePageState extends State<MobileInvitePage> {
  late final PageController _pageController;
  int _selected = 0;
  bool _creating = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.9);
  }

  @override
  void dispose() {
    _pageController.dispose();
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
      error ?? '邀请码已创建',
      type: error == null ? AppToastType.success : AppToastType.error,
    );
  }

  Future<void> _handlePullRefresh() async {
    final ctrl = AppScope.of(context);
    await ctrl.refreshData();
    if (!mounted || ctrl.dataLoadError != null) return;
    AppToast.show(context, '已刷新', type: AppToastType.success);
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = AppScope.of(context);
    final invites = ctrl.inviteCodes.isEmpty
        ? [
            InviteCodeModel(
              code: ctrl.inviteCode.isEmpty ? '--' : ctrl.inviteCode,
              link: ctrl.inviteLink,
            ),
          ]
        : ctrl.inviteCodes;
    final safeSelected = _selected.clamp(0, invites.length - 1);

    void switchTo(int index) {
      final next = index % invites.length;
      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
      );
      setState(() => _selected = next);
    }

    return RefreshIndicator(
      onRefresh: _handlePullRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        children: [
          Text('邀请好友', style: AppTextStyles.pageTitle.copyWith(fontSize: 26)),
          const SizedBox(height: 16),
          _InviteLinkPanel(
            invites: invites,
            selected: safeSelected,
            creating: _creating,
            controller: _pageController,
            onChanged: (index) => setState(() => _selected = index),
            onPrevious: () => switchTo(safeSelected - 1 + invites.length),
            onNext: () => switchTo(safeSelected + 1),
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
}

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
  });

  final List<InviteCodeModel> invites;
  final int selected;
  final bool creating;
  final PageController controller;
  final ValueChanged<int> onChanged;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final invite = invites[selected];
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 16),
      decoration: BoxDecoration(
        color: c.cardBg,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: c.softBorder),
        boxShadow: AppShadows.soft(c),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '邀请链接',
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
          const SizedBox(height: 26),
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                height: 164,
                child: PageView.builder(
                  itemCount: invites.length,
                  onPageChanged: onChanged,
                  controller: controller,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      child: _InviteCodeCard(
                        code: invites[index].code,
                        index: index + 1,
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
              _CopyButton(label: '复制链接', value: invite.link, filled: true),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ShareButton(
                label: '微信',
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
    return GestureDetector(
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
              creating ? '创建中' : '创建邀请码',
              style: AppTextStyles.caption.copyWith(
                color: c.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InviteCodeCard extends StatelessWidget {
  const _InviteCodeCard({required this.code, required this.index});

  final String code;
  final int index;

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
        children: [
          Row(
            children: [
              const Icon(LucideIcons.ticket, color: Colors.white, size: 16),
              const SizedBox(width: 8),
              Text(
                '邀请码 $index',
                style: AppTextStyles.bodyStrong.copyWith(color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 18),
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
              style: AppTextStyles.largeNumber(
                fontSize: 24,
              ).copyWith(color: Colors.white),
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
    return GestureDetector(
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
              value.isEmpty ? '邀请链接未配置' : value,
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
    return GestureDetector(
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
    );
  }
}

class _InviteStatsGrid extends StatelessWidget {
  const _InviteStatsGrid({
    required this.registeredUsers,
    required this.pendingCommission,
    required this.earnedCommission,
    required this.commissionRate,
  });

  final int registeredUsers;
  final String pendingCommission;
  final String earnedCommission;
  final String commissionRate;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.92,
      children: [
        _InviteStatTile(
          label: '已注册用户',
          value: '$registeredUsers 人',
          icon: LucideIcons.users,
        ),
        _InviteStatTile(
          label: '确认中佣金',
          value: pendingCommission,
          icon: LucideIcons.circleDollarSign,
        ),
        _InviteStatTile(
          label: '累计佣金',
          value: earnedCommission,
          icon: LucideIcons.walletCards,
        ),
        _InviteStatTile(
          label: '佣金比例',
          value: commissionRate,
          icon: LucideIcons.chartNoAxesColumnIncreasing,
        ),
      ],
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
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: c.cardBg,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: c.softBorder),
        boxShadow: AppShadows.soft(c),
      ),
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.cardBg,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: c.softBorder),
        boxShadow: AppShadows.soft(c),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.receiptText, color: c.primary, size: 18),
              const SizedBox(width: 8),
              const Text('佣金记录', style: AppTextStyles.bodyStrong),
            ],
          ),
          const SizedBox(height: 12),
          if (records.isEmpty)
            Text(
              '暂无佣金记录',
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
    final name = record.userName.isEmpty ? '邀请用户' : record.userName;
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
                '${record.dateDisplay} · 订单 ${record.amountDisplay(currencySymbol)}',
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
    return GestureDetector(
      onTap: () async {
        final text = value.trim();
        if (text.isEmpty) {
          AppToast.show(context, '邀请链接未配置', type: AppToastType.warning);
          return;
        }
        await Clipboard.setData(ClipboardData(text: text));
        if (context.mounted) {
          AppToast.show(context, '已复制', type: AppToastType.success);
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
    AppToast.show(context, '邀请链接未配置', type: AppToastType.warning);
    return;
  }

  await Clipboard.setData(ClipboardData(text: text));
  if (!context.mounted) return;
  final name = switch (target) {
    _ShareTarget.wechat => '微信',
    _ShareTarget.qq => 'QQ',
    _ShareTarget.twitter => 'Twitter',
    _ShareTarget.telegram => 'Telegram',
  };
  AppToast.show(context, '链接已复制，可粘贴到$name', type: AppToastType.success);
}
