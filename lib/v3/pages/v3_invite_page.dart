import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_controller.dart';
import '../../shared/models/app_models.dart';
import '../theme/v3_palette.dart';
import '../ui/v3_components.dart';

class V3InvitePage extends StatefulWidget {
  const V3InvitePage({super.key});

  @override
  State<V3InvitePage> createState() => _V3InvitePageState();
}

class _V3InvitePageState extends State<V3InvitePage> {
  int _selected = 0;
  bool _creating = false;

  List<InviteCodeModel> _codes(AppController controller) {
    if (controller.inviteCodes.isNotEmpty) return controller.inviteCodes;
    final code = controller.inviteCode.trim();
    final link = controller.inviteLink.trim();
    if (code.isEmpty && link.isEmpty) return const [];
    return [InviteCodeModel(code: code, link: link)];
  }

  Future<void> _copy(String value, String message) async {
    final text = value.trim();
    if (text.isEmpty) {
      _toast('当前没有可复制的邀请内容');
      return;
    }
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) _toast(message);
  }

  Future<void> _createCode() async {
    if (_creating) return;
    setState(() => _creating = true);
    final controller = AppScope.read(context);
    final error = await controller.createInviteCode();
    if (!mounted) return;
    setState(() {
      _creating = false;
      final length = _codes(controller).length;
      if (length == 0) {
        _selected = 0;
      } else if (_selected >= length) {
        _selected = length - 1;
      }
    });
    _toast(error ?? '新的邀请码已创建');
  }

  void _toast(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final p = V3Palette.of(context);
    final codes = _codes(controller);
    final safeIndex = codes.isEmpty ? 0 : _selected.clamp(0, codes.length - 1);
    final active = codes.isEmpty ? null : codes[safeIndex];

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 26, 24, 36),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '邀请奖励',
                          style: TextStyle(
                            color: p.lycheeInk,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2.2,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          '邀请好友',
                          style: Theme.of(context).textTheme.displayMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '邀请码、邀请链接与返佣数据都集中在这里。',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  V3BackToAccount(
                    onTap: () => controller.goToPage(AppPage.account),
                  ),
                  IconButton(
                    tooltip: '刷新邀请数据',
                    onPressed: controller.refreshData,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              compact
                  ? Column(
                      children: [
                        _InviteHero(
                          code: active?.code ?? '',
                          link: active?.link ?? '',
                          currentIndex: safeIndex,
                          total: codes.length,
                          creating: _creating,
                          onPrevious: codes.length <= 1
                              ? null
                              : () => setState(() {
                                  _selected =
                                      (safeIndex - 1 + codes.length) %
                                      codes.length;
                                }),
                          onNext: codes.length <= 1
                              ? null
                              : () => setState(() {
                                  _selected = (safeIndex + 1) % codes.length;
                                }),
                          onCreate: _createCode,
                          onCopyCode: () => _copy(active?.code ?? '', '邀请码已复制'),
                          onCopyLink: () =>
                              _copy(active?.link ?? '', '邀请链接已复制'),
                        ),
                        const SizedBox(height: 16),
                        _InviteStats(controller: controller),
                      ],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          flex: 11,
                          child: _InviteHero(
                            code: active?.code ?? '',
                            link: active?.link ?? '',
                            currentIndex: safeIndex,
                            total: codes.length,
                            creating: _creating,
                            onPrevious: codes.length <= 1
                                ? null
                                : () => setState(() {
                                    _selected =
                                        (safeIndex - 1 + codes.length) %
                                        codes.length;
                                  }),
                            onNext: codes.length <= 1
                                ? null
                                : () => setState(() {
                                    _selected = (safeIndex + 1) % codes.length;
                                  }),
                            onCreate: _createCode,
                            onCopyCode: () =>
                                _copy(active?.code ?? '', '邀请码已复制'),
                            onCopyLink: () =>
                                _copy(active?.link ?? '', '邀请链接已复制'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 9,
                          child: _InviteStats(controller: controller),
                        ),
                      ],
                    ),
              const SizedBox(height: 16),
              _ReferralLedger(controller: controller),
            ],
          ),
        );
      },
    );
  }
}

class _InviteHero extends StatelessWidget {
  const _InviteHero({
    required this.code,
    required this.link,
    required this.currentIndex,
    required this.total,
    required this.creating,
    required this.onPrevious,
    required this.onNext,
    required this.onCreate,
    required this.onCopyCode,
    required this.onCopyLink,
  });

  final String code;
  final String link;
  final int currentIndex;
  final int total;
  final bool creating;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback onCreate;
  final VoidCallback onCopyCode;
  final VoidCallback onCopyLink;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    final hasCode = code.trim().isNotEmpty || link.trim().isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: p.night,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '分享邀请',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.6,
                ),
              ),
              const Spacer(),
              if (total > 0)
                Text(
                  '第 ${currentIndex + 1} 个，共 $total 个',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.42),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 28),
          Text(
            hasCode ? (code.trim().isEmpty ? 'LITCHI' : code.trim()) : '还没有邀请码',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            hasCode
                ? (link.trim().isEmpty ? '邀请码可直接分享给朋友' : link.trim())
                : '创建一个邀请码后，就可以开始邀请。',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 11,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 28),
          if (hasCode) ...[
            Row(
              children: [
                Expanded(
                  child: _HeroButton(
                    icon: Icons.copy_rounded,
                    label: '复制邀请码',
                    onTap: onCopyCode,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _HeroButton(
                    icon: Icons.link_rounded,
                    label: '复制链接',
                    onTap: onCopyLink,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
          Row(
            children: [
              IconButton(
                tooltip: '上一个邀请码',
                onPressed: onPrevious,
                icon: const Icon(Icons.chevron_left_rounded),
                color: Colors.white,
              ),
              IconButton(
                tooltip: '下一个邀请码',
                onPressed: onNext,
                icon: const Icon(Icons.chevron_right_rounded),
                color: Colors.white,
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: creating ? null : onCreate,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: p.night,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: creating
                    ? const SizedBox(
                        width: 15,
                        height: 15,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add_rounded, size: 18),
                label: Text(creating ? '创建中' : '新建邀请码'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroButton extends StatelessWidget {
  const _HeroButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
        padding: const EdgeInsets.symmetric(vertical: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      icon: Icon(icon, size: 17),
      label: Text(label),
    );
  }
}

class _InviteStats extends StatelessWidget {
  const _InviteStats({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    final symbol = controller.currencySymbol;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: p.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '邀请统计',
            style: TextStyle(
              color: p.inkMuted,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 18),
          _StatLine(
            label: '成功邀请',
            value: '${controller.invitedCount}',
            suffix: '人',
          ),
          _StatLine(
            label: '返佣比例',
            value: controller.commissionRate.toStringAsFixed(0),
            suffix: '%',
          ),
          _StatLine(
            label: '累计佣金',
            value: '$symbol${controller.earnedCommission.toStringAsFixed(2)}',
          ),
          _StatLine(
            label: '待确认',
            value: '$symbol${controller.pendingCommission.toStringAsFixed(2)}',
          ),
          const SizedBox(height: 22),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: p.lycheeSoft,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.account_balance_wallet_rounded,
                  color: p.lychee,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '可提现佣金',
                        style: TextStyle(color: p.inkMuted, fontSize: 10),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '$symbol${controller.withdrawable.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: p.ink,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: '前往钱包',
                  onPressed: () => controller.goToPage(AppPage.wallet),
                  icon: const Icon(Icons.arrow_forward_rounded),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatLine extends StatelessWidget {
  const _StatLine({required this.label, required this.value, this.suffix = ''});

  final String label;
  final String value;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: p.inkMuted, fontSize: 10),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: p.ink,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (suffix.isNotEmpty) ...[
            const SizedBox(width: 3),
            Text(suffix, style: TextStyle(color: p.inkMuted, fontSize: 10)),
          ],
        ],
      ),
    );
  }
}

class _ReferralLedger extends StatelessWidget {
  const _ReferralLedger({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    final records = controller.inviteRecords;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: p.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '最近邀请',
                style: TextStyle(
                  color: p.inkMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
              const Spacer(),
              Text(
                '${records.length} 条',
                style: TextStyle(color: p.inkMuted, fontSize: 10),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (records.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 26),
              child: Center(
                child: Text(
                  '还没有邀请记录',
                  style: TextStyle(color: p.inkMuted, fontSize: 11),
                ),
              ),
            )
          else
            for (final record in records.take(8))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: p.surfaceRaised,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.person_add_alt_1_rounded,
                        color: p.lychee,
                        size: 17,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            record.userName.trim().isEmpty
                                ? '新用户'
                                : record.userName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: p.ink,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            record.dateDisplay,
                            style: TextStyle(color: p.inkMuted, fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          record.commissionDisplay(controller.currencySymbol),
                          style: TextStyle(
                            color: p.successInk,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          record.amountDisplay(controller.currencySymbol),
                          style: TextStyle(color: p.inkMuted, fontSize: 10),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}
