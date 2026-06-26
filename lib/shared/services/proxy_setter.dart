import 'dart:convert';
import 'dart:io';

import 'secure_logger.dart';

/// Sets / clears the system HTTP(S) proxy.
///
/// Windows: HKCU Internet Settings registry + a WinInet broadcast.
/// macOS: `networksetup` web/secure-web proxy on every enabled network service.
abstract final class ProxySetter {
  static const _key =
      r'HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings';
  static const _snapshotName = 'proxy_snapshot.json';

  static Future<void> enable({int port = 7890}) async {
    if (Platform.isWindows) return _winEnable(port);
    if (Platform.isMacOS) return _macSetProxy('127.0.0.1', port);
  }

  /// Kill-switch: point the system proxy at a dead local port so proxy-aware
  /// traffic fails closed instead of leaking directly when the tunnel drops.
  /// Cleared automatically on the next [enable] / [disable] or on app exit.
  ///
  /// Note: protects proxy-aware apps in system-proxy mode. Apps that open raw
  /// sockets ignoring the system proxy are not covered — a full firewall
  /// kill-switch is the follow-up for that threat model.
  static Future<void> engageKillSwitch() async {
    // 127.0.0.1:1 — nothing listens here, so every proxied request is refused.
    if (Platform.isWindows) return _winKillSwitch();
    if (Platform.isMacOS) return _macSetProxy('127.0.0.1', 1);
  }

  /// Clears the system proxy. [notify] broadcasts the change to WinInet so
  /// open browsers pick it up immediately — skip it on app exit, where the
  /// registry write already takes effect and waiting on the PowerShell helper
  /// would stall shutdown. (macOS applies immediately, so [notify] is a no-op.)
  static Future<void> disable({bool notify = true}) async {
    if (Platform.isWindows) return _winDisable(notify: notify);
    if (Platform.isMacOS) return _macDisable();
  }

  /// On startup: if the system proxy still points to our previous Litchi
  /// snapshot and no sing-box is alive, restore the user's old proxy silently.
  /// Without a valid snapshot, do nothing — another proxy app may own 127.0.0.1.
  static Future<void> disableIfStale() async {
    if (Platform.isWindows) return _winDisableIfStale();
    if (Platform.isMacOS) return _macDisableIfStale();
  }

  // ── Windows (registry + WinInet) ───────────────────────────────────────────

  static Future<void> _winEnable(int port) async {
    await _winSaveSnapshotIfNeeded(port);
    // ProxyServer first: if either write fails, the proxy is never left
    // enabled while pointing at a stale address.
    await _reg('ProxyServer', 'REG_SZ', '127.0.0.1:$port');
    await _reg('ProxyEnable', 'REG_DWORD', '1');
    await _notify();
  }

  static Future<void> _winKillSwitch() async {
    await _winSaveSnapshotIfNeeded(1);
    await _reg('ProxyServer', 'REG_SZ', '127.0.0.1:1');
    await _reg('ProxyEnable', 'REG_DWORD', '1');
    await _notify();
  }

  static Future<void> _winDisable({bool notify = true}) async {
    try {
      final restored = await _winRestoreSnapshotIfOwned();
      if (!restored) {
        await _reg('ProxyEnable', 'REG_DWORD', '0');
      }
    } catch (e) {
      SecureLogger.warn('ProxySetter.disable failed', e);
    }
    if (notify) await _notify();
  }

  static Future<void> _winDisableIfStale() async {
    try {
      final r1 = await Process.run('reg', ['query', _key, '/v', 'ProxyEnable']);
      if (r1.exitCode != 0) return;
      // reg query prints "ProxyEnable    REG_DWORD    0x1" — match the value
      // token exactly so error text containing "0x1" can't false-positive.
      if (!RegExp(r'REG_DWORD\s+0x1\b').hasMatch('${r1.stdout}')) return;
      final r2 = await Process.run('reg', ['query', _key, '/v', 'ProxyServer']);
      if (r2.exitCode != 0) return;
      if ('${r2.stdout}'.contains('127.0.0.1:')) {
        await _winRestoreSnapshotIfOwned();
      }
    } catch (e) {
      SecureLogger.warn('ProxySetter.disableIfStale failed', e);
    }
  }

  static Future<void> _winSaveSnapshotIfNeeded(int port) async {
    try {
      final file = await _snapshotFile();
      if (await file.exists()) return;
      final snapshot = <String, Object?>{
        'platform': 'windows',
        'owner_host': '127.0.0.1',
        'owner_port': port,
        'proxy_enable': await _regReadDword('ProxyEnable'),
        'proxy_server': await _regReadString('ProxyServer'),
        'proxy_override': await _regReadString('ProxyOverride'),
        'saved_at': DateTime.now().toIso8601String(),
      };
      await file.parent.create(recursive: true);
      await file.writeAsString(jsonEncode(snapshot));
    } catch (e) {
      SecureLogger.warn('ProxySetter snapshot save failed', e);
    }
  }

  static Future<bool> _winRestoreSnapshotIfOwned() async {
    final file = await _snapshotFile();
    if (!await file.exists()) return false;

    Map<String, dynamic>? snapshot;
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is Map<String, dynamic>) snapshot = decoded;
    } catch (_) {}
    if (snapshot == null || snapshot['platform'] != 'windows') {
      await _deleteSnapshot();
      return false;
    }

    final ownerPort = _ownerPort(snapshot);
    final currentServer = await _regReadString('ProxyServer') ?? '';
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
      await _reg('ProxyServer', 'REG_SZ', oldServer);
    } else {
      await _regDelete('ProxyServer');
    }
    if (oldOverride != null) {
      await _reg('ProxyOverride', 'REG_SZ', oldOverride);
    } else {
      await _regDelete('ProxyOverride');
    }
    await _reg('ProxyEnable', 'REG_DWORD', oldEnable == 0 ? '0' : '1');
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

  static Future<int?> _regReadDword(String name) async {
    final result = await Process.run('reg', ['query', _key, '/v', name]);
    if (result.exitCode != 0) return null;
    final match = RegExp(
      r'REG_DWORD\s+0x([0-9a-fA-F]+)\b',
    ).firstMatch('${result.stdout}');
    if (match == null) return null;
    return int.tryParse(match.group(1)!, radix: 16);
  }

  static Future<String?> _regReadString(String name) async {
    final result = await Process.run('reg', ['query', _key, '/v', name]);
    if (result.exitCode != 0) return null;
    final lines = const LineSplitter().convert('${result.stdout}');
    for (final line in lines) {
      final match = RegExp(
        r'^\s*' + RegExp.escape(name) + r'\s+REG_\w+\s+(.*)$',
      ).firstMatch(line);
      if (match != null) return match.group(1)?.trim();
    }
    return null;
  }

  static Future<void> _reg(String name, String type, String value) async {
    final result = await Process.run('reg', [
      'add',
      _key,
      '/v',
      name,
      '/t',
      type,
      '/d',
      value,
      '/f',
    ]);
    if (result.exitCode != 0) {
      throw Exception('系统代理设置失败 (exit ${result.exitCode}): ${result.stderr}');
    }
  }

  static Future<void> _regDelete(String name) async {
    final result = await Process.run('reg', ['delete', _key, '/v', name, '/f']);
    if (result.exitCode != 0) {
      // Missing values are fine; reg.exe returns non-zero for that case.
      SecureLogger.warn('reg delete $name skipped', result.stderr);
    }
  }

  /// Notify WinInet so browsers pick up the registry change immediately.
  /// Compiles a tiny C# DLL to %TEMP% on the first call, then loads the cached
  /// DLL on subsequent calls — avoiding repeated JIT compile overhead.
  static Future<void> _notify() async {
    final tmp = Directory.systemTemp.path;
    final ps1 = '$tmp\\litchi_notify.ps1';
    final dll = '$tmp\\litchi_wininet.dll';

    if (!File(ps1).existsSync()) {
      await File(ps1).writeAsString(_notifyScript(dll));
    }

    await Process.run('powershell', [
      '-NoProfile',
      '-NonInteractive',
      '-ExecutionPolicy',
      'Bypass',
      '-File',
      ps1,
    ]).timeout(
      const Duration(seconds: 5),
      onTimeout: () => ProcessResult(0, 0, '', ''),
    );
  }

  static String _notifyScript(String dllPath) {
    final esc = dllPath.replaceAll("'", "''"); // PowerShell single-quote escape
    return "\$dll = '$esc'\n"
        r"""
$src = @'
using System.Runtime.InteropServices;
namespace LitchiWin {
  public class WinInet {
    [DllImport("wininet.dll")]
    public static extern bool InternetSetOption(
      System.IntPtr h, int d, System.IntPtr b, int l);
  }
}
'@
try {
  if (-not (Test-Path $dll)) {
    Add-Type -TypeDefinition $src -OutputAssembly $dll -ErrorAction Stop
  }
  Add-Type -Path $dll -ErrorAction Stop
} catch {
  # Fallback: inline compile (slower, but always works).
  Add-Type -MemberDefinition '[DllImport("wininet.dll")] public static extern bool InternetSetOption(IntPtr h,int d,IntPtr b,int l);' -Namespace LW -Name N -ErrorAction SilentlyContinue
}
foreach ($opt in 39, 37) {
  try { [LitchiWin.WinInet]::InternetSetOption([System.IntPtr]::Zero, $opt, [System.IntPtr]::Zero, 0) | Out-Null } catch {}
  try { [LW.N]::InternetSetOption([System.IntPtr]::Zero, $opt, [System.IntPtr]::Zero, 0) | Out-Null } catch {}
}
""";
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
    for (final service in await _macNetworkServices()) {
      await _macRun(['-setwebproxy', service, host, '$port']);
      await _macRun(['-setsecurewebproxy', service, host, '$port']);
      await _macRun(['-setwebproxystate', service, 'on']);
      await _macRun(['-setsecurewebproxystate', service, 'on']);
    }
  }

  static Future<void> _macDisable() async {
    if (await _macRestoreSnapshotIfOwned()) return;
    for (final service in await _macNetworkServices()) {
      await _macRun(['-setwebproxystate', service, 'off']);
      await _macRun(['-setsecurewebproxystate', service, 'off']);
    }
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

  static Future<void> _macRun(List<String> args) async {
    final r = await Process.run('networksetup', args);
    if (r.exitCode != 0) {
      SecureLogger.warn(
        'networksetup ${args.first} failed (exit ${r.exitCode})',
        r.stderr,
      );
    }
  }

  static Future<void> _macSaveSnapshotIfNeeded(int port) async {
    try {
      final file = await _snapshotFile();
      if (await file.exists()) return;
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
      await file.parent.create(recursive: true);
      await file.writeAsString(
        jsonEncode({
          'platform': 'macos',
          'owner_host': '127.0.0.1',
          'owner_port': port,
          'services': services,
          'saved_at': DateTime.now().toIso8601String(),
        }),
      );
    } catch (e) {
      SecureLogger.warn('macOS proxy snapshot save failed', e);
    }
  }

  static Future<bool> _macRestoreSnapshotIfOwned() async {
    final file = await _snapshotFile();
    if (!await file.exists()) return false;

    Map<String, dynamic>? snapshot;
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is Map<String, dynamic>) snapshot = decoded;
    } catch (_) {}
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
      final current = _parseMacProxy(
        await _macGetProxy('-getwebproxy', service),
      );
      final server = current['server']?.toString() ?? '';
      final port = current['port'];
      final currentServer = port is int && port > 0 ? '$server:$port' : server;
      if (current['enabled'] == true &&
          !_isOwnedLocalProxyServer(currentServer, ownerPort)) {
        await _deleteSnapshot();
        return true;
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

  static Future<void> _deleteSnapshot() async {
    try {
      final file = await _snapshotFile();
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }
}
