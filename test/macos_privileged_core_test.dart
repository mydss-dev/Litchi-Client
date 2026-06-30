import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/shared/services/macos_privileged_core.dart';

void main() {
  test('builds a quoted one-shot macOS TUN launch command', () {
    final command = MacOsPrivilegedCoreSession.buildLaunchCommand(
      executable: "/Applications/Client's App.app/Contents/Resources/mihomo",
      dataDirectory: '/tmp/client tun/runtime',
      configPath: '/tmp/client tun/config.yaml',
      appPid: 4242,
      ownerUid: 501,
      stopPath: '/tmp/client tun/runtime/.stop',
      logPath: '/tmp/client tun/runtime/mihomo.log',
      runtimePath: '/tmp/client tun/runtime',
    );

    expect(command, contains('/usr/bin/nohup'));
    expect(command, contains(r'watcher "$core_pid" 4242'));
    expect(command, contains('/usr/sbin/chown 501'));
    expect(command, contains("'\"'\"'"));
    expect(command, contains(r'/bin/kill -TERM "$core_pid"'));
    expect(command, contains(r'/bin/rm -rf "$runtime_dir"'));
  });

  test('recognizes the standard macOS authorization cancellation', () {
    const error = MacOsPrivilegeException(
      'execution error: User canceled. (-128)',
    );
    expect(error.wasCancelled, isTrue);
  });

  test('prepares an isolated runtime and accepts the privileged pid', () async {
    final source = await Directory.systemTemp.createTemp('mac-core-test-');
    addTearDown(() async {
      if (await source.exists()) await source.delete(recursive: true);
    });
    await File(
      '${source.path}${Platform.pathSeparator}country.mmdb',
    ).writeAsString('geo');
    final config = File('${source.path}${Platform.pathSeparator}config.yaml');
    await config.writeAsString('mixed-port: 7890');
    String? command;

    final session = await MacOsPrivilegedCoreSession.start(
      executable: '/Applications/Client.app/Contents/Resources/mihomo',
      dataDirectory: source.path,
      configPath: config.path,
      appPid: 4242,
      ownerUid: 501,
      runner: (value) async {
        command = value;
        return ProcessResult(1, 0, '9876\n', '');
      },
    );
    addTearDown(session.cleanupFiles);

    expect(session.pid, 9876);
    expect(command, contains(session.runtimeDirectory.path));
    expect(
      await File(
        '${session.runtimeDirectory.path}${Platform.pathSeparator}country.mmdb',
      ).readAsString(),
      'geo',
    );
  });
}
