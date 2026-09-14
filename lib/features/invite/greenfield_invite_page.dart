import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_controller.dart';
import '../../app/nav_destinations.dart';
import '../../l10n/l10n.dart';
import '../../shared/models/app_models.dart';
import '../../shared/widgets/app_toast.dart';
import '../../shared/widgets/responsive_page_scaffold.dart';
import 'widgets/greenfield_invite_surface.dart';

class GreenfieldInvitePage extends StatefulWidget {
  const GreenfieldInvitePage({super.key});

  @override
  State<GreenfieldInvitePage> createState() => _GreenfieldInvitePageState();
}

class _GreenfieldInvitePageState extends State<GreenfieldInvitePage> {
  int _selected = 0;
  bool _creating = false;

  List<InviteCodeModel> _invites(AppController controller) {
    if (controller.inviteCodes.isNotEmpty) return controller.inviteCodes;
    return [
      InviteCodeModel(
        code: controller.inviteCode.isEmpty ? '--' : controller.inviteCode,
        link: controller.inviteLink,
      ),
    ];
  }

  Future<void> _refresh() async {
    final controller = AppScope.of(context);
    await controller.refreshData();
    if (!mounted || controller.dataLoadError != null) return;
    AppToast.show(
      context,
      context.l10n.refreshed,
      type: AppToastType.success,
    );
  }

  Future<void> _createInviteCode() async {
    if (_creating) return;
    setState(() => _creating = true);
    final controller = AppScope.of(context);
    final error = await controller.createInviteCode();
    if (!mounted) return;
    setState(() {
      _creating = false;
      final count = _invites(controller).length;
      if (_selected >= count) _selected = count - 1;
    });
    AppToast.show(
      context,
      error ?? context.l10n.inviteCodeCreated,
      type: error == null ? AppToastType.success : AppToastType.error,
    );
  }

  Future<void> _copyLink(String link) async {
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
    if (!mounted) return;
    AppToast.show(
      context,
      context.l10n.copied,
      type: AppToastType.success,
    );
  }

  Future<void> _share(String link, _ShareTarget target) async {
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
    if (!mounted) return;
    final appName = switch (target) {
      _ShareTarget.wechat => context.l10n.wechat,
      _ShareTarget.qq => 'QQ',
      _ShareTarget.twitter => 'Twitter',
      _ShareTarget.telegram => 'Telegram',
    };
    AppToast.show(
      context,
      context.l10n.linkCopiedForApp(appName),
      type: AppToastType.success,
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final invites = _invites(controller);
    final safeSelected = _selected >= invites.length
        ? invites.length - 1
        : _selected;
    final invite = invites[safeSelected];

    void selectRelative(int delta) {
      final next = (safeSelected + delta + invites.length) % invites.length;
      setState(() => _selected = next);
    }

    final surface = GreenfieldInviteSurface(
      invite: invite,
      selectedIndex: safeSelected,
      inviteCount: invites.length,
      creating: _creating,
      registeredUsers: controller.invitedCount,
      pendingCommission:
          '${controller.currencySymbol}${controller.pendingCommission.toStringAsFixed(2)}',
      earnedCommission:
          '${controller.currencySymbol}${controller.earnedCommission.toStringAsFixed(2)}',
      commissionRate: '${controller.commissionRate.toStringAsFixed(0)}%',
      records: controller.inviteRecords,
      currencySymbol: controller.currencySymbol,
      onPrevious: () => selectRelative(-1),
      onNext: () => selectRelative(1),
      onCreate: _createInviteCode,
      onCopy: () => _copyLink(invite.link),
      onShareWechat: () => _share(invite.link, _ShareTarget.wechat),
      onShareQq: () => _share(invite.link, _ShareTarget.qq),
      onShareTwitter: () => _share(invite.link, _ShareTarget.twitter),
      onShareTelegram: () => _share(invite.link, _ShareTarget.telegram),
    );

    return ResponsivePageScaffold(
      title: context.l10n.inviteFriends,
      subtitle: context.l10n.inviteSubtitle,
      compactTitle: context.l10n.invite,
      compactSubtitle: context.l10n.inviteSubtitle,
      primaryCompact:
          isPrimaryCompactTab(AppPage.invite) &&
          !controller.mobileProfileChildPage,
      onRefresh: _refresh,
      onBack: () => controller.goToPage(AppPage.account),
      children: [surface],
    );
  }
}

enum _ShareTarget { wechat, qq, twitter, telegram }
