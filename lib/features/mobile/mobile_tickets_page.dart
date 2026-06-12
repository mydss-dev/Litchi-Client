import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/app_controller.dart';
import '../../shared/models/api_models.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_radius.dart';
import '../../shared/theme/app_text_styles.dart';

class MobileTicketsPage extends StatefulWidget {
  const MobileTicketsPage({super.key});

  @override
  State<MobileTicketsPage> createState() => _MobileTicketsPageState();
}

class _MobileTicketsPageState extends State<MobileTicketsPage> {
  bool _loading = true;
  String? _error;
  List<TicketModel> _tickets = const [];

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
      final tickets = await AppScope.of(context).api.fetchTickets();
      if (!mounted) return;
      setState(() {
        _tickets = tickets;
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
              Expanded(child: Text('工单', style: AppTextStyles.pageTitle.copyWith(fontSize: 26))),
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
            _StateCard(icon: LucideIcons.circleAlert, title: '工单加载失败', subtitle: _error!)
          else if (_tickets.isEmpty)
            const _StateCard(icon: LucideIcons.messageSquare, title: '暂无工单', subtitle: '有问题可以新建工单联系客服')
          else
            for (final ticket in _tickets) ...[
              _TicketCard(ticket: ticket),
              const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }
}

class _TicketCard extends StatelessWidget {
  const _TicketCard({required this.ticket});

  final TicketModel ticket;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final statusColor = ticket.isOpen ? c.primary : c.textMuted;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: c.cardBg, borderRadius: BorderRadius.circular(AppRadius.card), border: Border.all(color: c.softBorder)),
      child: Row(
        children: [
          Icon(LucideIcons.messageSquare, color: statusColor, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(ticket.subject.isEmpty ? '未命名工单' : ticket.subject, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTextStyles.bodyStrong),
              const SizedBox(height: 3),
              Text('${ticket.levelLabel} · ${ticket.dateDisplay}', style: AppTextStyles.caption.copyWith(color: c.textMuted)),
            ]),
          ),
          Text(ticket.statusLabel, style: AppTextStyles.caption.copyWith(color: statusColor, fontWeight: FontWeight.w700)),
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
      child: Row(children: [
        Icon(icon, color: c.iconMuted, size: 22),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: AppTextStyles.bodyStrong),
          const SizedBox(height: 3),
          Text(subtitle, style: AppTextStyles.caption.copyWith(color: c.textMuted)),
        ])),
      ]),
    );
  }
}
