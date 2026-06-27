import 'dart:ffi';
import 'dart:io';

typedef InternetSetOptionWNative = Int32 Function(
  IntPtr hInternet,
  Uint32 dwOption,
  IntPtr lpBuffer,
  Uint32 dwBufferLength,
);

typedef InternetSetOptionWDart = int Function(
  int hInternet,
  int dwOption,
  int lpBuffer,
  int dwBufferLength,
);

abstract final class WinInetNotify {
  static final DynamicLibrary _wininet = DynamicLibrary.open('wininet.dll');

  static final InternetSetOptionWDart _internetSetOptionW =
      _wininet.lookupFunction<InternetSetOptionWNative, InternetSetOptionWDart>(
    'InternetSetOptionW',
  );

  static void notifyChanged() {
    if (!Platform.isWindows) return;

    const internetOptionSettingsChanged = 39;
    const internetOptionRefresh = 37;

    _internetSetOptionW(0, internetOptionSettingsChanged, 0, 0);
    _internetSetOptionW(0, internetOptionRefresh, 0, 0);
  }
}
