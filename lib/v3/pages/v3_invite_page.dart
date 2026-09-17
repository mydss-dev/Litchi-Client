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
  String? _selectedIdentity;
  bool _creating = false;

  List<InviteCodeModel> _codes(AppController controller) {
    if (controller.inviteCodes.isNotEmpty) return controller.inviteCodes;
    final code = controller.inviteCode.trim();
    final link = controller.inviteLink.trim();
    if (code.isEmpty && link.isEmpty) return const [];
    return [InviteCodeModel(code: code, link: link)];
  }

  // A refresh may reorder the list. Preserve what the user picked by its
  // actual identity, not an index that might now refer to a different code.
  String _identity(InviteCodeModel item) => item.code.trim().isNotEmpty
      ? 'code:${item.code.trim()}'
      : 'link:${item.link.trim()}';

  int _activeIndex(List<InviteCodeModel> codes) {
    if (codes.isEmpty) return 0;
    if (_selectedIdentity != null) {
      final index = codes.indexWhere((item) => _identity(item) == _selectedIdentity);
      if (index >= 0) return index;
    }
    return _selected.clamp(0, codes.length - 1);
  }

  void _select(List<InviteCodeModel> codes, int index) {
    setState(() {
      _selected = index;
      _selectedIdentity = _identity(codes[index]);
    });
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _copy(String value, String message) async {
    if (value.trim().isEmpty) return;
    try {
      await Clipboard.setData(ClipboardData(text: value.trim()));
      _toast(message);
    } catch (_) {
      _toast('复制失败，请重试');
    }
  }

  Future<void> _createCode() async {
    if (_creating) return;
    final controller = AppScope.read(context);
    final before = _codes(controller).map(_identity).toSet();
    setState(() => _creating = true);
    final error = await controller.createInviteCode();
    if (!mounted) return;
    final after = _codes(controller);
    final added = error == null
        ? after.where((item) => !before.contains(_identity(item))).toList()
        : <InviteCodeModel>[];
    setState(() {
      _creating = false;
      if (added.isNotEmpty) {
        _selectedIdentity = _identity(added.last);
        _selected = after.indexWhere((item) => _identity(item) == _selectedIdentity);
      } else {
        _selected = _activeIndex(after);
      }
    });
    if (error != null) {
      _toast(error);
    } else if (added.isNotEmpty) {
      _toast('邀请码已创建');
    } else {
      _toast('创建请求已完成，邀请码尚未同步，请稍后刷新');
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final codes = _codes(controller);
    final index = _activeIndex(codes);
    final active = codes.isEmpty ? null : codes[index];
    final hero = _InviteHero(
      code: active?.code ?? '',
      link: active?.link ?? '',
      currentIndex: index,
      total: codes.length,
      creating: _creating,
      onPrevious: codes.length <= 1
          ? null
          : () => _select(codes, (index - 1 + codes.length) % codes.length),
      onNext: codes.length <= 1
          ? null
          : () => _select(codes, (index + 1) % codes.length),
      onCreate: _createCode,
      onCopyCode: () => _copy(active?.code ?? '', '邀请码已复制'),
      onCopyLink: () => _copy(active?.link ?? '', '邀请链接已复制'),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 26, 24, 36),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              V3PageHeader(
                kicker: '邀请奖励',
                title: '邀请好友',
                description: '复制邀请码或链接，分享给好友。',
                trailing: IconButton(
                  tooltip: '刷新邀请数据',
                  onPressed: controller.refreshData,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ),
              const SizedBox(height: 20),
              if (compact)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    hero,
                    const SizedBox(height: 16),
                    _InviteStats(controller: controller),
                  ],
                )
              else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 11, child: hero),
                    const SizedBox(width: 16),
                    Expanded(flex: 9, child: _InviteStats(controller: controller)),
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
    final hasCode = code.trim().isNotEmpty;
    final hasLink = link.trim().isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: p.hero,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: p.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text('分享邀请', style: TextStyle(color: p.inkMuted, fontSize: 11,
                fontWeight: FontWeight.w900, letterSpacing: 1.2)),
            const Spacer(),
            if (total > 0)
              Text('${currentIndex + 1} / $total',
                  style: TextStyle(color: p.inkMuted, fontSize: 11)),
          ]),
          const SizedBox(height: 18),
          Text('邀请码', style: TextStyle(color: p.inkMuted, fontSize: 11)),
          const SizedBox(height: 7),
          Text(
            hasCode ? code.trim() : (hasLink ? '后台未返回邀请码' : '还没有邀请码'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: p.ink, fontSize: hasCode ? 27 : 19,
                fontWeight: FontWeight.w900, letterSpacing: hasCode ? 0.8 : 0),
          ),
          const SizedBox(height: 16),
          Text('邀请链接', style: TextStyle(color: p.inkMuted, fontSize: 11)),
          const SizedBox(height: 5),
          Text(
            hasLink ? link.trim() : (hasCode ? '后台尚未提供邀请链接，可分享邀请码' : '创建邀请码后即可分享'),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: p.inkMuted, fontSize: 12, height: 1.5),
          ),
          const SizedBox(height: 18),
          Row(children: [
            Expanded(child: OutlinedButton.icon(
              key: const ValueKey('v3-invite-copy-code'),
              onPressed: hasCode ? onCopyCode : null,
              icon: const Icon(Icons.copy_rounded, size: 16),
              label: const Text('复制邀请码'),
            )),
            const SizedBox(width: 10),
            Expanded(child: OutlinedButton.icon(
              key: const ValueKey('v3-invite-copy-link'),
              onPressed: hasLink ? onCopyLink : null,
              icon: const Icon(Icons.link_rounded, size: 16),
              label: const Text('复制链接'),
            )),
          ]),
          const SizedBox(height: 14),
          Row(children: [
            if (total > 1) ...[
              IconButton(
                tooltip: '上一个邀请码',
                onPressed: onPrevious,
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              IconButton(
                key: const ValueKey('v3-invite-next'),
                tooltip: '下一个邀请码',
                onPressed: onNext,
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
            const Spacer(),
            FilledButton.icon(
              key: const ValueKey('v3-invite-create'),
              onPressed: creating ? null : onCreate,
              style: FilledButton.styleFrom(
                backgroundColor: p.lychee,
                foregroundColor: Colors.white,
              ),
              icon: creating
                  ? const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.add_rounded, size: 18),
              label: Text(creating ? '创建中' : '新建邀请码'),
            ),
          ]),
        ],
      ),
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
    return V3Panel(
      padding: const EdgeInsets.all(20),
      radius: 26,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('邀请统计', style: TextStyle(color: p.inkMuted, fontSize: 11,
            fontWeight: FontWeight.w900, letterSpacing: 1.2)),
        const SizedBox(height: 15),
        _StatLine(label: '邀请人数', value: '${controller.invitedCount}', suffix: '人'),
        _StatLine(label: '返佣比例', value: controller.commissionRate.toStringAsFixed(0), suffix: '%'),
        Divider(color: p.line, height: 18),
        _StatLine(label: '累计佣金',
            value: '$symbol${controller.earnedCommission.toStringAsFixed(2)}'),
        _StatLine(label: '待确认佣金',
            value: '$symbol${controller.pendingCommission.toStringAsFixed(2)}'),
        _StatLine(label: '可提现佣金',
            value: '$symbol${controller.withdrawable.toStringAsFixed(2)}'),
        const SizedBox(height: 10),
        Text('统计与返佣金额以服务端数据为准',
            style: TextStyle(color: p.inkMuted, fontSize: 10)),
      ]),
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
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        Expanded(child: Text(label, style: TextStyle(color: p.inkMuted, fontSize: 11))),
        Text(value, style: TextStyle(color: p.ink, fontSize: 16, fontWeight: FontWeight.w900)),
        if (suffix.isNotEmpty) ...[
          const SizedBox(width: 3),
          Text(suffix, style: TextStyle(color: p.inkMuted, fontSize: 10)),
        ],
      ]),
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
    return V3Panel(
      padding: const EdgeInsets.all(20),
      radius: 26,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('最近返佣记录', style: TextStyle(color: p.inkMuted,
              fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.1))),
          Text('${records.length} 条', style: TextStyle(color: p.inkMuted, fontSize: 11)),
        ]),
        const SizedBox(height: 12),
        if (records.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 26),
            child: Center(child: Text('暂无返佣记录',
                style: TextStyle(color: p.inkMuted, fontSize: 12))),
          )
        else
          for (final record in records.take(8))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(children: [
                Container(
                  width: 36, height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: p.surfaceRaised,
                      borderRadius: BorderRadius.circular(12)),
                  child: Icon(Icons.person_add_alt_1_rounded,
                      color: p.lycheeInk, size: 17),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(record.userName.trim().isEmpty ? '新用户' : record.userName,
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: p.ink, fontSize: 11,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 3),
                    Text(record.dateDisplay,
                        style: TextStyle(color: p.inkMuted, fontSize: 10)),
                  ],
                )),
                const SizedBox(width: 8),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(record.commissionDisplay(controller.currencySymbol),
                      style: TextStyle(color: p.successInk, fontSize: 11,
                          fontWeight: FontWeight.w900)),
                  const SizedBox(height: 3),
                  Text(record.amountDisplay(controller.currencySymbol),
                      style: TextStyle(color: p.inkMuted, fontSize: 10)),
                ]),
              ]),
            ),
      ]),
    );
  }
}
