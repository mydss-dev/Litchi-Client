import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_controller.dart';
import '../../shared/models/app_models.dart';
import '../theme/v3_palette.dart';
import '../ui/v3_components.dart';
import '../ui/v3_layout.dart';
import '../ui/v3_locale_copy.dart';
import '../ui/v3_toast.dart';

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

  String _identity(InviteCodeModel item) => item.code.trim().isNotEmpty
      ? 'code:${item.code.trim()}' : 'link:${item.link.trim()}';

  int _activeIndex(List<InviteCodeModel> codes) {
    if (codes.isEmpty) return 0;
    if (_selectedIdentity != null) {
      final index = codes.indexWhere((item) => _identity(item) == _selectedIdentity);
      if (index >= 0) return index;
    }
    return _selected.clamp(0, codes.length - 1);
  }

  void _select(List<InviteCodeModel> codes, int index) {
    setState(() { _selected = index; _selectedIdentity = _identity(codes[index]); });
  }

  void _toast(String message, {V3ToastType type = V3ToastType.info}) {
    if (!mounted) return;
    V3Toast.show(context, message, type: type);
  }

  Future<void> _copy(String value, String message) async {
    if (value.trim().isEmpty) return;
    final copyFailure = v3Copy(context, zh: '复制失败，请重试',
      en: 'Copy failed. Please retry.', tw: '複製失敗，請重試');
    try {
      await Clipboard.setData(ClipboardData(text: value.trim()));
      _toast(message, type: V3ToastType.success);
    } catch (_) {
      _toast(copyFailure, type: V3ToastType.error);
    }
  }

  Future<void> _createCode() async {
    if (_creating) return;
    final controller = AppScope.read(context);
    final before = _codes(controller).map(_identity).toSet();
    final created = v3Copy(context, zh: '邀请码已创建',
      en: 'Invite code created', tw: '邀請碼已建立');
    final pending = v3Copy(context,
      zh: '创建请求已完成，邀请码尚未同步，请稍后刷新',
      en: 'Request completed, but the code has not synced. Refresh shortly.',
      tw: '建立請求已完成，但邀請碼尚未同步，請稍後重新整理');
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
      _toast(error, type: V3ToastType.error);
    } else if (added.isNotEmpty) {
      _toast(created, type: V3ToastType.success);
    } else {
      _toast(pending);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final codes = _codes(controller);
    final index = _activeIndex(codes);
    final active = codes.isEmpty ? null : codes[index];
    final hero = _InviteHero(
      code: active?.code ?? '', link: active?.link ?? '',
      currentIndex: index, total: codes.length, creating: _creating,
      onPrevious: codes.length <= 1 ? null
          : () => _select(codes, (index - 1 + codes.length) % codes.length),
      onNext: codes.length <= 1 ? null
          : () => _select(codes, (index + 1) % codes.length),
      onCreate: _createCode,
      onCopyCode: () => _copy(active?.code ?? '', v3Copy(context,
        zh: '邀请码已复制', en: 'Invite code copied', tw: '邀請碼已複製')),
      onCopyLink: () => _copy(active?.link ?? '', v3Copy(context,
        zh: '邀请链接已复制', en: 'Invite link copied', tw: '邀請連結已複製')),
      // One-tap share is a clipboard hand-off: copy the link and name the
      // destination, matching the hero's share-row comment.
      onShareTo: (target) => _copy(active?.link ?? '', v3Copy(context,
        zh: '链接已复制，去 $target 粘贴发送',
        en: 'Link copied — paste it in $target',
        tw: '連結已複製，貼到 $target 發送')),
    );
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: V3Layout.pageInsets,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        V3PageHeader(
          kicker: v3Copy(context, zh: '邀请奖励',
            en: 'REFERRAL REWARDS', tw: '邀請獎勵'),
          title: v3Copy(context, zh: '邀请好友',
            en: 'Invite friends', tw: '邀請好友'),
          description: v3Copy(context, zh: '复制邀请码或链接，分享给好友。',
            en: 'Copy your invite code or link and share it with friends.',
            tw: '複製邀請碼或連結並分享給好友。'),
          trailing: IconButton(tooltip: v3Copy(context, zh: '刷新邀请数据',
              en: 'Refresh invitations', tw: '重新整理邀請資料'),
            onPressed: controller.refreshData,
            icon: const Icon(Icons.refresh_rounded))),
        const SizedBox(height: 18),
        // Legacy rhythm, rebuilt in V3 language: full-width hero, then stats,
        // then the ledger. Splitting hero beside stats starves the code stage
        // (~370dp at 900x700) and cramps the link bar and share row.
        hero,
        const SizedBox(height: 16),
        _InviteStats(controller: controller),
        const SizedBox(height: 16),
        _ReferralLedger(controller: controller),
      ]),
    );
  }
}

class _InviteHero extends StatelessWidget {
  const _InviteHero({required this.code, required this.link,
    required this.currentIndex, required this.total, required this.creating,
    required this.onPrevious, required this.onNext, required this.onCreate,
    required this.onCopyCode, required this.onCopyLink,
    required this.onShareTo});
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
  final ValueChanged<String> onShareTo;

  // Fixed third-party brand hues for the share icons, like the country flags:
  // they identify the destination app, not Litchi's own palette. X stays
  // monochrome on purpose — its mark is black/white.
  static const _shareTargets = [
    (label: '微信', en: 'WeChat', tw: '微信',
      icon: Icons.chat_bubble_rounded, brand: Color(0xFF2AAE67)),
    (label: 'QQ', en: 'QQ', tw: 'QQ',
      icon: Icons.question_answer_rounded, brand: Color(0xFF12B7F5)),
    (label: 'Twitter', en: 'X', tw: 'Twitter',
      icon: Icons.tag_rounded, brand: null),
    (label: 'Telegram', en: 'Telegram', tw: 'Telegram',
      icon: Icons.send_rounded, brand: Color(0xFF27A7E5)),
  ];

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    final hasCode = code.trim().isNotEmpty;
    final hasLink = link.trim().isNotEmpty;
    return LayoutBuilder(builder: (context, box) {
      // Neutral hero ground, same material as the traffic quota panel and the
      // shell sidebar — brand color comes from the accents (gift tile, chips,
      // share icons), not from a tinted slab no other page uses.
      // Narrow panes (390dp phones, split panes) drop the header create
      // button; it returns as a full-width row below the code stage.
      final narrow = box.maxWidth < 520;
      return Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(color: p.hero,
          borderRadius: BorderRadius.circular(V3Radius.panel),
          border: Border.all(color: p.line)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 44, height: 44, alignment: Alignment.center,
              decoration: BoxDecoration(color: p.lychee,
                borderRadius: BorderRadius.circular(V3Radius.field)),
              child: const Icon(Icons.redeem_rounded, color: Colors.white,
                size: 22)),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min, children: [
                Text(v3Copy(context, zh: '分享邀请，好友注册即计入奖励',
                  en: 'Share and earn on every signup',
                  tw: '分享邀請，好友註冊即計入獎勵'),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: p.ink, fontSize: 14,
                    fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                Text(v3Copy(context, zh: '邀请链接与返佣进度都保存在本页',
                  en: 'Your link and commission progress live here',
                  tw: '邀請連結與返佣進度都保存在本頁'),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: p.inkMuted, fontSize: 11)),
              ])),
            if (!narrow) ...[
              const SizedBox(width: 14),
              _CreateButton(key: const ValueKey('v3-invite-create'),
                creating: creating, onCreate: onCreate),
            ],
          ]),
          const SizedBox(height: 18),
          // Code stage: the flanking arrows sit against the code, not in a
          // far corner — the carousel is the hero of this page.
          Row(children: [
            if (total > 1) IconButton(tooltip: v3Copy(context,
                zh: '上一个邀请码', en: 'Previous code', tw: '上一個邀請碼'),
              onPressed: onPrevious,
              icon: const Icon(Icons.chevron_left_rounded)),
            Expanded(child: Column(children: [
              Row(children: [
                Text(v3Copy(context, zh: '邀请码', en: 'Invite code',
                  tw: '邀請碼'),
                  style: TextStyle(color: p.inkMuted, fontSize: 11,
                    fontWeight: FontWeight.w800)),
                const Spacer(),
                if (total > 0)
                  Text('${currentIndex + 1} / $total',
                    style: TextStyle(color: p.inkMuted, fontSize: 11)),
              ]),
              const SizedBox(height: 10),
              Text(hasCode ? code.trim()
                  : hasLink ? v3Copy(context, zh: '后台未返回邀请码',
                      en: 'No code returned by the server', tw: '後台未傳回邀請碼')
                    : v3Copy(context, zh: '还没有邀请码',
                      en: 'No invite code yet', tw: '尚無邀請碼'),
                maxLines: 1, overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(color: hasCode ? p.ink : p.inkMuted,
                  fontSize: hasCode ? 28 : 17,
                  fontWeight: hasCode ? FontWeight.w900 : FontWeight.w600,
                  letterSpacing: hasCode ? .8 : 0)),
              const SizedBox(height: 12),
              OutlinedButton(
                key: const ValueKey('v3-invite-copy-code'),
                onPressed: hasCode ? onCopyCode : null,
                style: OutlinedButton.styleFrom(
                  foregroundColor: p.ink,
                  side: BorderSide(color: p.line),
                  minimumSize: const Size(0, 34),
                  padding: const EdgeInsets.symmetric(horizontal: 14)),
                child: Text(v3Copy(context, zh: '复制邀请码',
                  en: 'Copy code', tw: '複製邀請碼'),
                  style: const TextStyle(fontSize: 12))),
            ])),
            if (total > 1) IconButton(key: const ValueKey('v3-invite-next'),
              tooltip: v3Copy(context, zh: '下一个邀请码',
                en: 'Next code', tw: '下一個邀請碼'),
              onPressed: onNext,
              icon: const Icon(Icons.chevron_right_rounded)),
          ]),
          if (narrow) ...[
            const SizedBox(height: 14),
            SizedBox(width: double.infinity,
              child: _CreateButton(key: const ValueKey('v3-invite-create'),
                creating: creating, onCreate: onCreate)),
          ],
          const SizedBox(height: 14),
          // Link bar: the URL reads like an input, with its copy action
          // inline where the eye already is.
          Container(
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.fromLTRB(12, 6, 8, 6),
            decoration: BoxDecoration(color: p.surfaceRaised,
              borderRadius: BorderRadius.circular(V3Radius.field),
              border: Border.all(color: p.line)),
            child: Row(children: [
              Icon(Icons.link_rounded, size: 16, color: p.inkMuted),
              const SizedBox(width: 10),
              Expanded(child: Text(hasLink ? link.trim()
                  : hasCode ? v3Copy(context,
                      zh: '后台尚未提供邀请链接，可分享邀请码',
                      en: 'No link yet. You can share your invite code.',
                      tw: '後台尚未提供邀請連結，可分享邀請碼')
                    : v3Copy(context, zh: '创建邀请码后即可分享',
                      en: 'Create an invite code to start sharing',
                      tw: '建立邀請碼後即可分享'),
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(color: hasLink ? p.ink : p.inkMuted,
                  fontSize: 12))),
              const SizedBox(width: 10),
              OutlinedButton(
                key: const ValueKey('v3-invite-copy-link'),
                onPressed: hasLink ? onCopyLink : null,
                style: OutlinedButton.styleFrom(
                  foregroundColor: p.ink,
                  side: const BorderSide(color: Colors.transparent),
                  backgroundColor: p.surface,
                  minimumSize: const Size(0, 34),
                  padding: const EdgeInsets.symmetric(horizontal: 14)),
                child: Text(v3Copy(context, zh: '复制链接', en: 'Copy link',
                  tw: '複製連結'),
                  style: const TextStyle(fontSize: 12))),
            ])),
          const SizedBox(height: 14),
          // One-tap share: copies the link and tells the user where to paste
          // it. Desktop has no share sheet; the clipboard hand-off is the
          // share. Disabled while there is no link to hand off.
          Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Padding(padding: const EdgeInsets.only(right: 2),
                child: Text(v3Copy(context, zh: '分享到', en: 'Share to',
                  tw: '分享到'),
                  style: TextStyle(color: p.inkMuted, fontSize: 11))),
              for (final target in _shareTargets)
                OutlinedButton.icon(
                  onPressed: hasLink
                      ? () => onShareTo(v3Copy(context,
                          zh: target.label, en: target.en, tw: target.tw))
                      : null,
                  icon: Icon(target.icon, size: 15, color: target.brand),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: p.ink,
                    side: BorderSide(color: p.line),
                    minimumSize: const Size(0, 34),
                    padding: const EdgeInsets.symmetric(horizontal: 12)),
                  label: Text(v3Copy(context, zh: target.label,
                    en: target.en, tw: target.tw),
                    style: const TextStyle(fontSize: 12))),
            ]),
        ]),
      );
    });
  }
}

class _CreateButton extends StatelessWidget {
  const _CreateButton({super.key, required this.creating, required this.onCreate});
  final bool creating;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return FilledButton.icon(
      onPressed: creating ? null : onCreate,
      style: FilledButton.styleFrom(backgroundColor: p.lychee,
        foregroundColor: Colors.white),
      icon: creating ? const SizedBox(width: 16, height: 16,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
        : const Icon(Icons.add_rounded, size: 18),
      label: Text(creating ? v3Copy(context, zh: '创建中', en: 'Creating',
        tw: '建立中')
        : v3Copy(context, zh: '新建邀请码', en: 'New invite code',
          tw: '建立邀請碼')));
  }
}

class _InviteStats extends StatelessWidget {
  const _InviteStats({required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    final symbol = controller.currencySymbol;
    final entries = [
      (label: v3Copy(context, zh: '邀请人数', en: 'Friends invited',
          tw: '邀請人數'),
        value: '${controller.invitedCount}',
        suffix: v3Copy(context, zh: '人', en: ' people', tw: '人'),
        positive: false),
      (label: v3Copy(context, zh: '返佣比例', en: 'Commission rate',
          tw: '返佣比例'),
        value: controller.commissionRate.toStringAsFixed(0), suffix: '%',
        positive: false),
      (label: v3Copy(context, zh: '累计佣金', en: 'Total commission',
          tw: '累計佣金'),
        value: '$symbol${controller.earnedCommission.toStringAsFixed(2)}',
        suffix: '', positive: false),
      (label: v3Copy(context, zh: '待确认佣金', en: 'Pending commission',
          tw: '待確認佣金'),
        value: '$symbol${controller.pendingCommission.toStringAsFixed(2)}',
        suffix: '', positive: false),
      // Withdrawable balance is the one number the user can act on — green
      // marks it as money in hand, not just a counter.
      (label: v3Copy(context, zh: '可提现佣金', en: 'Withdrawable',
          tw: '可提領佣金'),
        value: '$symbol${controller.withdrawable.toStringAsFixed(2)}',
        suffix: '', positive: controller.withdrawable > 0),
    ];
    // Same tile material as the traffic page's stat band: separate cards on
    // the canvas. The inset panel with hairline dividers read as a different
    // system from every other page.
    return LayoutBuilder(builder: (context, box) {
      final tiles = <Widget>[
        for (final entry in entries)
          Container(padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: p.surface,
              borderRadius: BorderRadius.circular(V3Radius.card),
              border: Border.all(color: p.line)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min, children: [
                Text(entry.label, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: p.inkMuted, fontSize: 10)),
                const SizedBox(height: 6),
                Row(mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Flexible(child: Text(entry.value, maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: entry.positive
                        ? p.successInk : p.ink, fontSize: 16,
                        fontWeight: FontWeight.w900))),
                    if (entry.suffix.isNotEmpty) ...[
                      const SizedBox(width: 3),
                      Text(entry.suffix,
                        style: TextStyle(color: p.inkMuted, fontSize: 10)),
                    ],
                  ]),
              ])),
      ];
      final cols = box.maxWidth >= V3Layout.paneCompact ? 5 : 2;
      return Column(children: [
        for (var i = 0; i < tiles.length; i += cols) ...[
          if (i > 0) const SizedBox(height: 12),
          Row(children: [
            for (var j = i; j < (i + cols).clamp(0, tiles.length); j++) ...[
              if (j > i) const SizedBox(width: 12),
              Expanded(child: tiles[j]),
            ],
          ]),
        ],
      ]);
    });
  }
}

class _ReferralLedger extends StatelessWidget {
  const _ReferralLedger({required this.controller});
  final AppController controller;
  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    final records = controller.inviteRecords;
    return V3Panel(padding: const EdgeInsets.all(20), radius: V3Radius.panel,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(v3Copy(context,
            zh: '最近返佣记录', en: 'RECENT COMMISSIONS', tw: '最近返佣紀錄'),
            style: TextStyle(color: p.inkMuted, fontSize: 11,
              fontWeight: FontWeight.w900, letterSpacing: 1.1))),
          Text(v3Copy(context, zh: '${records.length} 条',
            en: '${records.length} entries', tw: '${records.length} 筆'),
            style: TextStyle(color: p.inkMuted, fontSize: 11)),
        ]),
        const SizedBox(height: 12),
        if (records.isEmpty)
          Padding(padding: const EdgeInsets.symmetric(vertical: 26),
            child: Center(child: Text(v3Copy(context, zh: '暂无返佣记录',
              en: 'No commission records', tw: '暫無返佣紀錄'),
              style: TextStyle(color: p.inkMuted, fontSize: 12))))
        else for (final record in records.take(8))
          Padding(padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(children: [
              Container(width: 36, height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: p.surfaceRaised,
                  borderRadius: BorderRadius.circular(V3Radius.field)),
                child: Icon(Icons.person_add_alt_1_rounded,
                  color: p.lycheeInk, size: 17)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(record.userName.trim().isEmpty
                      ? v3Copy(context, zh: '新用户', en: 'New user', tw: '新用戶')
                      : record.userName,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: p.ink, fontSize: 11,
                      fontWeight: FontWeight.w800)),
                  const SizedBox(height: 3),
                  Text(record.dateDisplay,
                    style: TextStyle(color: p.inkMuted, fontSize: 10)),
                ])),
              const SizedBox(width: 8),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(record.commissionDisplay(controller.currencySymbol),
                  style: TextStyle(color: p.successInk, fontSize: 11,
                    fontWeight: FontWeight.w900)),
                const SizedBox(height: 3),
                Text(record.amountDisplay(controller.currencySymbol),
                  style: TextStyle(color: p.inkMuted, fontSize: 10)),
              ]),
            ])),
      ]),
    );
  }
}
