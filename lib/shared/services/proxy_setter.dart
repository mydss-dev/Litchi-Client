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

  static Future<void> enable({int port = 7890}) async {
    if (Platform.isWindows) return _winEnable(port);
    if (Platform.isMacOS) return _macSetProxy('127.0.0.1', port);
  }

  /// Kill-switch: point the system proxy at a dead local port so proxy-aware
  /// traffic fails closed instead of leaking directly when the tunnel drops.
  /// Cleared automatically on the next [enable] / [disable] or on app exit.
  ///
  /// Note: this protects proxy-aware apps in system-proxy mode. Apps that open
  /// raw sockets without honouring the system proxy are not covered — a full
  /// firewall kill-switch is the follow-up for that threat model.
  static Future<void> engageKillSwitch() async {
    // 127.0.0.1:1 — nothing listens here, so every proxied request is refused.
    if (Platform.isWindows) return _winKillSwitch();
    if (Platform.isMacOS) return _macSetProxy('127.0.0.1', 1);
  }

  /// Clears the system proxy. [notify] broadcasts the change to WinInet so
  /// open browsers pick it up immediately — skip it on app exit, where the
  /// registry write already takes effect and waiting on the PowerShell helper
  /// would stall the shutdown by up to several seconds. (macOS applies changes
  /// immediately, so [notify] is a no-op there.)
  static Future<void> disable({bool notify = true}) async {
    if (Platform.isWindows) return _winDisable(notify: notify);
    if (Platform.isMacOS) return _macDisable();
  }

  /// On startup: if the system proxy still points to 127.0.0.1 but no sing-box
  /// is alive (PID file already removed by [CoreManager.cleanupOnStartup]),
  /// the proxy was left behind by a crash. Clear it silently.
  static Future<void> disableIfStale() async {
    if (Platform.isWindows) return _winDisableIfStale();
    if (Platform.isMacOS) return _macDisableIfStale();
  }

  // ── Windows (registry + WinInet) ───────────────────────────────────────────

  static Future<void> _winEnable(int port) async {
    // ProxyServer first: if either write fails, the proxy is never left
    // enabled while pointing at a stale address.
    await _reg('ProxyServer', 'REG_SZ', '127.0.0.1:$port');
    await _reg('ProxyEnable', 'REG_DWORD', '1');
    await _notify();
  }

  static Future<void> _winKillSwitch() async {
    await _reg('ProxyServer', 'REG_SZ', '127.0.0.1:1');
    await _reg('ProxyEnable', 'REG_DWORD', '1');
    await _notify();
  }

  static Future<void> _winDisable({bool notify = true}) async {
    try {
      await _reg('ProxyEnable', 'REG_DWORD', '0');
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
        await _winDisable(notify: false);
      }
    } catch (e) {
      SecureLogger.warn('ProxySetter.disableIfStale failed', e);
    }
  }

  static Future<void> _reg(String name, String type, String value) async {
    final result = await Process.run(
      'reg',
      ['add', _key, '/v', name, '/t', type, '/d', value, '/f'],
    );
    if (result.exitCode != 0) {
      throw Exception('系统代理设置失败 (exit ${result.exitCode}): ${result.stderr}');
    }
  }

  /// Notify WinInet so browsers pick up the registry change immediately.
  ///
  /// Strategy: compile a tiny C# DLL to %TEMP% on the first call, then load
  /// the pre-built DLL on every subsequent call — avoiding the JIT overhead
  /// (~1-2 s) that comes with inline Add-Type compilation.
  static Future<void> _notify() async {
    final tmp = Directory.systemTemp.path;
    final ps1 = '$tmp\\litchi_notify.ps1';
    final dll = '$tmp\\litchi_wininet.dll';

    if (!File(ps1).existsSync()) {
      await File(ps1).writeAsString(_notifyScript(dll));
    }

    await Process.run(
      'powershell',
      ['-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-File', ps1],
    ).timeout(
      const Duration(seconds: 5),
      onTimeout: () => ProcessResult(0, 0, '', ''),
    );
  }

  /// Generates the PowerShell helper script embedded with the [dllPath].
  ///
  /// The script compiles a C# assembly to [dllPath] on its first run and
  /// loads the cached DLL on subsequent runs, calling InternetSetOption(39)
  /// and InternetSetOption(37) to broadcast the proxy-settings change.
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
    for (final service in await _macNetworkServices()) {
      await _macRun(['-setwebproxy', service, host, '$port']);
      await _macRun(['-setsecurewebproxy', service, host, '$port']);
      await _macRun(['-setwebproxystate', service, 'on']);
      await _macRun(['-setsecurewebproxystate', service, 'on']);
    }
  }

  static Future<void> _macDisable() async {
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
          await _macRun(['-setwebproxystate', service, 'off']);
          await _macRun(['-setsecurewebproxystate', service, 'off']);
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
}
