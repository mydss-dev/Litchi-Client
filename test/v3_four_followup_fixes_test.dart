import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/shared/models/app_models.dart';
import 'package:litchi_client/v3/pages/v3_dashboard_page.dart';

void main() {
  test('only desktop platforms display system proxy', () {
    for (final platform in [TargetPlatform.windows, TargetPlatform.macOS]) {
      expect(v3ShowsNetworkMode(platform, NetworkMode.system), isTrue);
      expect(v3ShowsNetworkMode(platform, NetworkMode.tun), isTrue);
    }
    for (final platform in [TargetPlatform.android, TargetPlatform.linux]) {
      expect(v3ShowsNetworkMode(platform, NetworkMode.system), isFalse);
      expect(v3ShowsNetworkMode(platform, NetworkMode.tun), isTrue);
    }
  });
}
