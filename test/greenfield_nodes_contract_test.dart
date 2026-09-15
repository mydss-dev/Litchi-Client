import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/features/nodes/widgets/greenfield_node_tile.dart';

void main() {
  test('greenfield node rows keep desktop and Android target heights', () {
    expect(GreenfieldNodeTile.desktopHeight, 62);
    expect(GreenfieldNodeTile.compactHeight, 76);

    expect(
      GreenfieldNodeTile.desktopHeight,
      inInclusiveRange(60, 64),
    );
    expect(
      GreenfieldNodeTile.compactHeight,
      greaterThanOrEqualTo(72),
    );
  });
}
