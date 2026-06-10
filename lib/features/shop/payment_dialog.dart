import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../shared/models/api_models.dart';
import '../../shared/services/panel_api.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_palette.dart';
import '../../shared/theme/app_radius.dart';
import '../../shared/theme/app_text_styles.dart';
import '../../shared/widgets/app_toast.dart';
import '../../shared/widgets/icon_action_btn.dart';

/// Opens the payment dialog for an existing pending order.
///
/// [currencySymbol] is optional — fetched from the API when omitted so
/// callers that already have the symbol (e.g. after order submission) can
/// skip the extra round-trip.
Future<void> showOrderPaymentDialog({
  required BuildContext context,
  required String tradeNo,
  required double finalPrice,
  required PanelApi api,
  String? currencySymbol,
}) async {
  String sym = currencySymbol ?? '¥';
  if (currencySymbol == null) {
    try {
      sym = await api.getCommCurrencySymbol();
    } catch (_) {}
  }
  if (!context.mounted) return;
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black54,
    builder: (_) => _PaymentDialog(
      tradeNo: tradeNo,
      finalPrice: finalPrice,
      currencySymbol: sym,
      api: api,
    ),
  );
}

// Stage 1: method selection  →  Stage 2: QR code + polling  →  Stage 3: success
// Stage 2 can also expire → Stage 4: expired (refresh available)
enum _Stage { methods, qr, success, expired }

class _PaymentDialog extends StatefulWidget {
  const _PaymentDialog({
    required this.tradeNo,
    required this.finalPrice,
    required this.currencySymbol,
    required this.api,
  });

  final String tradeNo;
  final double finalPrice;
  final String currencySymbol;
  final PanelApi api;

  @override
  State<_PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<_PaymentDialog> {
  // method selection
  List<RemotePaymentMethod> _methods = [];
  bool _loadingMethods = true;
  int? _selectedId;
  String _selectedName = '';
  bool _checkingOut = false;

  // qr + timer
  _Stage _stage = _Stage.methods;
  String _payUrl = '';
  int _payType = 0; // 0=qr content, 1=redirect link
  Timer? _countdown;
  Timer? _pollTimer;
  int _secondsLeft = 900; // 15 minutes

  // actions
  bool _manualChecking = false;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _loadMethods();
  }

  @override
  void dispose() {
    _countdown?.cancel();
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadMethods() async {
    try {
      final methods = await widget.api.getPaymentMethods();
      if (mounted) {
        setState(() {
          _methods = methods;
          _loadingMethods = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingMethods = false);
        AppToast.show(context, '获取支付方式失败：$e', type: AppToastType.error);
      }
    }
  }

  Future<void> _checkout() async {
    if (_selectedId == null || _checkingOut) return;
    setState(() => _checkingOut = true);
    try {
      final result = await widget.api.checkoutOrder(widget.tradeNo, _selectedId!);
      if (!mounted) return;
      if (result.url.isEmpty) {
        // Balance deduction — processed server-side immediately
        setState(() {
          _stage = _Stage.success;
          _checkingOut = false;
        });
      } else {
        setState(() {
          _payUrl = result.url;
          _payType = result.type;
          _stage = _Stage.qr;
          _secondsLeft = 900;
          _checkingOut = false;
        });
        if (result.type == 1) unawaited(_openInBrowser(result.url));
        _startTimers();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _checkingOut = false);
        AppToast.show(context, '发起支付失败：$e', type: AppToastType.error);
      }
    }
  }

  Future<void> _openInBrowser(String url) async {
    try {
      if (Platform.isWindows) {
        await Process.run('cmd', ['/c', 'start', '', url]);
      }
    } catch (_) {}
  }

  void _startTimers() {
    _countdown?.cancel();
    _pollTimer?.cancel();
    _countdown = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _secondsLeft--;
        if (_secondsLeft <= 0) {
          _countdown?.cancel();
          _pollTimer?.cancel();
          _stage = _Stage.expired;
        }
      });
    });
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) => _pollStatus());
  }

  Future<void> _pollStatus() async {
    if (!mounted) return;
    try {
      final status = await widget.api.checkOrderStatus(widget.tradeNo);
      if ((status == 3 || status == 4) && mounted) {
        _countdown?.cancel();
        _pollTimer?.cancel();
        setState(() => _stage = _Stage.success);
      }
    } catch (_) {}
  }

  Future<void> _manualCheck() async {
    if (_manualChecking) return;
    setState(() => _manualChecking = true);
    try {
      final status = await widget.api.checkOrderStatus(widget.tradeNo);
      if (!mounted) return;
      if (status == 3 || status == 4) {
        _countdown?.cancel();
        _pollTimer?.cancel();
        setState(() => _stage = _Stage.success);
      } else {
        AppToast.show(context, '暂未检测到支付，请稍后再试', type: AppToastType.warning);
      }
    } catch (e) {
      if (mounted) AppToast.show(context, '查询失败：$e', type: AppToastType.error);
    } finally {
      if (mounted) setState(() => _manualChecking = false);
    }
  }

  Future<void> _refresh() async {
    if (_selectedId == null || _refreshing) return;
    setState(() => _refreshing = true);
    try {
      final result = await widget.api.checkoutOrder(widget.tradeNo, _selectedId!);
      if (!mounted) return;
      setState(() {
        _payUrl = result.url;
        _payType = result.type;
        _stage = _Stage.qr;
        _secondsLeft = 900;
        _refreshing = false;
      });
      if (result.type == 1) unawaited(_openInBrowser(result.url));
      _startTimers();
    } catch (e) {
      if (mounted) {
        setState(() => _refreshing = false);
        AppToast.show(context, '刷新失败：$e', type: AppToastType.error);
      }
    }
  }

  String get _countdownText {
    final m = _secondsLeft ~/ 60;
    final s = _secondsLeft % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Color _timerColor(AppColors c) {
    if (_secondsLeft > 300) return c.textMuted;
    if (_secondsLeft > 60) return c.warning;
    return c.danger;
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 420,
          constraints: const BoxConstraints(maxHeight: 640),
          decoration: BoxDecoration(
            color: c.cardBg,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(color: c.softBorder),
            boxShadow: [
              BoxShadow(color: c.shadow, blurRadius: 32, offset: const Offset(0, 12))
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(c),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: switch (_stage) {
                    _Stage.methods => _buildMethods(c),
                    _Stage.qr => _buildQr(c),
                    _Stage.success => _buildSuccess(c),
                    _Stage.expired => _buildExpired(c),
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(AppColors c) {
    final titles = {
      _Stage.methods: '选择支付方式',
      _Stage.qr: _payType == 1 ? '浏览器支付' : '扫码支付',
      _Stage.success: '支付成功',
      _Stage.expired: _payType == 1 ? '支付已超时' : '二维码已过期',
    };
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 16, 16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.softBorder)),
      ),
      child: Row(
        children: [
          if (_stage == _Stage.qr) ...[
            IconActionBtn(
              icon: LucideIcons.arrowLeft,
              onTap: () {
                _countdown?.cancel();
                _pollTimer?.cancel();
                setState(() => _stage = _Stage.methods);
              },
              c: c,
            ),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: Text(titles[_stage]!,
                style: AppTextStyles.pageTitle.copyWith(color: c.textPrimary)),
          ),
          if (_stage != _Stage.success)
            IconActionBtn(
                icon: LucideIcons.x,
                onTap: () => Navigator.of(context).pop(),
                c: c),
        ],
      ),
    );
  }

  // ── Stage 1: method selection ─────────────────────────────────────────────

  Widget _buildMethods(AppColors c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: c.primarySoft,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: c.primary.withValues(alpha: 0.2)),
          ),
          child: Column(
            children: [
              Text('应付金额',
                  style: AppTextStyles.caption
                      .copyWith(color: c.primary.withValues(alpha: 0.75))),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(widget.currencySymbol,
                      style: AppTextStyles.sectionTitle.copyWith(color: c.primary)),
                  Text(widget.finalPrice.toStringAsFixed(2),
                      style: AppTextStyles.largeNumber(fontSize: 26)
                          .copyWith(color: c.primary)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text('选择付款方式',
            style: AppTextStyles.sectionTitle.copyWith(color: c.textPrimary)),
        const SizedBox(height: 12),
        if (_loadingMethods)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else if (_methods.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text('暂无可用支付方式',
                style: AppTextStyles.body.copyWith(color: c.textMuted)),
          )
        else
          ...(_methods.map((m) {
            final sel = _selectedId == m.id;
            return GestureDetector(
              onTap: () => setState(() {
                _selectedId = m.id;
                _selectedName = m.name;
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 100),
                margin: const EdgeInsets.only(bottom: 10),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: sel ? c.primarySoft : c.surfaceMuted,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                    color: sel ? c.primary : c.border,
                    width: sel ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(LucideIcons.creditCard,
                        size: 18, color: sel ? c.primary : c.iconDefault),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(m.name,
                          style: AppTextStyles.bodyStrong.copyWith(
                            color: sel ? c.primary : c.textPrimary,
                          )),
                    ),
                    Icon(
                      sel ? LucideIcons.circleCheck : LucideIcons.circle,
                      size: 18,
                      color: sel ? c.primary : c.iconMuted,
                    ),
                  ],
                ),
              ),
            );
          })),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 44,
          child: ElevatedButton(
            onPressed:
                (_selectedId == null || _checkingOut || _loadingMethods)
                    ? null
                    : _checkout,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
            child: Ink(
              decoration: BoxDecoration(
                gradient: (_selectedId != null && !_loadingMethods)
                    ? AppPalette.brandGradient
                    : null,
                color: (_selectedId == null || _loadingMethods) ? c.border : null,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Center(
                child: _checkingOut
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : Text('去支付',
                        style: AppTextStyles.button.copyWith(
                            color: Colors.white, fontWeight: FontWeight.w700)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Stage 2: QR code ──────────────────────────────────────────────────────

  Widget _buildQr(AppColors c) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.creditCard, size: 15, color: c.textMuted),
            const SizedBox(width: 6),
            Text(_selectedName,
                style: AppTextStyles.body.copyWith(
                    color: c.textSecondary, fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(widget.currencySymbol,
                style: AppTextStyles.sectionTitle
                    .copyWith(color: c.primary, fontSize: 18)),
            Text(widget.finalPrice.toStringAsFixed(2),
                style: AppTextStyles.largeNumber(fontSize: 34)
                    .copyWith(color: c.primary)),
          ],
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.07),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: QrImageView(
            data: _payUrl,
            version: QrVersions.auto,
            size: 200,
            backgroundColor: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        Text('使用手机扫码完成支付',
            style: AppTextStyles.body.copyWith(color: c.textSecondary)),
        if (_payType == 1) ...[
          const SizedBox(height: 6),
          GestureDetector(
            onTap: () => _openInBrowser(_payUrl),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(LucideIcons.externalLink, size: 12, color: c.primary),
                  const SizedBox(width: 4),
                  Text('或在浏览器打开',
                      style: AppTextStyles.caption
                          .copyWith(color: c.primary)),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 8),
        _buildCountdown(c),
        const SizedBox(height: 24),
        _buildQrActions(c),
      ],
    );
  }

  Widget _buildCountdown(AppColors c) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(LucideIcons.timer, size: 13, color: _timerColor(c)),
        const SizedBox(width: 5),
        Text('剩余 $_countdownText',
            style: AppTextStyles.caption.copyWith(color: _timerColor(c))),
      ],
    );
  }

  Widget _buildQrActions(AppColors c) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: SizedBox(
            height: 44,
            child: ElevatedButton(
              onPressed: _manualChecking ? null : _manualCheck,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
              ),
              child: Ink(
                decoration: BoxDecoration(
                  gradient: AppPalette.brandGradient,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Center(
                  child: _manualChecking
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : Text('我已完成支付',
                          style: AppTextStyles.button.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700)),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SizedBox(
            height: 44,
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: c.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
              ),
              child: Text('取消',
                  style: AppTextStyles.button.copyWith(color: c.textSecondary)),
            ),
          ),
        ),
      ],
    );
  }

  // ── Stage 3: success ──────────────────────────────────────────────────────

  Widget _buildSuccess(AppColors c) {
    return Column(
      children: [
        const SizedBox(height: 8),
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: c.success.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(LucideIcons.circleCheck, size: 40, color: c.success),
        ),
        const SizedBox(height: 16),
        Text('支付成功！',
            style: AppTextStyles.heroTitle.copyWith(color: c.textPrimary)),
        const SizedBox(height: 8),
        Text('订单已激活，请刷新页面查看',
            style: AppTextStyles.body.copyWith(color: c.textMuted)),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          height: 44,
          child: ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
            child: Ink(
              decoration: BoxDecoration(
                gradient: AppPalette.brandGradient,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Center(
                child: Text('完成',
                    style: AppTextStyles.button.copyWith(
                        color: Colors.white, fontWeight: FontWeight.w700)),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  // ── Stage 4: expired ──────────────────────────────────────────────────────

  Widget _buildExpired(AppColors c) {
    return Column(
      children: [
        const SizedBox(height: 8),
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: c.warning.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(LucideIcons.timer, size: 40, color: c.warning),
        ),
        const SizedBox(height: 16),
        Text('二维码已过期',
            style: AppTextStyles.pageTitle.copyWith(color: c.textPrimary)),
        const SizedBox(height: 8),
        Text('请刷新获取新的支付二维码',
            style: AppTextStyles.body.copyWith(color: c.textMuted)),
        const SizedBox(height: 32),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: SizedBox(
                height: 44,
                child: ElevatedButton(
                  onPressed: _refreshing ? null : _refresh,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                  child: Ink(
                    decoration: BoxDecoration(
                      gradient: _refreshing ? null : AppPalette.brandGradient,
                      color: _refreshing ? c.border : null,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Center(
                      child: _refreshing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(LucideIcons.refreshCw,
                                    size: 15, color: Colors.white),
                                const SizedBox(width: 6),
                                Text('刷新二维码',
                                    style: AppTextStyles.button.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700)),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 44,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: c.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                  child: Text('取消',
                      style:
                          AppTextStyles.button.copyWith(color: c.textSecondary)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
