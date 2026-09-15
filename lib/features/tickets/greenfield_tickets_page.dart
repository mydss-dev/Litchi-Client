import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/app_controller.dart';
import '../../app/nav_destinations.dart';
import '../../l10n/l10n.dart';
import '../../shared/models/api_models.dart';
import '../../shared/services/app_error_message_service.dart';
import '../../shared/widgets/app_modal.dart';
import '../../shared/widgets/app_toast.dart';
import '../../shared/widgets/page_status_cards.dart';
import '../../shared/widgets/responsive_page_scaffold.dart';
import 'widgets/greenfield_new_ticket_modal.dart';
import 'widgets/greenfield_ticket_detail_modal.dart';
import 'widgets/greenfield_tickets_surface.dart';

class GreenfieldTicketsPage extends StatefulWidget {
  const GreenfieldTicketsPage({super.key});

  @override
  State<GreenfieldTicketsPage> createState() => _GreenfieldTicketsPageState();
}

class _GreenfieldTicketsPageState extends State<GreenfieldTicketsPage> {
  bool _loading = true;
  String? _error;
  List<TicketModel> _tickets = const [];
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final tickets = await AppScope.of(context).api.getTickets();
      if (!mounted) return;
      setState(() {
        _tickets = tickets;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('ApiException: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _refresh() async {
    await _load();
    if (!mounted || _error != null) return;
    AppToast.show(
      context,
      context.l10n.refreshed,
      type: AppToastType.success,
    );
  }

  void _openNewTicket() {
    showAppAdaptiveModal<void>(
      context: context,
      builder: (_) => GreenfieldNewTicketModal(onCreated: _load),
    );
  }

  void _openTicketDetail(TicketModel ticket) {
    showAppAdaptiveModal<void>(
      context: context,
      builder: (_) => GreenfieldTicketDetailModal(
        ticket: ticket,
        onChanged: _load,
      ),
    );
  }

  Widget _body(BuildContext context) {
    if (_loading) return const PageLoadingCard();
    if (_error != null) {
      return PageStateCard(
        icon: LucideIcons.circleAlert,
        title: context.l10n.ticketLoadFailed,
        subtitle: AppErrorMessageService.userFacing(_error!, context.l10n),
        onTap: _load,
      );
    }
    if (_tickets.isEmpty) {
      return PageStateCard(
        icon: LucideIcons.messageSquare,
        title: context.l10n.noTickets,
        subtitle: context.l10n.noTicketsSubtitle,
        onTap: _openNewTicket,
      );
    }
    return GreenfieldTicketsSurface(
      tickets: _tickets,
      onOpenTicket: _openTicketDetail,
      onCreateTicket: _openNewTicket,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ResponsivePageScaffold(
      title: context.l10n.ticketSupport,
      subtitle: context.l10n.ticketSupportSubtitle,
      compactTitle: context.l10n.tickets,
      compactSubtitle: context.l10n.ticketSupportCompactSubtitle,
      primaryCompact: isPrimaryCompactTab(AppPage.tickets),
      onRefresh: _refresh,
      onBack: () => AppScope.of(context).goToPage(AppPage.account),
      children: [_body(context)],
    );
  }
}
