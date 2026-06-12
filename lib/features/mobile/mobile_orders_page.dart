import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/app_controller.dart';
import '../../shared/models/api_models.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_radius.dart';
import '../../shared/theme/app_text_styles.dart';

class MobileOrdersPage extends StatefulWidget {
  const MobileOrdersPage({super.key});

  @override
  State<MobileOrdersPage> createState() => _MobileOrdersPageState();
}

class _MobileOrdersPageState extends State<MobileOrdersPage> {
  bool _loading = true;
  String? _error;
  List<RemoteOrder> _orders = const [];

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final orders = await AppScope.of(context).api.fetchOrders();
      if (!mounted) return;
      setState(() {
        _orders = orders;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('ApiException: ', '');
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        children: [
          Row(
            children: [
              Expanded(child: Text('订单', style: AppTextStyles.pageTitle.copyWith(fontSize: 26))),
              IconButton(onPressed: _load, icon: Icon(LucideIcons.refreshCw, color: c.primary)),
            ],
          ),
          const SizedBox(height: 16),
          if (_loading)
            Padding(
              padding: const EdgeInsets.only(top: 80),
              child: Center(child: CircularProgressIndicator(color: c.primary)),
            )
          else if (_error != null)
            _StateCard(icon: LucideIcons.circleAlert, title: '订单加载失败', subtitle: _error!)
          else if (_orders.isEmpty)
            const _StateCard(icon: LucideIcons.receipt, title: '暂无订单', subtitle: '购买套餐后会显示在这里')
          else
            for (final order in _orders) ...[
              _OrderCard(order: order),
              const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order});

  final RemoteOrder order;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final statusColor = switch (order.status) {
      0 => c.warning,
      1 => c.primary,
      2 => c.textMuted,
      3 => c.success,
      4 => c.danger,
      _ => c.textMuted,
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: c.cardBg, borderRadius: BorderRadius.circular(AppRadius.card), border: Border.all(color: c.softBorder)),
      child: Row(
        children: [
          Icon(LucideIcons.receipt, color: c.primary, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(order.planName ?? '套餐订单', maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTextStyles.bodyStrong),
                const SizedBox(height: 3),
                Text('${order.periodLabel} · ${order.dateDisplay}', style: AppTextStyles.caption.copyWith(color: c.textMuted)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(order.amountDisplay, style: AppTextStyles.bodyStrong.copyWith(color: c.textPrimary)),
              const SizedBox(height: 3),
              Text(order.statusLabel, style: AppTextStyles.caption.copyWith(color: statusColor, fontWeight: FontWeight.w700)),
            ],
          ),
        ],
      ),
    );
  }
}

class _StateCard extends StatelessWidget {
  const _StateCard({required this.icon, required this.title, required this.subtitle});

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: c.cardBg, borderRadius: BorderRadius.circular(AppRadius.card), border: Border.all(color: c.softBorder)),
      child: Row(
        children: [
          Icon(icon, color: c.iconMuted, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.bodyStrong),
                const SizedBox(height: 3),
                Text(subtitle, style: AppTextStyles.caption.copyWith(color: c.textMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
