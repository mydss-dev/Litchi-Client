import 'dart:io';

/// Sets / clears the Windows system HTTP proxy via registry.
abstract final class ProxySetter {
  static const _key =
      r'HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings';

  static Future<void> enable({int port = 7890}) async {
    await _reg('ProxyEnable', 'REG_DWORD', '1');
    await _reg('ProxyServer', 'REG_SZ', '127.0.0.1:$port');
    await _notify();
  }

  static Future<void> disable() async {
    try {
      await _reg('ProxyEnable', 'REG_DWORD', '0');
    } catch (_) {}
    await _notify();
  }

  /// On startup: if the system proxy points to 127.0.0.1 but no sing-box
  /// is alive (PID file already removed by [CoreManager.cleanupOnStartup]),
  /// the proxy was left behind by a crash. Clear it silently.
  static Future<void> disableIfStale() async {
    try {
      final r1 = await Process.run(
        'reg', ['query', _key, '/v', 'ProxyEnable'],
      );
      if (!'${r1.stdout}'.contains('0x1')) return;
      final r2 = await Process.run(
        'reg', ['query', _key, '/v', 'ProxyServer'],
      );
      if ('${r2.stdout}'.contains('127.0.0.1:')) await disable();
    } catch (_) {}
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
}
