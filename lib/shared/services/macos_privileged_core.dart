import 'dart:async';
import 'dart:io';

import 'secure_logger.dart';

typedef MacOsPrivilegeRunner = Future<ProcessResult> Function(String command);

/// One-shot privileged mihomo launcher for macOS TUN mode.
///
/// The system password dialog is shown only while starting TUN. A tiny
/// root-owned watchdog then stops mihomo when either the unprivileged app
/// creates [stopFile] or the app process disappears. This avoids a second
/// password prompt on disconnect and prevents root-owned orphan cores after a
/// force quit.
final class MacOsPrivilegedCoreSession {
  MacOsPrivilegedCoreSession._({
    required this.pid,
    required this.stopFile,
    required this.logFile,
    required this.runtimeDirectory,
  });

  final int pid;
  final File stopFile;
  final File logFile;
  final Directory runtimeDirectory;

  static Future<MacOsPrivilegedCoreSession> start({
    required String executable,
    required String dataDirectory,
    required String configPath,
    required int appPid,
    int? ownerUid,
    MacOsPrivilegeRunner runner = _runWithAdministratorPrivileges,
  }) async {
    final persistentDataDir = Directory(dataDirectory);
    await persistentDataDir.create(recursive: true);
    final nonce = DateTime.now().microsecondsSinceEpoch;
    final uid = ownerUid ?? await _currentUserId();
    final runtimeDirectory = Directory(
      '${Directory.systemTemp.path}${Platform.pathSeparator}'
      'client-tun-$uid-$nonce',
    );
    await runtimeDirectory.create(recursive: true);
    await _copyRuntimeAssets(persistentDataDir, runtimeDirectory);
    final stopFile = File(
      '${runtimeDirectory.path}${Platform.pathSeparator}.stop',
    );
    final logFile = File(
      '${runtimeDirectory.path}${Platform.pathSeparator}mihomo.log',
    );
    await _deleteIfExists(stopFile);
    await _deleteIfExists(logFile);

    final command = buildLaunchCommand(
      executable: executable,
      dataDirectory: runtimeDirectory.path,
      configPath: configPath,
      appPid: appPid,
      ownerUid: uid,
      stopPath: stopFile.path,
      logPath: logFile.path,
      runtimePath: runtimeDirectory.path,
    );
    final result = await runner(command).timeout(const Duration(minutes: 2));
    if (result.exitCode != 0) {
      final message = '${result.stderr}'.trim();
      await _deleteIfExists(stopFile);
      await _deleteIfExists(logFile);
      await _deleteDirectoryIfExists(runtimeDirectory);
      throw MacOsPrivilegeException(
        message.isEmpty ? 'Administrator authorization was denied' : message,
      );
    }

    final output = '${result.stdout}'.trim();
    final pid = int.tryParse(output.split(RegExp(r'\s+')).last);
    if (pid == null || pid <= 0) {
      await _deleteIfExists(stopFile);
      await _deleteIfExists(logFile);
      await _deleteDirectoryIfExists(runtimeDirectory);
      throw const MacOsPrivilegeException(
        'The privileged launcher did not return a valid process ID',
      );
    }
    return MacOsPrivilegedCoreSession._(
      pid: pid,
      stopFile: stopFile,
      logFile: logFile,
      runtimeDirectory: runtimeDirectory,
    );
  }

  static String buildLaunchCommand({
    required String executable,
    required String dataDirectory,
    required String configPath,
    required int appPid,
    required int ownerUid,
    required String stopPath,
    required String logPath,
    required String runtimePath,
  }) {
    const watchdog = r'''
core_pid="$1"
app_pid="$2"
stop_file="$3"
runtime_dir="$4"
while /bin/kill -0 "$app_pid" 2>/dev/null &&
      /bin/kill -0 "$core_pid" 2>/dev/null &&
      [ ! -e "$stop_file" ]; do
  /bin/sleep 1
done
/bin/kill -TERM "$core_pid" 2>/dev/null || true
i=0
while /bin/kill -0 "$core_pid" 2>/dev/null && [ "$i" -lt 20 ]; do
  /bin/sleep 0.1
  i=$((i + 1))
done
/bin/kill -KILL "$core_pid" 2>/dev/null || true
/bin/rm -rf "$runtime_dir"
''';

    return [
      '/usr/bin/touch ${_shellQuote(logPath)}',
      '/usr/sbin/chown $ownerUid ${_shellQuote(logPath)}',
      '/bin/chmod 600 ${_shellQuote(logPath)}',
      '/usr/bin/nohup ${_shellQuote(executable)}'
          ' -d ${_shellQuote(dataDirectory)}'
          ' -f ${_shellQuote(configPath)}'
          ' >> ${_shellQuote(logPath)} 2>&1 &',
      r'core_pid=$!',
      '/usr/bin/nohup /bin/sh -c ${_shellQuote(watchdog)}'
          ' watcher "\$core_pid" $appPid ${_shellQuote(stopPath)}'
          ' ${_shellQuote(runtimePath)}'
          ' >/dev/null 2>&1 &',
      r'/bin/echo "$core_pid"',
    ].join('; ');
  }

  Future<bool> stop({Duration timeout = const Duration(seconds: 5)}) async {
    try {
      await stopFile.writeAsString('stop\n', flush: true);
    } catch (error) {
      SecureLogger.warn('macOS TUN stop signal failed', error);
      return false;
    }

    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      if (!await isRunning()) {
        await cleanupFiles();
        return true;
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    SecureLogger.warn(
      'macOS privileged mihomo did not stop before timeout',
      'pid=$pid',
    );
    return false;
  }

  void requestStopSync() {
    try {
      stopFile.writeAsStringSync('stop\n', flush: true);
    } catch (_) {
      // The root watchdog also observes the app PID and will stop on exit.
    }
  }

  Future<bool> isRunning() async {
    // An unprivileged process receives EPERM from `kill -0` for a root-owned
    // mihomo even while it is healthy. `ps` is read-only and reports the
    // process reliably without requiring another authorization prompt.
    final result = await Process.run('/bin/ps', [
      '-p',
      '$pid',
      '-o',
      'pid=',
    ]).timeout(const Duration(seconds: 2));
    return result.exitCode == 0 && '${result.stdout}'.trim() == '$pid';
  }

  Future<String> readLogTail({int maxChars = 8000}) async {
    try {
      if (!await logFile.exists()) return '';
      final text = await logFile.readAsString();
      return text.length <= maxChars
          ? text
          : text.substring(text.length - maxChars);
    } catch (_) {
      return '';
    }
  }

  Future<void> cleanupFiles() async {
    await _deleteIfExists(stopFile);
    await _deleteIfExists(logFile);
    await _deleteDirectoryIfExists(runtimeDirectory);
  }

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
    if (result.exitCode != 0 || uid == null || uid < 0) {
      throw const MacOsPrivilegeException('Unable to resolve the current user');
    }
    return uid;
  }

  static String _shellQuote(String value) =>
      "'${value.replaceAll("'", "'\"'\"'")}'";

  static Future<void> _deleteIfExists(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {
      // Best-effort cleanup only.
    }
  }

  static Future<void> _deleteDirectoryIfExists(Directory directory) async {
    try {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    } catch (_) {
      // Root-owned runtime files may still be disappearing via the watchdog.
    }
  }

  static Future<void> _copyRuntimeAssets(
    Directory source,
    Directory destination,
  ) async {
    for (final name in const ['country.mmdb', 'geosite.dat', 'geoip.dat']) {
      final file = File('${source.path}${Platform.pathSeparator}$name');
      if (!await file.exists()) continue;
      await file.copy('${destination.path}${Platform.pathSeparator}$name');
    }
    final providers = Directory(
      '${source.path}${Platform.pathSeparator}providers',
    );
    if (await providers.exists()) {
      await _copyDirectory(
        providers,
        Directory('${destination.path}${Platform.pathSeparator}providers'),
      );
    }
  }

  static Future<void> _copyDirectory(
    Directory source,
    Directory destination,
  ) async {
    await destination.create(recursive: true);
    await for (final entity in source.list(followLinks: false)) {
      final name = entity.uri.pathSegments
          .where((segment) => segment.isNotEmpty)
          .last;
      final target = '${destination.path}${Platform.pathSeparator}$name';
      if (entity is File) {
        await entity.copy(target);
      } else if (entity is Directory) {
        await _copyDirectory(entity, Directory(target));
      }
    }
  }
}

final class MacOsPrivilegeException implements Exception {
  const MacOsPrivilegeException(this.message);

  final String message;

  bool get wasCancelled =>
      message.contains('(-128)') ||
      message.toLowerCase().contains('user canceled');

  @override
  String toString() => message;
}
