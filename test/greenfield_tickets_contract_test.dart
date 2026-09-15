import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('TicketsPage delegates to Greenfield Tickets', () {
    final source = File(
      'lib/features/tickets/tickets_page.dart',
    ).readAsStringSync();

    expect(source, contains("import 'greenfield_tickets_page.dart';"));
    expect(source, contains('GreenfieldTicketsPage'));
    expect(source, isNot(contains('_TicketCard')));
    expect(source, isNot(contains('_PrioritySelector')));
    expect(source, isNot(contains('_TicketDetailModal')));
  });

  test('greenfield tickets surface keeps a stable runtime marker', () {
    final source = File(
      'lib/features/tickets/widgets/greenfield_tickets_surface.dart',
    ).readAsStringSync();

    expect(source, contains("ValueKey('greenfield-tickets-surface')"));
    expect(source, contains('AppPlatform.usesTouch'));
  });

  test('greenfield new ticket keeps subscription mismatch compatibility', () {
    final source = File(
      'lib/features/tickets/widgets/greenfield_new_ticket_modal.dart',
    ).readAsStringSync();

    expect(source, contains('ticketBestEffort(api.getUserInfo())'));
    expect(source, contains('ticketBestEffort(api.getSubscribeInfo())'));
    expect(source, contains('isTicketSubscriptionRequiredError'));
    expect(source, contains('ticketAccountHasActiveSubscription'));
  });
}
