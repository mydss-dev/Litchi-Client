import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../app/plan_presentation.dart';
import '../app/v3_nav.dart';
import '../../config/app_config.dart';
import '../commerce/v3_order_dialog.dart';
import '../theme/v3_motion.dart';
import '../theme/v3_palette.dart';
import '../ui/v3_account_labels.dart';
import '../ui/v3_components.dart';
import '../ui/v3_empty_state.dart';
import '../ui/v3_layout.dart';
import '../ui/v3_locale_copy.dart';
import '../ui/v3_mobile_components.dart';
import '../ui/v3_logout_confirmation.dart';
import '../ui/v3_plan_labels.dart';
import '../ui/v3_sheet.dart';
import '../ui/v3_toast.dart';
import 'v3_telegram_page.dart';
import 'v3_wallet_actions.dart';

/// Account layout: identity/plan hero, wallet, then preferences and security
/// — all directly visible. Do not turn the account into a collapsed menu.
///
/// Compact surfaces are the exception (§13.3): 我的 is the phone workspace's
/// data center, so the five overflow surfaces (订单 / 用量 / 工单 / 邀请 /
/// 设置) reappear as one quiet long-row list. Desktop keeps none of them —
/// the rail owns navigation there (§13.4).

/// Compact targets get the hub rows; desktop keeps the rail-only account.
bool get _usesCompactAccountHub =>
    !kIsWeb &&
    switch (defaultTargetPlatform) {
      TargetPlatform.android || TargetPlatform.iOS => true,
      _ => false,
    };
/// Telegram binding is a bottom action; redemption lives in the window bar
/// (desktop) or the compact 更多 list (mobile).
class V3AccountPage extends StatefulWidget {
  const V3AccountPage({super.key});
  @override
  State<V3AccountPage> createState() => _V3AccountPageState();
}

class _V3AccountPageState extends State<V3AccountPage> {
  bool _updatingPreferences = false;
  bool _refreshing = false;

  /// Header refresh with in-flight feedback: the icon becomes an 18px
  /// spinner and the button disables until the await settles. refreshData
  /// is single-flight and swallows failures internally; the dataLoadError
  /// strip at the bottom reports them.
  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      await AppScope.read(context).refreshData();
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<void> _updatePreferences({
    bool? remindExpire,
    bool? remindTraffic,
    bool? autoRenewal,
  }) async {
    if (_updatingPreferences) return;
    final controller = AppScope.read(context);
    setState(() => _updatingPreferences = true);
    try {
      final error = await controller.updateUserSettings(
        remindExpire: remindExpire ?? controller.user.remindExpire,
        remindTraffic: remindTraffic ?? controller.user.remindTraffic,
        autoRenewal: autoRenewal ?? controller.user.autoRenewal,
      );
      if (!mounted) return;
      V3Toast.show(
        context,
        error ??
            v3Copy(
              context,
              zh: '账户设置已更新',
              en: 'Account preferences updated',
              tw: '帳戶設定已更新',
            ),
        type: error == null ? V3ToastType.success : V3ToastType.error,
      );
    } catch (error) {
      if (mounted) {
        // The raw exception must not leak into the toast: the shared mapping
        // unwraps and localizes the failure (N13).
        final detail = v3UserFacingError(context, error);
        V3Toast.show(
          context,
          v3Copy(
            context,
            zh: '更新账户偏好失败：$detail',
            en: 'Could not update account preferences: $detail',
            tw: '更新帳戶偏好失敗：$detail',
          ),
          type: V3ToastType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _updatingPreferences = false);
    }
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showV3LogoutConfirmation(context);
    if (!confirmed || !mounted) return;
    await AppScope.read(context).logout();
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    if (_usesCompactAccountHub) {
      return _MobileAccountOverview(
        controller: controller,
        refreshing: _refreshing,
        preferencesBusy: _updatingPreferences,
        onRefresh: _refresh,
        onExpireChanged: (v) => _updatePreferences(remindExpire: v),
        onTrafficChanged: (v) => _updatePreferences(remindTraffic: v),
        onAutoRenewalChanged: (v) => _updatePreferences(autoRenewal: v),
        onPassword: () => showGeneralDialog<void>(
          transitionBuilder: v3PopTransition,
          transitionDuration: V3Motion.medium,
          barrierDismissible: true,
          barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
          context: context,
          barrierColor: Colors.black.withValues(alpha: .48),
          pageBuilder: (_, _, _) => const _PasswordDialog(),
        ),
        onTelegram: () => V3TelegramPage.show(context),
        onLogout: _confirmLogout,
      );
    }
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: V3Layout.pageInsets,
      child: V3WaveColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          V3PageHeader(
            title: v3Copy(context, zh: '我的', en: 'Account', tw: '我的'),
            subtitle: v3Copy(
              context,
              zh: '账户信息 · 偏好 · 安全',
              en: 'Account · Preferences · Security',
              tw: '帳戶資訊 · 偏好 · 安全',
            ),
            trailing: IconButton(
              tooltip: v3Copy(
                context,
                zh: '刷新账户数据',
                en: 'Refresh account',
                tw: '重新整理帳戶資料',
              ),
              onPressed: _refreshing ? null : _refresh,
              icon: _refreshing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh_rounded),
            ),
          ),
          const SizedBox(height: 18),
          _AccountSummaryPanel(controller: controller),
          if (AppConfig.panelFeatures.wallet ||
              controller.user.balance > 0 ||
              controller.withdrawable > 0) ...[
            const SizedBox(height: 16),
            const _WalletPanel(),
          ],
          if (_usesCompactAccountHub) ...[
            const SizedBox(height: 16),
            _AccountHubRows(controller: controller),
          ],
          if (controller.hasPlan) ...[
            const SizedBox(height: 16),
            _PreferencesPanel(
              controller: controller,
              busy: _updatingPreferences,
              onExpireChanged: (v) => _updatePreferences(remindExpire: v),
              onTrafficChanged: (v) => _updatePreferences(remindTraffic: v),
              onAutoRenewalChanged: (v) => _updatePreferences(autoRenewal: v),
            ),
          ],
          const SizedBox(height: 16),
          _AccountActions(
            onPassword: () => showGeneralDialog<void>(
              transitionBuilder: v3PopTransition,
              transitionDuration: V3Motion.medium,
              barrierDismissible: true,
              barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
              context: context,
              barrierColor: Colors.black.withValues(alpha: .48),
              pageBuilder: (_, _, _) => const _PasswordDialog(),
            ),
            onTelegram: () => V3TelegramPage.show(context),
            onLogout: _confirmLogout,
          ),
          if (controller.dataLoadError != null) ...[
            const SizedBox(height: 16),
            // Same failure voice as the tickets and orders pages (icon tile,
            // one muted line, one retry step) instead of a private yellow
            // strip.
            V3EmptyState(
              icon: Icons.error_outline_rounded,
              title: v3Copy(
                context,
                zh: '账户信息加载失败',
                en: 'Could not load account info',
                tw: '帳戶資訊載入失敗',
              ),
              subtitle: controller.dataLoadError!,
              actionLabel: v3Copy(context, zh: '重试', en: 'Retry', tw: '重試'),
              onAction: controller.refreshData,
            ),
          ],
        ],
      ),
    );
  }
}


void _openAccountPlan(BuildContext context, AppController controller) {
  if (!controller.hasPlan) {
    controller.goToPage(AppPage.shop);
    return;
  }
  for (final plan in controller.plans) {
    if (int.tryParse(plan.id) == controller.currentPlanId) {
      showV3OrderDialog(
        context: context,
        plan: plan,
        initialCycle: v3DefaultCycle(plan),
        api: controller.api,
        currencySymbol: controller.currencySymbol,
        onPaid: controller.refreshData,
        onViewOrders: () => openV3Page(context, AppPage.orders),
      );
      return;
    }
  }
  controller.goToPage(AppPage.shop);
}

/// Phone account layout. The desktop workspace retains its original panels.
/// This page intentionally uses low-elevation surfaces and one calm type scale;
/// money movement, preferences and security still call the existing handlers.

class _MobileAccountOverview extends StatelessWidget {
  const _MobileAccountOverview({
    required this.controller,
    required this.refreshing,
    required this.preferencesBusy,
    required this.onRefresh,
    required this.onExpireChanged,
    required this.onTrafficChanged,
    required this.onAutoRenewalChanged,
    required this.onPassword,
    required this.onTelegram,
    required this.onLogout,
  });

  final AppController controller;
  final bool refreshing;
  final bool preferencesBusy;
  final VoidCallback onRefresh;
  final ValueChanged<bool> onExpireChanged;
  final ValueChanged<bool> onTrafficChanged;
  final ValueChanged<bool> onAutoRenewalChanged;
  final VoidCallback onPassword;
  final VoidCallback onTelegram;
  final VoidCallback onLogout;


  void _showManage(BuildContext context) {
    final p = V3Palette.of(context);
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: p.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) => ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(sheetContext).height * .78),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 26),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 36, height: 4,
              decoration: BoxDecoration(color: p.line,
                borderRadius: BorderRadius.circular(99)))),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: Text(v3Copy(sheetContext,
                zh: '账户管理', en: 'Manage account', tw: '帳戶管理'),
                style: TextStyle(color: p.ink,
                  fontSize: 20, fontWeight: FontWeight.w800))),
              IconButton(
                tooltip: v3Copy(sheetContext,
                    zh: '关闭', en: 'Close', tw: '關閉'),
                onPressed: () => Navigator.of(sheetContext).pop(),
                icon: Icon(Icons.close_rounded, color: p.inkMuted)),
            ]),
            if (controller.hasPlan) ...[
              _MobileGroupLabel(v3Copy(sheetContext,
                zh: '偏好', en: 'PREFERENCES', tw: '偏好')),
              _MobilePreference(
                title: v3Copy(sheetContext, zh: '到期提醒',
                  en: 'Expiry reminder', tw: '到期提醒'),
                subtitle: v3Copy(sheetContext, zh: '到期前通知',
                  en: 'Before expiry', tw: '到期前通知'),
                value: controller.user.remindExpire,
                onChanged: preferencesBusy ? null : onExpireChanged),
              const _MobileHairline(indent: 10),
              _MobilePreference(
                title: v3Copy(sheetContext, zh: '流量提醒',
                  en: 'Traffic reminder', tw: '流量提醒'),
                subtitle: v3Copy(sheetContext, zh: '流量不足时通知',
                  en: 'When data is low', tw: '流量不足時通知'),
                value: controller.user.remindTraffic,
                onChanged: preferencesBusy ? null : onTrafficChanged),
              const _MobileHairline(indent: 10),
              _MobilePreference(
                title: v3Copy(sheetContext, zh: '自动续费',
                  en: 'Auto-renewal', tw: '自動續費'),
                subtitle: v3Copy(sheetContext, zh: '符合条件时自动续费',
                  en: 'Renew when eligible', tw: '符合條件時自動續費'),
                value: controller.user.autoRenewal,
                onChanged: preferencesBusy ? null : onAutoRenewalChanged),
            ],
            const SizedBox(height: 10),
            _MobileGroupLabel(v3Copy(sheetContext,
              zh: '安全', en: 'SECURITY', tw: '安全')),
            _MobileAccountLink(
              icon: Icons.tune_rounded,
              title: v3Copy(sheetContext, zh: '应用设置',
                en: 'App settings', tw: '應用設定'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                controller.goToPage(AppPage.settings);
              }),
            const _MobileHairline(indent: 10),
            _MobileAccountLink(
              icon: Icons.lock_outline_rounded,
              title: v3Copy(sheetContext, zh: '修改密码',
                en: 'Change password', tw: '修改密碼'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                onPassword();
              }),
            const _MobileHairline(indent: 10),
            _MobileAccountLink(
              key: const ValueKey('v3-account-telegram'),
              icon: Icons.send_outlined,
              title: v3Copy(sheetContext, zh: 'Telegram 绑定',
                en: 'Telegram', tw: 'Telegram 綁定'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                onTelegram();
              }),
            const _MobileHairline(indent: 10),
            _MobileAccountLink(
              icon: Icons.logout_rounded,
              title: v3Copy(sheetContext, zh: '退出登录',
                en: 'Sign out', tw: '登出'),
              danger: true,
              onTap: () {
                Navigator.of(sheetContext).pop();
                onLogout();
              }),
          ]),
        ),
      ),
    );
  }

  /// Transcribed from elegant_mockup.html account .ac-profile / .ac-wallet /
  /// .ac-grid / .ac-group: a 12dp rhythm rather than the previous 57dp menu
  /// stack. Every service tile is still wired to the existing controller.
  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    final walletVisible = AppConfig.panelFeatures.wallet ||
        controller.user.balance > 0 || controller.withdrawable > 0;
    final remain = controller.traffic.remainGb;
    final total = controller.traffic.totalGb;
    final used = controller.traffic.usedGb;
    final ticketsOpen = controller.tickets.where((t) => t.isOpen).length;
    final symbol = controller.currencySymbol;
    final recent = controller.hasAccountSummary
        ? '${remain.toStringAsFixed(1)} GB' : '—';
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 110),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        V3PageHeader(
          title: v3Copy(context, zh: '我的', en: 'Account', tw: '我的'),
          subtitle: v3Copy(context, zh: '账户信息 · 偏好 · 安全',
              en: 'Account · Preferences · Security',
              tw: '帳戶資訊 · 偏好 · 安全'),
          trailing: IconButton(
            tooltip: v3Copy(context, zh: '刷新账户数据',
              en: 'Refresh account', tw: '重新整理帳戶資料'),
            onPressed: refreshing ? null : onRefresh,
            icon: refreshing
                ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Icon(Icons.refresh_rounded, color: p.inkMuted, size: 19),
          ),
        ),
        const SizedBox(height: 14),
        _MobileIdentityCard(
          controller: controller,
          onManage: () => _showManage(context),
        ),
        const SizedBox(height: 12),
        _MobilePlanCard(controller: controller),
        const SizedBox(height: 18),
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(v3Copy(context, zh: '账户服务',
            en: 'Account services', tw: '帳戶服務'),
            style: TextStyle(color: p.inkMuted,
              fontSize: 12, fontWeight: FontWeight.w700)),
        ),
        _MobileSurface(
          padding: const EdgeInsets.all(12),
          child: Column(children: [
            Row(children: [
              Expanded(child: V3MobileHubTile(
                key: hubRowKey(AppPage.orders),
                icon: Icons.receipt_long_outlined,
                title: v3Copy(context, zh: '订单', en: 'Orders', tw: '訂單'),
                value: v3Copy(context, zh: '订单记录',
                  en: 'Order history', tw: '訂單紀錄'),
                subtitle: v3Copy(context, zh: '支付记录与详情',
                  en: 'Payment history', tw: '付款紀錄與詳情'),
                onTap: () => openV3Page(context, AppPage.orders),
              )),
              const SizedBox(width: 10),
              Expanded(child: V3MobileHubTile(
                key: hubRowKey(AppPage.traffic),
                icon: Icons.data_usage_outlined,
                title: v3Copy(context, zh: '流量',
                    en: 'Traffic', tw: '流量'),
                value: recent,
                subtitle: total > 0
                    ? v3Copy(context,
                        zh: '已用 ${used.toStringAsFixed(1)} GB',
                        en: 'Used ${used.toStringAsFixed(1)} GB',
                        tw: '已用 ${used.toStringAsFixed(1)} GB')
                    : v3Copy(context, zh: '查看使用情况',
                        en: 'View usage', tw: '查看用量'),
                onTap: () => openV3Page(context, AppPage.traffic),
                footer: total <= 0 ? null : ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: (used / total).clamp(0.0, 1.0),
                    minHeight: 4,
                    backgroundColor: p.line,
                    valueColor: AlwaysStoppedAnimation(p.success),
                  ),
                ),
              )),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: V3MobileHubTile(
                key: hubRowKey(AppPage.tickets),
                icon: Icons.chat_bubble_outline_rounded,
                title: v3Copy(context, zh: '工单', en: 'Support', tw: '工單'),
                value: controller.ticketsLoaded
                    ? '$ticketsOpen' : '—',
                subtitle: v3Copy(context, zh: '待处理工单',
                    en: 'Open tickets', tw: '待處理工單'),
                onTap: () => openV3Page(context, AppPage.tickets),
              )),
              const SizedBox(width: 10),
              Expanded(child: V3MobileHubTile(
                key: hubRowKey(AppPage.invite),
                icon: Icons.people_outline_rounded,
                title: v3Copy(context, zh: '邀请',
                    en: 'Invite', tw: '邀請'),
                value: '$symbol${controller.earnedCommission.toStringAsFixed(2)}',
                subtitle: v3Copy(context, zh: '累计佣金',
                    en: 'Commission', tw: '累計佣金'),
                onTap: () => openV3Page(context, AppPage.invite),
              )),
            ]),
          ]),
        ),

        if (walletVisible) ...[
          const SizedBox(height: 10),
          V3MobileHubTile(
            icon: Icons.account_balance_wallet_outlined,
            title: v3Copy(context, zh: '钱包',
              en: 'Wallet', tw: '錢包'),
            value: v3Copy(context, zh: '我的钱包',
              en: 'My wallet', tw: '我的錢包'),
            subtitle: v3Copy(context, zh: '余额 · 提现 · 划转',
              en: 'Balance · Withdraw · Transfer',
              tw: '餘額 · 提領 · 轉帳'),
            onTap: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => const _MobileWalletPage())),
          ),
        ],
        if (controller.dataLoadError != null) ...[
          const SizedBox(height: 12),
          V3EmptyState(
            icon: Icons.error_outline_rounded,
            title: v3Copy(context, zh: '账户加载失败',
                en: 'Could not load account', tw: '帳戶載入失敗'),
            subtitle: controller.dataLoadError!,
            actionLabel: v3Copy(context, zh: '重试',
                en: 'Retry', tw: '重試'),
            onAction: controller.refreshData,
          ),
        ],
      ]),
    );
  }
}

class _MobileGroupLabel extends StatelessWidget {
  const _MobileGroupLabel(this.value);
  final String value;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 5),
      child: Text(value, style: TextStyle(color: p.inkMuted,
        fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 1.4)),
    );
  }
}

class _MobileSurface extends StatelessWidget {
  const _MobileSurface({required this.child, this.padding = const EdgeInsets.all(18)});
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: p.line.withValues(alpha: .72)),
      ),
      child: child,
    );
  }
}



class _MobileIdentityCard extends StatelessWidget {
  const _MobileIdentityCard({
    required this.controller,
    required this.onManage,
  });
  final AppController controller;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    final user = controller.user;
    final letter = user.avatarLetter.trim().isEmpty
        ? 'L' : user.avatarLetter.trim().substring(0, 1).toUpperCase();

    return _MobileSurface(
      padding: const EdgeInsets.all(14),
      child: Row(children: [
        CircleAvatar(radius: 21, backgroundColor: p.lychee,
          child: Text(letter, style: TextStyle(
            color: p.onLychee, fontWeight: FontWeight.w700, fontSize: 17))),
        const SizedBox(width: 10),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(v3AccountDisplayName(context, user.name),
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(color: p.ink, fontSize: 15,
                fontWeight: FontWeight.w700)),
            const SizedBox(height: 3),
            Text(v3AccountEmailLabel(
              context, controller.accountDetails?.email),
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(color: p.inkMuted, fontSize: 11)),
          ],
        )),
        const SizedBox(width: 4),
        TextButton(
          onPressed: onManage,
          style: TextButton.styleFrom(
            foregroundColor: p.lycheeInk,
            minimumSize: const Size(0, 40),
            padding: const EdgeInsets.symmetric(horizontal: 5)),
          child: Text(v3Copy(context, zh: '管理账户',
            en: 'Manage', tw: '管理帳戶'),
            style: const TextStyle(fontSize: 11,
                fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }
}

/// Subscription details belong in their own compact surface, not the profile.
class _MobilePlanCard extends StatelessWidget {
  const _MobilePlanCard({required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    final plan = PlanPresentation.fromController(controller);
    final expiry = plan.expiryDate;
    final remaining = expiry?.difference(DateTime.now());
    final expiryText = expiry == null
        ? '—'
        : '${expiry.year}-${expiry.month.toString().padLeft(2, '0')}-${expiry.day.toString().padLeft(2, '0')}';
    final daysText = remaining == null || remaining <= Duration.zero
        ? '—'
        : v3Copy(context, zh: '${remaining.inDays} 天',
            en: '${remaining.inDays} days', tw: '${remaining.inDays} 天');
    return _MobileSurface(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 11),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.workspace_premium_outlined,
            size: 18, color: p.lycheeInk),
          const SizedBox(width: 7),
          Expanded(child: Text(
            controller.hasPlan ? v3PlanShortLabel(context, plan)
                : v3Copy(context, zh: '暂无套餐',
                    en: 'No active plan', tw: '暫無套餐'),
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(color: p.ink, fontSize: 14,
              fontWeight: FontWeight.w700))),
          TextButton(
            onPressed: () => _openAccountPlan(context, controller),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              minimumSize: const Size(0, 38)),
            child: Text(controller.hasPlan
              ? v3Copy(context, zh: '续费', en: 'Renew', tw: '續費')
              : v3Copy(context, zh: '购买', en: 'Choose', tw: '購買'),
              style: TextStyle(color: p.lycheeInk, fontSize: 12)),
          ),
        ]),
        if (controller.hasPlan) ...[
          Divider(height: 12, color: p.line),
          Row(children: [
            Expanded(child: Text(
              v3Copy(context, zh: '到期 $expiryText',
                en: 'Expires $expiryText', tw: '到期 $expiryText'),
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(color: p.inkMuted, fontSize: 11))),
            Text(v3Copy(context, zh: '剩余 $daysText',
              en: '$daysText left', tw: '剩餘 $daysText'),
              style: TextStyle(color: p.inkMuted, fontSize: 11)),
          ]),
        ],
      ]),
    );
  }
}

/// Full-screen wallet page, reached from Account services; bottom tabs stay
/// on the Account root, not on this pushed route.
class _MobileWalletPage extends StatelessWidget {
  const _MobileWalletPage();

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    final controller = AppScope.of(context);
    return Scaffold(
      backgroundColor: p.canvas,
      body: SafeArea(child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          V3PageHeader(
            title: v3Copy(context, zh: '我的钱包', en: 'Wallet', tw: '我的錢包'),
            onBack: () => Navigator.of(context).pop(),
          ),
          const SizedBox(height: 16),
          _MobileWalletCard(controller: controller),
        ]),
      )),
    );
  }
}

class _MobileWalletCard extends StatelessWidget {
  const _MobileWalletCard({required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    final symbol = controller.currencySymbol;
    return _MobileSurface(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(v3Copy(context, zh: '我的钱包',
            en: 'MY WALLET', tw: '我的錢包'),
          style: TextStyle(color: p.inkMuted, fontSize: 11,
            fontWeight: FontWeight.w800, letterSpacing: 1.4)),
        const SizedBox(height: 8),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: _MobileMiniMoney(
            title: v3Copy(context, zh: '账户余额',
              en: 'Balance', tw: '帳戶餘額'),
            amount: '$symbol${(controller.user.balance / 100).toStringAsFixed(2)}')),
          const SizedBox(width: 6),
          Expanded(child: _MobileMiniMoney(
            title: v3Copy(context, zh: '可提现',
              en: 'Withdrawable', tw: '可提領'),
            amount: '$symbol${controller.withdrawable.toStringAsFixed(2)}')),
          const SizedBox(width: 14),
          Expanded(child: _MobileMiniMoney(
            title: v3Copy(context, zh: '累计佣金',
              en: 'Commission', tw: '累計佣金'),
            amount: '$symbol${controller.earnedCommission.toStringAsFixed(2)}')),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          if (AppConfig.panelFeatures.wallet) ...[
            Expanded(child: _MobileWalletAction(
              icon: Icons.add_rounded,
              label: v3Copy(context, zh: '充值',
                en: 'Top up', tw: '儲值'),
              emphasized: true,
              onTap: () => showV3RechargeDialog(context))),
            const SizedBox(width: 8),
          ],
          Expanded(child: _MobileWalletAction(
            icon: Icons.account_balance_outlined,
            label: v3Copy(context, zh: '提现',
              en: 'Withdraw', tw: '提領'),
            busy: controller.walletBusy,
            onTap: () => showV3WithdrawDialog(context))),
          const SizedBox(width: 8),
          Expanded(child: _MobileWalletAction(
            icon: Icons.swap_horiz_rounded,
            label: v3Copy(context, zh: '划转',
              en: 'Transfer', tw: '轉帳'),
            busy: controller.walletBusy,
            onTap: () => showV3TransferDialog(context))),
        ]),
      ]),
    );
  }
}

class _MobileMiniMoney extends StatelessWidget {
  const _MobileMiniMoney({required this.title, required this.amount});
  final String title;
  final String amount;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: TextStyle(color: p.inkMuted, fontSize: 11)),
      const SizedBox(height: 5),
      SizedBox(width: double.infinity,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(amount, maxLines: 1,
            style: TextStyle(color: p.ink,
                fontSize: 16, fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()])),
        )),
    ]);
  }
}

class _MobileWalletAction extends StatelessWidget {
  const _MobileWalletAction({
    required this.icon, required this.label, required this.onTap,
    this.emphasized = false, this.busy = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool emphasized;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return SizedBox(
      height: 43,
      child: Material(
        color: emphasized ? p.ink : p.surfaceRaised,
        borderRadius: BorderRadius.circular(13),
        child: InkWell(
          borderRadius: BorderRadius.circular(13),
          onTap: busy ? null : onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              if (busy)
                SizedBox(width: 14, height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: emphasized ? p.surface : p.ink))
              else
                Icon(icon, color: emphasized ? p.surface : p.ink, size: 16),
              const SizedBox(width: 4),
              Flexible(child: Text(label,
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(color: emphasized ? p.surface : p.ink,
                    fontSize: 11, fontWeight: FontWeight.w700))),
            ]),
          ),
        ),
      ),
    );
  }
}

class _MobileHairline extends StatelessWidget {
  const _MobileHairline({this.indent = 52});
  final double indent;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return Padding(
      padding: EdgeInsets.only(left: indent),
      child: Container(height: 1, color: p.line.withValues(alpha: .8)),
    );
  }
}

class _MobileAccountLink extends StatelessWidget {
  const _MobileAccountLink({
    super.key, required this.icon, required this.title, required this.onTap,
    this.danger = false,
  });
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    final fg = danger ? p.dangerInk : p.ink;
    return V3Pressable(
      onTap: onTap,
      hoverTint: p.ink.withValues(alpha: .035),
      child: SizedBox(
        height: 57,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 17),
          child: Row(children: [
            Icon(icon, size: 20, color: danger ? fg : p.inkMuted),
            const SizedBox(width: 16),
            Expanded(child: Text(title,
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(color: fg,
                    fontSize: 14, fontWeight: FontWeight.w600))),
            Icon(Icons.chevron_right_rounded, size: 19,
                color: p.inkMuted.withValues(alpha: .65)),
          ]),
        ),
      ),
    );
  }
}

class _MobilePreference extends StatelessWidget {
  const _MobilePreference({
    required this.title, required this.subtitle,
    required this.value, required this.onChanged,
  });
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(children: [
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(color: p.ink,
                fontSize: 13, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(subtitle, style: TextStyle(
                color: p.inkMuted, fontSize: 11)),
          ],
        )),
        const SizedBox(width: 8),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: p.surface,
          activeTrackColor: p.ink,
          inactiveTrackColor: p.line,
          inactiveThumbColor: p.surface,
        ),
      ]),
    );
  }
}

class _AccountSummaryPanel extends StatelessWidget {
  const _AccountSummaryPanel({required this.controller});
  final AppController controller;

  /// Renew the current plan in place, or route to the shop when the account
  /// has no plan or the plan id is no longer in the catalogue.

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    final user = controller.user;
    final plan = PlanPresentation.fromController(controller);
    final letter = user.avatarLetter.trim().isEmpty
        ? 'L'
        : user.avatarLetter.trim().substring(0, 1).toUpperCase();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(V3Radius.panel),
        border: Border.all(color: p.hairline),
        boxShadow: p.shadows,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: p.lychee,
                  borderRadius: BorderRadius.circular(V3Radius.card),
                ),
                child: Text(
                  letter,
                  style: TextStyle(
                    color: p.onLychee,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      v3AccountDisplayName(context, user.name),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: p.ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      v3AccountEmailLabel(
                        context,
                        controller.accountDetails?.email,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: p.inkMuted, fontSize: 11),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // The badge speaks account standing: green while normal, amber
              // when the plan needs renewal or traffic, red on ban.
              V3StatusBadge(
                label: v3PlanStatusLabel(context, plan.statusKind),
                color: v3PlanStatusColor(p, plan.statusKind),
                compact: true,
              ),
            ],
          ),
          const SizedBox(height: 20),
          Divider(color: p.line, height: 1),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      v3Copy(
                        context,
                        zh: '当前套餐',
                        en: 'CURRENT PLAN',
                        tw: '目前方案',
                      ),
                      style: TextStyle(
                        color: p.inkMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      v3PlanShortLabel(context, plan),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      // The account page's figures share one 16px voice —
                      // plan value and wallet money alike (desktop flat-branch
                      // ruling: no hero-scale numbers on this page).
                      style: TextStyle(
                        color: p.ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      v3PlanExpiryLabel(context, plan),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              FilledButton.icon(
                onPressed: () => _openAccountPlan(context, controller),
                style: FilledButton.styleFrom(
                  backgroundColor: p.lychee,
                  foregroundColor: p.onLychee,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(V3Radius.field),
                  ),
                ),
                // Renew opens the order-confirm dialog for the current plan
                // directly; without a plan it takes you to pick one in the shop.
                icon: Icon(
                  controller.hasPlan
                      ? Icons.autorenew_rounded
                      : Icons.storefront_rounded,
                  size: 17,
                ),
                label: Text(
                  controller.hasPlan
                      ? v3Copy(
                          context,
                          zh: '续费套餐',
                          en: 'Renew plan',
                          tw: '續費方案',
                        )
                      : v3Copy(
                          context,
                          zh: '选择套餐',
                          en: 'Choose plan',
                          tw: '選擇方案',
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Wallet balance and its three entries. Busy is controller-owned:
/// walletBusy rides only each transfer/withdraw API await (the dialog
/// phase stays interactive — that phase is input, not a pending money
/// movement, and the recharge dialog owns its own CTA spinner
/// underneath); the wallet controller raises it and notifies, so this
/// panel rebuilds via AppScope and both money buttons spin and disable
/// together instead of tracking private per-button state.
/// Compact account hub (§13.3): the five overflow surfaces read as one
/// quiet long-row list — circular icon seat, label, chevron, hairline
/// dividers. Content lives on its own pages; this is navigation, not a
/// second copy of the data.
class _AccountHubRows extends StatelessWidget {
  const _AccountHubRows({required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    final rows = <(IconData, String, AppPage)>[
      (
        Icons.receipt_long_rounded,
        v3Copy(context, zh: '订单', en: 'Orders', tw: '訂單'),
        AppPage.orders,
      ),
      (
        Icons.insights_rounded,
        v3Copy(context, zh: '用量', en: 'Usage', tw: '用量'),
        AppPage.traffic,
      ),
      (
        Icons.forum_rounded,
        v3Copy(context, zh: '工单', en: 'Support', tw: '工單'),
        AppPage.tickets,
      ),
      (
        Icons.auto_awesome_rounded,
        v3Copy(context, zh: '邀请', en: 'Invite', tw: '邀請'),
        AppPage.invite,
      ),
      (
        Icons.tune_rounded,
        v3Copy(context, zh: '设置', en: 'Settings', tw: '設定'),
        AppPage.settings,
      ),
    ];
    return V3Panel(
      padding: EdgeInsets.zero,
      child: Column(children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) Divider(color: p.line, height: 1),
          _AccountHubRow(
            key: hubRowKey(rows[i].$3),
            icon: rows[i].$1,
            label: rows[i].$2,
            onTap: () => openV3Page(context, rows[i].$3),
          ),
        ],
      ]),
    );
  }
}

class _AccountHubRow extends StatelessWidget {
  const _AccountHubRow({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return V3Pressable(
      onTap: onTap,
      hoverTint: p.ink.withValues(alpha: 0.04),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: p.surfaceRaised,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 22, color: p.inkMuted),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: p.ink,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              )),
          ),
          Icon(Icons.chevron_right_rounded, size: 20, color: p.inkMuted),
        ]),
      ),
    );
  }
}

class _WalletPanel extends StatelessWidget {
  const _WalletPanel();

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final p = V3Palette.of(context);
    final symbol = controller.currencySymbol;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: p.surfaceRaised,
        borderRadius: BorderRadius.circular(V3Radius.panel),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            v3Copy(context, zh: '我的钱包', en: 'WALLET', tw: '我的錢包'),
            style: TextStyle(
              color: p.inkMuted,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          // Three equal columns (owner ruling): balance / withdrawable /
          // lifetime commission — symmetric, no hero-plus-footnotes.
          Row(
            children: [
              Expanded(
                child: _MoneyStat(
                  label: v3Copy(
                    context,
                    zh: '账户余额',
                    en: 'Account balance',
                    tw: '帳戶餘額',
                  ),
                  symbol: symbol,
                  amount: controller.user.balance / 100,
                ),
              ),
              Container(width: 1, height: 46, color: p.line),
              const SizedBox(width: 18),
              Expanded(
                child: _MoneyStat(
                  label: v3Copy(
                    context,
                    zh: '可提现',
                    en: 'Withdrawable',
                    tw: '可提領',
                  ),
                  symbol: symbol,
                  amount: controller.withdrawable,
                ),
              ),
              Container(width: 1, height: 46, color: p.line),
              const SizedBox(width: 18),
              Expanded(
                child: _MoneyStat(
                  label: v3Copy(
                    context,
                    zh: '累计佣金',
                    en: 'Total commission',
                    tw: '累計佣金',
                  ),
                  symbol: symbol,
                  amount: controller.earnedCommission,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              if (AppConfig.panelFeatures.wallet) ...[
                Expanded(
                  child: _WalletActionButton(
                    icon: Icons.add_card_rounded,
                    label: v3Copy(context, zh: '充值', en: 'Top up', tw: '儲值'),
                    primary: true,
                    onTap: () => showV3RechargeDialog(context),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: _WalletActionButton(
                  icon: Icons.account_balance_rounded,
                  label: v3Copy(context, zh: '提现', en: 'Withdraw', tw: '提領'),
                  busy: controller.walletBusy,
                  onTap: () => showV3WithdrawDialog(context),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _WalletActionButton(
                  icon: Icons.swap_horiz_rounded,
                  label: v3Copy(context, zh: '划转', en: 'Transfer', tw: '轉帳'),
                  busy: controller.walletBusy,
                  onTap: () => showV3TransferDialog(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MoneyStat extends StatelessWidget {
  const _MoneyStat({
    required this.label,
    required this.symbol,
    required this.amount,
  });
  final String label;
  final String symbol;
  final double amount;
  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: p.inkMuted,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        V3RollingMoney(
          value: amount,
          symbol: symbol,
          style: TextStyle(
            color: p.ink,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class _WalletActionButton extends StatelessWidget {
  const _WalletActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.primary = false,
    this.busy = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool primary;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(V3Radius.field),
    );
    // While the flow is in flight the spinner rides a 16px icon slot
    // (recharge-dialog standard) and the null onPressed blocks the repeat
    // clicks that would double-spend.
    final leading = busy
        ? SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: primary ? p.onLychee : p.ink,
            ),
          )
        : Icon(icon, size: 17);
    return SizedBox(
      height: 46,
      child: primary
          ? FilledButton.icon(
              onPressed: busy ? null : onTap,
              style: FilledButton.styleFrom(
                backgroundColor: p.lychee,
                foregroundColor: p.onLychee,
                padding: EdgeInsets.zero,
                shape: shape,
              ),
              icon: leading,
              label: Text(label),
            )
          : OutlinedButton.icon(
              onPressed: busy ? null : onTap,
              style: OutlinedButton.styleFrom(
                foregroundColor: p.ink,
                side: BorderSide(color: p.line),
                padding: EdgeInsets.zero,
                shape: shape,
              ),
              icon: leading,
              label: Text(label),
            ),
    );
  }
}

class _PreferencesPanel extends StatelessWidget {
  const _PreferencesPanel({
    required this.controller,
    required this.busy,
    required this.onExpireChanged,
    required this.onTrafficChanged,
    required this.onAutoRenewalChanged,
  });
  final AppController controller;
  final bool busy;
  final ValueChanged<bool> onExpireChanged;
  final ValueChanged<bool> onTrafficChanged;
  final ValueChanged<bool> onAutoRenewalChanged;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(V3Radius.panel),
        border: Border.all(color: p.hairline),
        boxShadow: p.shadows,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                v3Copy(
                  context,
                  zh: '账户偏好',
                  en: 'ACCOUNT PREFERENCES',
                  tw: '帳戶偏好',
                ),
                style: TextStyle(
                  color: p.inkMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
              const Spacer(),
              if (busy)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _PreferenceRow(
            title: v3Copy(
              context,
              zh: '到期提醒',
              en: 'Expiry reminder',
              tw: '到期提醒',
            ),
            subtitle: v3Copy(
              context,
              zh: '套餐接近到期时提醒我',
              en: 'Notify me when the plan is near expiry',
              tw: '方案即將到期時提醒我',
            ),
            value: controller.user.remindExpire,
            onChanged: busy ? null : onExpireChanged,
          ),
          Divider(color: p.line, height: 1),
          _PreferenceRow(
            title: v3Copy(context, zh: '流量提醒', en: 'Data reminder', tw: '流量提醒'),
            subtitle: v3Copy(
              context,
              zh: '剩余流量不足时提醒我',
              en: 'Notify me when data runs low',
              tw: '剩餘流量不足時提醒我',
            ),
            value: controller.user.remindTraffic,
            onChanged: busy ? null : onTrafficChanged,
          ),
          Divider(color: p.line, height: 1),
          _PreferenceRow(
            title: v3Copy(context, zh: '自动续费', en: 'Auto-renewal', tw: '自動續費'),
            subtitle: v3Copy(
              context,
              zh: '允许服务端在条件满足时自动续费',
              en: 'Allow the service to renew when eligible',
              tw: '允許服務端在符合條件時自動續費',
            ),
            value: controller.user.autoRenewal,
            onChanged: busy ? null : onAutoRenewalChanged,
          ),
        ],
      ),
    );
  }
}

class _PreferenceRow extends StatelessWidget {
  const _PreferenceRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: p.ink,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(color: p.inkMuted, fontSize: 11),
                ),
              ],
            ),
          ),
          V3Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _AccountActions extends StatelessWidget {
  const _AccountActions({
    required this.onPassword,
    required this.onTelegram,
    required this.onLogout,
  });
  final VoidCallback onPassword;
  final VoidCallback onTelegram;
  final VoidCallback onLogout;
  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: p.surfaceRaised,
        borderRadius: BorderRadius.circular(V3Radius.card),
      ),
      child: Row(
        children: [
          Expanded(
            child: _AccountAction(
              icon: Icons.password_rounded,
              label: v3Copy(
                context,
                zh: '修改密码',
                en: 'Change password',
                tw: '修改密碼',
              ),
              onTap: onPassword,
            ),
          ),
          Expanded(
            child: _AccountAction(
              key: const ValueKey('v3-account-telegram'),
              icon: Icons.send_rounded,
              label: v3Copy(context, zh: 'TG 通知', en: 'Telegram', tw: 'TG 通知'),
              onTap: onTelegram,
            ),
          ),
          Expanded(
            child: _AccountAction(
              icon: Icons.logout_rounded,
              label: v3Copy(context, zh: '退出登录', en: 'Log out', tw: '登出'),
              danger: true,
              onTap: onLogout,
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountAction extends StatelessWidget {
  const _AccountAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;
  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    // V3Pressable paints the ink above the panel's opaque fill, so the
    // press/hover highlight is actually visible.
    return V3Pressable(
      onTap: onTap,
      hoverTint: p.ink.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(V3Radius.field),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 6),
        child: Column(
          children: [
            Icon(icon, size: 18, color: danger ? p.danger : p.inkMuted),
            const SizedBox(height: 5),
            Text(
              label,
              style: TextStyle(
                color: danger ? p.danger : p.ink,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PasswordDialog extends StatefulWidget {
  const _PasswordDialog();
  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  final _old = TextEditingController();
  final _next = TextEditingController();
  final _confirmation = TextEditingController();
  bool _busy = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _old.dispose();
    _next.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (_old.text.isEmpty || _next.text.isEmpty || _confirmation.text.isEmpty) {
      setState(
        () => _error = v3Copy(
          context,
          zh: '请完整填写密码',
          en: 'Fill in all password fields',
          tw: '請完整填寫密碼',
        ),
      );
      return;
    }
    if (_next.text != _confirmation.text) {
      setState(
        () => _error = v3Copy(
          context,
          zh: '两次输入的新密码不一致',
          en: 'New passwords do not match',
          tw: '兩次輸入的新密碼不一致',
        ),
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AppScope.read(context).changePasswordApi(
        oldPassword: _old.text,
        newPassword: _next.text,
        passwordConfirmation: _confirmation.text,
      );
      if (!mounted) return;
      // Capture the root overlay before popping so the feedback outlives
      // the dialog route.
      final overlay = Overlay.of(context, rootOverlay: true);
      final message = v3Copy(
        context,
        zh: '密码修改成功',
        en: 'Password changed',
        tw: '密碼修改成功',
      );
      Navigator.of(context).pop();
      V3Toast.showInOverlay(overlay, message, type: V3ToastType.success);
    } catch (error) {
      if (mounted) {
        // Async result errors are transient toasts, same voice as the success
        // path; only field validation stays inline (M3). The wrapper type is
        // unwrapped and the failure localized by the shared mapping (N13).
        final overlay = Overlay.of(context, rootOverlay: true);
        V3Toast.showInOverlay(overlay, v3UserFacingError(context, error),
          type: V3ToastType.error);
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: Container(
        width: 430,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        padding: const EdgeInsets.all(V3Layout.dialogPadding),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(V3Radius.panel),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      v3Copy(
                        context,
                        zh: '修改账户密码',
                        en: 'Change account password',
                        tw: '修改帳戶密碼',
                      ),
                      style: TextStyle(
                        color: p.ink,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: v3Copy(context, zh: '关闭', en: 'Close', tw: '關閉'),
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _PasswordField(
                controller: _old,
                label: v3Copy(
                  context,
                  zh: '当前密码',
                  en: 'Current password',
                  tw: '目前密碼',
                ),
                autofocus: true,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              _PasswordField(
                controller: _next,
                label: v3Copy(
                  context,
                  zh: '新密码',
                  en: 'New password',
                  tw: '新密碼',
                ),
                textInputAction: TextInputAction.next,
                obscureText: _obscure,
                trailing: IconButton(
                  tooltip: _obscure
                      ? v3Copy(
                          context,
                          zh: '显示密码',
                          en: 'Show password',
                          tw: '顯示密碼',
                        )
                      : v3Copy(
                          context,
                          zh: '隐藏密码',
                          en: 'Hide password',
                          tw: '隱藏密碼',
                        ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    size: 18,
                    color: p.inkMuted,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _PasswordField(
                controller: _confirmation,
                label: v3Copy(
                  context,
                  zh: '确认新密码',
                  en: 'Confirm new password',
                  tw: '確認新密碼',
                ),
                obscureText: _obscure,
                onSubmitted: (_) => _submit(),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(color: p.dangerInk, fontSize: 11),
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: _busy ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: p.lychee,
                    foregroundColor: p.onLychee,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(V3Radius.field),
                    ),
                  ),
                  // The spinner replaces the label inside the fixed-width
                  // slot, so the button never resizes mid-submit (M3).
                  child: _busy
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: p.onLychee,
                          ),
                        )
                      : Text(
                          v3Copy(
                            context,
                            zh: '保存新密码',
                            en: 'Save password',
                            tw: '儲存新密碼',
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PasswordField extends StatelessWidget {
  const _PasswordField({
    required this.controller,
    required this.label,
    this.trailing,
    this.obscureText = true,
    this.autofocus = false,
    this.textInputAction,
    this.onSubmitted,
  });
  final TextEditingController controller;
  final String label;
  final Widget? trailing;
  final bool obscureText;
  final bool autofocus;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return TextField(
      controller: controller,
      autofocus: autofocus,
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: p.surfaceRaised,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(V3Radius.field),
          borderSide: BorderSide.none,
        ),
        suffixIcon: trailing,
      ),
    );
  }
}
