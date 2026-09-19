import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../l10n/generated/app_localizations_zh.dart';
import '../../shared/services/app_error_message_service.dart';
import '../theme/v3_palette.dart';
import '../ui/v3_components.dart';
import '../ui/v3_sheet.dart';

AppLocalizations _copy(BuildContext context) =>
    Localizations.of<AppLocalizations>(context, AppLocalizations) ??
    AppLocalizationsZh();

/// The panel may redeem balance, traffic, time, or plans. Never promise that
/// every code credits wallet balance; the exact benefit is decided by the API.
String _redemptionIntro(AppLocalizations l) {
  if (l.localeName.startsWith('en')) {
    return 'Enter your redemption code. The benefit depends on the code and may include balance, traffic, duration, or a plan.';
  }
  if (l.localeName.toLowerCase().contains('tw')) {
    return '輸入兌換碼；實際權益依兌換碼而定，可能包含餘額、流量、時長或套餐。';
  }
  return '输入兑换码；实际权益以兑换码为准，可能包含余额、流量、时长或套餐。';
}

String _redemptionHelp(AppLocalizations l) {
  if (l.localeName.startsWith('en')) {
    return 'Enter the code exactly as provided. After redeeming, check the updated benefits in your account.';
  }
  if (l.localeName.toLowerCase().contains('tw')) {
    return '請依照原樣輸入兌換碼。兌換後可到帳戶頁查看更新的權益。';
  }
  return '请按原样输入兑换码。兑换后可到账户页查看更新的权益。';
}

String _refreshFailedAfterRedeem(AppLocalizations l) {
  if (l.localeName.startsWith('en')) {
    return 'Redeemed successfully, but account refresh failed. Refresh later; do not redeem the same code again.';
  }
  if (l.localeName.toLowerCase().contains('tw')) {
    return '兌換已成功，但帳戶資料刷新失敗。請稍後刷新，不要重複兌換。';
  }
  return '兑换已成功，但账户数据刷新失败。请稍后刷新，不要重复兑换。';
}

/// Redeem a code for the backend-defined account benefit. Only compatible
/// panels expose this endpoint, so navigation remains feature-gated.
class V3GiftCardPage extends StatefulWidget {
  const V3GiftCardPage({super.key});

  static Future<void> show(BuildContext context) => showV3Sheet<void>(
    context,
    title: _copy(context).giftCardTitle,
    builder: (_) => const V3GiftCardPage(),
  );

  @override
  State<V3GiftCardPage> createState() => _V3GiftCardPageState();
}

class _V3GiftCardPageState extends State<V3GiftCardPage> {
  final _code = TextEditingController();
  bool _busy = false;
  String? _error;
  String? _success;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _redeem() async {
    if (_busy) return;
    final l = _copy(context);
    final code = _code.text.trim();
    if (code.isEmpty) {
      setState(() {
        _error = l.giftCardEnterRequired;
        _success = null;
      });
      return;
    }
    final controller = AppScope.read(context);
    setState(() {
      _busy = true;
      _error = null;
      _success = null;
    });
    try {
      try {
        await controller.api.redeemGiftCard(code);
      } catch (error) {
        if (mounted) {
          setState(() => _error = AppErrorMessageService.userFacing(error, _copy(context)));
        }
        return;
      }

      // Redemption succeeded. Refresh is a separate, best-effort operation:
      // a network failure here must never be shown as a failed redemption or
      // invite a duplicate submission of a one-use code.
      if (!mounted) return;
      _code.clear();
      var refreshFailed = false;
      try {
        await controller.refreshData();
      } catch (_) {
        refreshFailed = true;
      }
      if (!mounted) return;
      setState(() {
        _success = refreshFailed
            ? _refreshFailedAfterRedeem(_copy(context))
            : _copy(context).giftCardRedeemed;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    final l = _copy(context);
    // The surrounding sheet owns the title and scrolling; this is form content.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _redemptionIntro(l),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 18),
        V3Panel(
          tone: V3PanelTone.hero,
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l.giftCardTitle,
                style: TextStyle(
                  color: p.inkMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _code,
                enabled: !_busy,
                autofocus: true,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _redeem(),
                decoration: InputDecoration(hintText: l.giftCardEnterHint),
              ),
              if (_error != null || _success != null) ...[
                const SizedBox(height: 12),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _error ?? _success!,
                    style: TextStyle(
                      color: _error != null ? p.dangerInk : p.successInk,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: FilledButton(
                  onPressed: _busy ? null : _redeem,
                  style: FilledButton.styleFrom(
                    backgroundColor: p.lychee,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(_busy ? l.giftCardRedeeming : l.giftCardRedeemNow),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        V3Panel(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded, color: p.inkMuted, size: 18),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _redemptionHelp(l),
                  style: TextStyle(
                    color: p.inkMuted,
                    fontSize: 11,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
