import 'dart:convert';
import 'dart:io';

import 'secure_logger.dart';
import 'windows_registry.dart';
import 'wininet_notify.dart';

/// Sets / clears the system HTTP(S) proxy.
///
/// Windows: HKCU Internet Settings registry + a WinInet broadcast.
/// macOS: `networksetup` web/secure-web proxy on every enabled network service.
abstract final class ProxySetter {
  static const _key =
      r'Software\Microsoft\Windows\CurrentVersion\Internet Settings';
  static const _snapshotName = 'proxy_snapshot.json';
  static Future<void> _pendingUpdate = Future<void>.value();

  static Future<void> enable({int port = 7890}) => _schedule(() async {
    if (Platform.isWindows) return _winEnable(port);
    if (Platform.isMacOS) return _macSetProxy('127.0.0.1', port);
  });

  /// Kill-switch: point the system proxy at a dead local port so proxy-aware
  /// traffic fails closed instead of leaking directly when the tunnel drops.
  /// Cleared automatically on the next [enable] / [disable] or on app exit.
  ///
  /// Note: protects proxy-aware apps in system-proxy mode. Apps that open raw
  /// sockets ignoring the system proxy are not covered — a full firewall
  /// kill-switch is the follow-up for that threat model.
  static Future<void> engageKillSwitch() => _schedule(() async {
    // 127.0.0.1:1 — nothing listens here, so every proxied request is refused.
    if (Platform.isWindows) return _winKillSwitch();
    if (Platform.isMacOS) return _macSetProxy('127.0.0.1', 1);
  });

  /// Clears the system proxy. [notify] broadcasts the change to WinInet so
  /// open browsers pick it up immediately — skip it on app exit, where the
  /// registry write already takes effect and waiting on the FFI call would
  /// stall shutdown. (macOS applies immediately, so [notify] is a no-op.)
  static Future<void> disable({bool notify = true}) => _schedule(() async {
    if (Platform.isWindows) return _winDisable(notify: notify);
    if (Platform.isMacOS) return _macDisable();
  });

  /// On startup: if the system proxy still points to our previous Litchi
  /// snapshot and no application-owned core is alive, restore it silently.
  /// Without a valid snapshot, do nothing — another proxy app may own 127.0.0.1.
  static Future<void> disableIfStale() => _schedule(() async {
    if (Platform.isWindows) return _winDisableIfStale();
    if (Platform.isMacOS) return _macDisableIfStale();
  });

  static Future<void> _schedule(Future<void> Function() operation) {
    final result = _pendingUpdate.then((_) => operation());
    _pendingUpdate = result.catchError((_) {
      // intentional: cascade error in scheduler chain, surfaced upstream
    });
    return result;
  }

  // ── Windows (registry + WinInet) ───────────────────────────────────────────

  static Future<void> _winEnable(int port) async {
    await _winSaveSnapshotIfNeeded(port);
    // ProxyServer first: if either write fails, the proxy is never left
    // enabled while pointing at a stale address.
    WindowsRegistry.writeString(_key, 'ProxyServer', '127.0.0.1:$port');
    WindowsRegistry.writeDword(_key, 'ProxyEnable', 1);
    await _notify();
  }

  static Future<void> _winKillSwitch() async {
    await _winSaveSnapshotIfNeeded(1);
    WindowsRegistry.writeString(_key, 'ProxyServer', '127.0.0.1:1');
    WindowsRegistry.writeDword(_key, 'ProxyEnable', 1);
    await _notify();
  }

  static Future<void> _winDisable({bool notify = true}) async {
    try {
      final restored = await _winRestoreSnapshotIfOwned();
      if (!restored) return;
    } catch (e) {
      SecureLogger.warn('ProxySetter.disable failed', e);
    }
    if (notify) await _notify();
  }

  static Future<void> _winDisableIfStale() async {
    try {
      final enable = WindowsRegistry.readDword(_key, 'ProxyEnable');
      if (enable != 1) return;
      final server = WindowsRegistry.readString(_key, 'ProxyServer');
      if (server != null && server.contains('127.0.0.1:')) {
        await _winRestoreSnapshotIfOwned();
      }
    } catch (e) {
      SecureLogger.warn('ProxySetter.disableIfStale failed', e);
    }
  }

  static Future<void> _winSaveSnapshotIfNeeded(int port) async {
    final file = await _snapshotFile();
    if (await _updateSnapshotOwner(file, 'windows', port)) return;
    final snapshot = <String, Object?>{
      'platform': 'windows',
      'owner_host': '127.0.0.1',
      'owner_port': port,
      'proxy_enable': WindowsRegistry.readDword(_key, 'ProxyEnable'),
      'proxy_server': WindowsRegistry.readString(_key, 'ProxyServer'),
      'proxy_override': WindowsRegistry.readString(_key, 'ProxyOverride'),
      'saved_at': DateTime.now().toIso8601String(),
    };
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(snapshot), flush: true);
  }

  static Future<bool> _winRestoreSnapshotIfOwned() async {
    final file = await _snapshotFile();
    if (!await file.exists()) return false;

    Map<String, dynamic>? snapshot;
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is Map<String, dynamic>) snapshot = decoded;
    } catch (_) {
      // intentional: parse attempt, fallback handled below
    }
    if (snapshot == null || snapshot['platform'] != 'windows') {
      await _deleteSnapshot();
      return false;
    }

    final ownerPort = _ownerPort(snapshot);
    final currentServer = WindowsRegistry.readString(_key, 'ProxyServer') ?? '';
    if (!_isOwnedLocalProxyServer(currentServer, ownerPort)) {
      // The user or another app changed the proxy while Litchi was running.
      // Do not overwrite that newer choice.
      await _deleteSnapshot();
      return true;
    }

    final oldServer = snapshot['proxy_server'] as String?;
    final oldOverride = snapshot['proxy_override'] as String?;
    final oldEnable = snapshot['proxy_enable'] as int? ?? 0;

    if (oldServer != null) {
      WindowsRegistry.writeString(_key, 'ProxyServer', oldServer);
    } else {
      WindowsRegistry.deleteValue(_key, 'ProxyServer');
    }
    if (oldOverride != null) {
      WindowsRegistry.writeString(_key, 'ProxyOverride', oldOverride);
    } else {
      WindowsRegistry.deleteValue(_key, 'ProxyOverride');
    }
    WindowsRegistry.writeDword(_key, 'ProxyEnable', oldEnable == 0 ? 0 : 1);
    await _deleteSnapshot();
    return true;
  }

  static int _ownerPort(Map<String, dynamic> snapshot) {
    final value = snapshot['owner_port'];
    if (value is int && value > 0) return value;
    if (value is num && value > 0) return value.toInt();
    return 0;
  }

  static bool _isOwnedLocalProxyServer(String value, int ownerPort) {
    final lower = value.toLowerCase().trim();
    if (!_isLocalProxyServer(lower)) return false;
    if (ownerPort <= 0) return true;
    return _containsLocalEndpoint(lower, ownerPort) ||
        // Kill-switch is also ours; it intentionally rewrites the proxy port to 1.
        _containsLocalEndpoint(lower, 1);
  }

  static bool _containsLocalEndpoint(String lower, int port) {
    for (final token in lower.split(RegExp(r'[;\s]+'))) {
      final endpoint = token.contains('=') ? token.split('=').last : token;
      if (endpoint == '127.0.0.1:$port' || endpoint == 'localhost:$port') {
        return true;
      }
    }
    return false;
  }

  static bool _isLocalProxyServer(String value) {
    final lower = value.toLowerCase();
    return lower.contains('127.0.0.1:') || lower.contains('localhost:');
  }

  /// Notify WinInet so browsers pick up the registry change immediately.
  /// Uses Dart FFI to call InternetSetOptionW directly — no PowerShell, no
  /// temporary scripts, no DLL compilation.
  static Future<void> _notify() async {
    try {
      WinInetNotify.notifyChanged();
    } catch (e) {
      SecureLogger.warn('WinInet notify failed', e);
    }
  }

  // ── macOS (networksetup) ───────────────────────────────────────────────────

  /// Enabled network services (Wi-Fi, Ethernet, …). In
  /// `networksetup -listallnetworkservices` a leading '*' marks a disabled
  /// service, and the first line is an informational header.
  static Future<List<String>> _macNetworkServices() async {
    try {
      final r = await Process.run('networksetup', ['-listallnetworkservices']);
      if (r.exitCode != 0) return const [];
      return const LineSplitter()
          .convert('${r.stdout}')
          .skip(1)
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty && !l.startsWith('*'))
          .toList();
    } catch (e) {
      SecureLogger.warn('networksetup list failed', e);
      return const [];
    }
  }

  static Future<void> _macSetProxy(String host, int port) async {
    await _macSaveSnapshotIfNeeded(port);
    final services = await _macNetworkServices();
    if (services.isEmpty) {
      throw StateError('macOS did not return any enabled network services');
    }
    try {
      for (final service in services) {
        await _macRun([
          '-setwebproxy',
          service,
          host,
          '$port',
        ], throwOnError: true);
        await _macRun([
          '-setsecurewebproxy',
          service,
          host,
          '$port',
        ], throwOnError: true);
        await _macRun(['-setwebproxystate', service, 'on'], throwOnError: true);
        await _macRun([
          '-setsecurewebproxystate',
          service,
          'on',
        ], throwOnError: true);
      }
    } catch (_) {
      // intentional: best-effort snapshot restore on failure, then rethrow
      await _macRestoreSnapshotIfOwned();
      rethrow;
    }
  }

  static Future<void> _macDisable() async {
    await _macRestoreSnapshotIfOwned();
  }

  static Future<void> _macDisableIfStale() async {
    for (final service in await _macNetworkServices()) {
      try {
        final r = await Process.run('networksetup', ['-getwebproxy', service]);
        final out = '${r.stdout}';
        if (out.contains('Enabled: Yes') && out.contains('127.0.0.1')) {
          await _macRestoreSnapshotIfOwned();
        }
      } catch (e) {
        SecureLogger.warn('networksetup getwebproxy failed', e);
      }
    }
  }

  static Future<void> _macRun(
    List<String> args, {
    bool throwOnError = false,
  }) async {
    final r = await Process.run('networksetup', args);
    if (r.exitCode != 0) {
      final error =
          'networksetup ${args.first} failed (exit ${r.exitCode}): ${r.stderr}';
      SecureLogger.warn(error);
      if (throwOnError) throw StateError(error);
    }
  }

  static Future<void> _macSaveSnapshotIfNeeded(int port) async {
    final file = await _snapshotFile();
    if (await _updateSnapshotOwner(file, 'macos', port)) return;
    final services = <Map<String, Object?>>[];
    for (final service in await _macNetworkServices()) {
      services.add({
        'name': service,
        'web': _parseMacProxy(await _macGetProxy('-getwebproxy', service)),
        'secure': _parseMacProxy(
          await _macGetProxy('-getsecurewebproxy', service),
        ),
      });
    }
    if (services.isEmpty) {
      throw StateError('macOS did not return any enabled network services');
    }
    await file.parent.create(recursive: true);
    await file.writeAsString(
      jsonEncode({
        'platform': 'macos',
        'owner_host': '127.0.0.1',
        'owner_port': port,
        'services': services,
        'saved_at': DateTime.now().toIso8601String(),
      }),
      flush: true,
    );
  }

  static Future<bool> _macRestoreSnapshotIfOwned() async {
    final file = await _snapshotFile();
    if (!await file.exists()) return false;

    Map<String, dynamic>? snapshot;
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is Map<String, dynamic>) snapshot = decoded;
    } catch (_) {
      // intentional: parse attempt, fallback handled below
    }
    if (snapshot == null || snapshot['platform'] != 'macos') {
      await _deleteSnapshot();
      return false;
    }

    final services = snapshot['services'];
    if (services is! List) {
      await _deleteSnapshot();
      return false;
    }

    final ownerPort = _ownerPort(snapshot);
    for (final item in services) {
      if (item is! Map) continue;
      final service = item['name']?.toString();
      if (service == null || service.isEmpty) continue;
      for (final command in const ['-getwebproxy', '-getsecurewebproxy']) {
        final current = _parseMacProxy(await _macGetProxy(command, service));
        final server = current['server']?.toString() ?? '';
        final port = current['port'];
        final currentServer = port is int && port > 0
            ? '$server:$port'
            : server;
        if (current['enabled'] == true &&
            !_isOwnedLocalProxyServer(currentServer, ownerPort)) {
          await _deleteSnapshot();
          return true;
        }
      }
    }

    for (final item in services) {
      if (item is! Map) continue;
      final service = item['name']?.toString();
      if (service == null || service.isEmpty) continue;
      await _macRestoreOne(service, 'web', item['web']);
      await _macRestoreOne(service, 'secureweb', item['secure']);
    }
    await _deleteSnapshot();
    return true;
  }

  static Future<String> _macGetProxy(String command, String service) async {
    try {
      final r = await Process.run('networksetup', [command, service]);
      return r.exitCode == 0 ? '${r.stdout}' : '';
    } catch (_) {
      // intentional: best-effort proxy query, failure is safe to ignore
      return '';
    }
  }

  static Map<String, Object?> _parseMacProxy(String output) {
    String? read(String key) {
      final match = RegExp(
        '^$key:\\s*(.*)\$',
        multiLine: true,
      ).firstMatch(output);
      return match?.group(1)?.trim();
    }

    final enabled = (read('Enabled') ?? '').toLowerCase() == 'yes';
    final server = read('Server');
    final port = int.tryParse(read('Port') ?? '');
    return {'enabled': enabled, 'server': server, 'port': port};
  }

  static Future<void> _macRestoreOne(
    String service,
    String kind,
    Object? raw,
  ) async {
    final data = raw is Map ? _dataFromMap(raw) : const <String, Object?>{};
    final enabled = data['enabled'] == true;
    final server = data['server']?.toString();
    final port = data['port'];
    final setCommand = kind == 'web' ? '-setwebproxy' : '-setsecurewebproxy';
    final stateCommand = kind == 'web'
        ? '-setwebproxystate'
        : '-setsecurewebproxystate';
    if (server != null && server.isNotEmpty && port is int && port > 0) {
      await _macRun([setCommand, service, server, '$port']);
    }
    await _macRun([stateCommand, service, enabled ? 'on' : 'off']);
  }

  static Map<String, Object?> _dataFromMap(Map raw) => {
    for (final entry in raw.entries) entry.key.toString(): entry.value,
  };

  static Future<File> _snapshotFile() async {
    final base = Platform.isWindows
        ? (Platform.environment['LOCALAPPDATA'] ??
              Platform.environment['APPDATA'] ??
              Directory.systemTemp.path)
        : (Platform.environment['HOME'] != null
              ? '${Platform.environment['HOME']}/Library/Application Support'
              : Directory.systemTemp.path);
    final dir = Platform.isWindows
        ? Directory('$base\\Litchi')
        : Directory('$base/Litchi');
    return File('${dir.path}${Platform.pathSeparator}$_snapshotName');
  }

  static Future<bool> _updateSnapshotOwner(
    File file,
    String platform,
    int port,
  ) async {
    if (!await file.exists()) return false;
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is Map<String, dynamic> && decoded['platform'] == platform) {
        decoded['owner_host'] = '127.0.0.1';
        decoded['owner_port'] = port;
        await file.writeAsString(jsonEncode(decoded), flush: true);
        return true;
      }
    } catch (_) {
      // intentional: parse attempt, fallback handled below
    }
    try {
      await file.delete();
    } catch (_) {
      // intentional: best-effort cleanup, failure is safe to ignore
    }
    return false;
  }

  static Future<void> _deleteSnapshot() async {
    try {
      final file = await _snapshotFile();
      if (await file.exists()) await file.delete();
    } catch (_) {
      // intentional: best-effort cleanup, failure is safe to ignore
    }
  }
}
