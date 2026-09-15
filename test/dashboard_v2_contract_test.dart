import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/app/core_controller.dart';
import 'package:litchi_client/features/dashboard/widgets/litchi_connection_orb.dart';

void main() {
  test('LitchiConnectionOrb keeps the frozen Dashboard V2 size', () {
    final orb = LitchiConnectionOrb(
      status: ConnectionStatus.disconnected,
      onPressed: () {},
    );

    expect(orb.size, 136);
  });
}
