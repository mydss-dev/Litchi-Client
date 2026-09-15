import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('OrdersPage and showOrdersModal delegate to Greenfield Orders', () {
    final source = File(
      'lib/features/orders/orders_page.dart',
    ).readAsStringSync();

    expect(source, contains("import 'greenfield_orders_page.dart';"));
    expect(source, contains('Future<void> showOrdersModal(BuildContext context)'));
    expect(source, contains('GreenfieldOrdersPage(modal: modal)'));
    expect(source, isNot(contains('_OrderCard')));
    expect(source, isNot(contains('_OrderActionButton')));
    expect(source, isNot(contains('_CancelOrderModal')));
  });

  test('greenfield orders surface keeps a stable runtime marker', () {
    final source = File(
      'lib/features/orders/widgets/greenfield_orders_surface.dart',
    ).readAsStringSync();

    expect(source, contains("ValueKey('greenfield-orders-surface')"));
    expect(source, contains('AppPlatform.usesTouch'));
  });
}
