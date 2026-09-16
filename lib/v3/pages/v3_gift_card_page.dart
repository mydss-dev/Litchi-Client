import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../theme/v3_palette.dart';
import '../ui/v3_components.dart';
import '../ui/v3_sheet.dart';

/// Redeem a gift card into the account balance.
///
/// Only xiaoV2board panels expose the endpoint, so the page is gated behind
/// [PanelFeatures.giftCard] like the wallet it credits.
class V3GiftCardPage extends StatefulWidget {
  const V3GiftCardPage({super.key});

  /// Opens the redemption form as a sheet.
  static Future<void> show(BuildContext context) => showV3Sheet<void>(
    context,
    title: '礼品卡兑换',
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
    final code = _code.text.trim();
    if (code.isEmpty) {
      setState(() {
        _error = '请输入兑换码';
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
      await controller.api.redeemGiftCard(code);
      if (!mounted) return;
      _code.clear();
      setState(() => _success = '兑换成功，余额已更新');
      await controller.refreshData();
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error
              .toString()
              .replaceFirst('ApiException: ', '')
              .replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    // No page header and no page-level scroll: the sheet supplies the title and
    // the scroller, so this is only the form.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '输入礼品卡上的兑换码，金额会直接充入账户余额。',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 18),
        V3Panel(
          tone: V3PanelTone.hero,
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '兑换码',
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
                decoration: const InputDecoration(hintText: '粘贴或输入兑换码'),
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
                  child: Text(_busy ? '兑换中…' : '立即兑换'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        V3Panel(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded, color: p.inkMuted, size: 18),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '兑换码区分大小写，且每个兑换码只能使用一次。兑换后余额可在「我的钱包」查看。',
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
