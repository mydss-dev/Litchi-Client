import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/shared/services/macos_tun_kill_switch.dart';

void main() {
  test(
    'builds PF rules that allow the tunnel and block direct user traffic',
    () {
      final rules = MacOsTunKillSwitch.buildRules(
        ownerUid: 501,
        tunnelInterfaces: {'utun8', 'invalid;name', 'utun3'},
      );

      expect(rules, contains('pass quick on lo0 all'));
      expect(rules, contains('pass out quick on utun3 all'));
      expect(rules, contains('pass out quick on utun8 all'));
      expect(rules, isNot(contains('invalid;name')));
      expect(
        rules,
        contains('block drop out quick proto { tcp, udp } all user 501'),
      );
    },
  );

  test('PF watchdog is tied to app lifetime and flushes only its anchor', () {
    final command = MacOsTunKillSwitch.buildEngageCommand(
      appPid: 1234,
      anchorName: 'com.apple/client_demo',
      stopPath: '/tmp/client pf/.stop',
      rulesPath: '/tmp/client pf/rules.conf',
      runtimePath: '/tmp/client pf',
    );

    expect(command, contains('/sbin/pfctl -E'));
    expect(command, contains('com.apple/client_demo'));
    expect(command, contains('/bin/kill -0 "\$app_pid"'));
    expect(command, contains('-F all'));
    expect(command, contains('/sbin/pfctl -X "\$pf_token"'));
  });
}
