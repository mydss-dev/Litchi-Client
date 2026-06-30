import 'dart:async';
import 'dart:io';

import '../../config/app_identity.dart';
import 'secure_logger.dart';

typedef MacOsPfPrivilegeRunner = Future<ProcessResult> Function(String command);

abstract final class MacOsTunKillSwitch {
  static _MacOsPfSession? _session;

  static Future<bool> engage({
    required Set<String> tunnelInterfaces,
    MacOsPfPrivilegeRunner runner = _runWithAdministratorPrivileges,
  }) async {
    if (!Platform.isMacOS) return true;
    final interfaces = tunnelInterfaces
        .where((name) => RegExp(r'^utun\d+$').hasMatch(name))
        .toSet();
    if (interfaces.isEmpty) return false;
    await release();
    try {
      _session = await _MacOsPfSession.start(
        appPid: pid,
        ownerUid: await _currentUserId(),
        tunnelInterfaces: interfaces,
        anchorName: 'com.apple/client_${AppIdentity.storageKey}',
        runner: runner,
      );
      return true;
    } catch (error) {
      SecureLogger.warn('macOS TUN kill switch engage failed', error);
      _session = null;
      return false;
    }
  }

  static Future<void> release() async {
    final session = _session;
    _session = null;
    if (session == null) return;
    await session.stop();
  }

  static void releaseSync() {
    _session?.requestStopSync();
    _session = null;
  }

  static String buildRules({
    required int ownerUid,
    required Set<String> tunnelInterfaces,
  }) {
    final interfaces =
        tunnelInterfaces
            .where((name) => RegExp(r'^utun\d+$').hasMatch(name))
            .toList()
          ..sort();
    return [
      'pass quick on lo0 all',
      for (final name in interfaces) 'pass out quick on $name all',
      'block drop out quick proto { tcp, udp } all user $ownerUid',
      '',
    ].join('\n');
  }

  static String buildEngageCommand({
    required int appPid,
    required String anchorName,
    required String stopPath,
    required String rulesPath,
    required String runtimePath,
  }) => _MacOsPfSession.buildEngageCommand(
    appPid: appPid,
    anchorName: anchorName,
    stopPath: stopPath,
    rulesPath: rulesPath,
    runtimePath: runtimePath,
  );

  static Future<ProcessResult> _runWithAdministratorPrivileges(String command) {
    return Process.run('/usr/bin/osascript', [
      '-e',
      'on run argv',
      '-e',
      'do shell script (item 1 of argv) with administrator privileges',
      '-e',
      'end run',
      command,
    ]);
  }

  static Future<int> _currentUserId() async {
    final result = await Process.run('/usr/bin/id', ['-u']);
    final uid = int.tryParse('${result.stdout}'.trim());
    if (result.exitCode != 0 || uid == null || uid <= 0) {
      throw StateError('Unable to resolve the current macOS user');
    }
    return uid;
  }
}

final class _MacOsPfSession {
  const _MacOsPfSession({
    required this.stopFile,
    required this.runtimeDirectory,
  });

  final File stopFile;
  final Directory runtimeDirectory;

  static Future<_MacOsPfSession> start({
    required int appPid,
    required int ownerUid,
    required Set<String> tunnelInterfaces,
    required String anchorName,
    required MacOsPfPrivilegeRunner runner,
  }) async {
    final nonce = DateTime.now().microsecondsSinceEpoch;
    final runtimeDirectory = Directory(
      '${Directory.systemTemp.path}${Platform.pathSeparator}'
      'client-pf-$ownerUid-$nonce',
    );
    await runtimeDirectory.create(recursive: true);
    final stopFile = File(
      '${runtimeDirectory.path}${Platform.pathSeparator}.stop',
    );
    final rulesFile = File(
      '${runtimeDirectory.path}${Platform.pathSeparator}rules.conf',
    );
    await rulesFile.writeAsString(
      MacOsTunKillSwitch.buildRules(
        ownerUid: ownerUid,
        tunnelInterfaces: tunnelInterfaces,
      ),
      flush: true,
    );

    final command = buildEngageCommand(
      appPid: appPid,
      anchorName: anchorName,
      stopPath: stopFile.path,
      rulesPath: rulesFile.path,
      runtimePath: runtimeDirectory.path,
    );
    final result = await runner(command).timeout(const Duration(minutes: 2));
    if (result.exitCode != 0) {
      await _deleteDirectory(runtimeDirectory);
      throw StateError(
        '${result.stderr}'.trim().isEmpty
            ? 'Unable to install macOS PF rules'
            : '${result.stderr}'.trim(),
      );
    }
    return _MacOsPfSession(
      stopFile: stopFile,
      runtimeDirectory: runtimeDirectory,
    );
  }

  static String buildEngageCommand({
    required int appPid,
    required String anchorName,
    required String stopPath,
    required String rulesPath,
    required String runtimePath,
  }) {
    const watchdog = r'''
app_pid="$1"
stop_file="$2"
anchor_name="$3"
pf_token="$4"
runtime_dir="$5"
while /bin/kill -0 "$app_pid" 2>/dev/null && [ ! -e "$stop_file" ]; do
  /bin/sleep 1
done
/sbin/pfctl -a "$anchor_name" -F all >/dev/null 2>&1 || true
if [ -n "$pf_token" ]; then
  /sbin/pfctl -X "$pf_token" >/dev/null 2>&1 || true
fi
/bin/rm -rf "$runtime_dir"
''';

    return [
      'pf_output=\$(/sbin/pfctl -E 2>&1)',
      r'''pf_token=$(/bin/echo "$pf_output" | /usr/bin/sed -n 's/^Token : //p' | /usr/bin/head -n 1)''',
      '(/sbin/pfctl -a ${_quote(anchorName)} -f ${_quote(rulesPath)} || '
          '{ [ -z "\$pf_token" ] || /sbin/pfctl -X "\$pf_token"; exit 1; })',
      '/usr/bin/nohup /bin/sh -c ${_quote(watchdog)}'
          ' watcher $appPid ${_quote(stopPath)} ${_quote(anchorName)}'
          ' "\$pf_token" ${_quote(runtimePath)} >/dev/null 2>&1 &',
      '/bin/echo pf-ready',
    ].join(' && ');
  }

  Future<void> stop() async {
    try {
      await stopFile.writeAsString('stop\n', flush: true);
      final deadline = DateTime.now().add(const Duration(seconds: 5));
      while (DateTime.now().isBefore(deadline)) {
        if (!await runtimeDirectory.exists()) return;
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      SecureLogger.warn('macOS PF watchdog cleanup timed out');
    } catch (error) {
      SecureLogger.warn('macOS PF stop signal failed', error);
    }
  }

  void requestStopSync() {
    try {
      stopFile.writeAsStringSync('stop\n', flush: true);
    } catch (_) {
      // The root watchdog also observes the app process.
    }
  }

  static String _quote(String value) => "'${value.replaceAll("'", "'\"'\"'")}'";

  static Future<void> _deleteDirectory(Directory directory) async {
    try {
      if (await directory.exists()) await directory.delete(recursive: true);
    } catch (_) {
      // Best-effort cleanup only.
    }
  }
}
