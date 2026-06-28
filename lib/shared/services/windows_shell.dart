import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

// ── IsUserAnAdmin ───────────────────────────────────────────────────────────
// shell32!IsUserAnAdmin returns TRUE if the caller is a member of the
// Administrators group.  No memory allocation, no cleanup needed.
typedef _IsUserAnAdminNative = Int32 Function();
typedef _IsUserAnAdminDart = int Function();

final class _Shell32 {
  _Shell32._();
  static final DynamicLibrary _lib = DynamicLibrary.open('shell32.dll');
  static final _IsUserAnAdminDart isUserAnAdmin = _lib
      .lookupFunction<_IsUserAnAdminNative, _IsUserAnAdminDart>('IsUserAnAdmin');
}

// ── ShellExecuteW ───────────────────────────────────────────────────────────
// Opens a file or URL with the associated handler.  Returns a value > 32 on
// success; ≤ 32 indicates an error.
typedef _ShellExecuteWNative = IntPtr Function(
  IntPtr hwnd,
  Pointer<Utf16> lpOperation,
  Pointer<Utf16> lpFile,
  Pointer<Utf16> lpParameters,
  Pointer<Utf16> lpDirectory,
  Int32 nShowCmd,
);
typedef _ShellExecuteWDart = int Function(
  int hwnd,
  Pointer<Utf16> lpOperation,
  Pointer<Utf16> lpFile,
  Pointer<Utf16> lpParameters,
  Pointer<Utf16> lpDirectory,
  int nShowCmd,
);

final _ShellExecuteWDart _shellExecuteW = _Shell32._lib
    .lookupFunction<_ShellExecuteWNative, _ShellExecuteWDart>('ShellExecuteW');

/// Returns true when the current process is running with administrator
/// privileges.  Always returns true on non-Windows platforms (where the concept
/// of UAC elevation is meaningless or the process already has equivalent
/// permissions).
bool checkWindowsAdminPrivilege() {
  if (!Platform.isWindows) return true;
  try {
    return _Shell32.isUserAnAdmin() != 0;
  } catch (_) {
    return false;
  }
}

// ── Process image path (OpenProcess + QueryFullProcessImageNameW) ──────────

typedef _OpenProcessNative = IntPtr Function(
  Uint32 dwDesiredAccess,
  Int32 bInheritHandle,
  Uint32 dwProcessId,
);
typedef _OpenProcessDart = int Function(int dwDesiredAccess, int bInheritHandle, int dwProcessId);

typedef _QueryFullProcessImageNameWNative = Int32 Function(
  IntPtr hProcess,
  Uint32 dwFlags,
  Pointer<Utf16> lpExeName,
  Pointer<Uint32> lpdwSize,
);
typedef _QueryFullProcessImageNameWDart = int Function(
  int hProcess,
  int dwFlags,
  Pointer<Utf16> lpExeName,
  Pointer<Uint32> lpdwSize,
);

typedef _CloseHandleNative = Int32 Function(IntPtr hObject);
typedef _CloseHandleDart = int Function(int hObject);

final class _Kernel32 {
  _Kernel32._();
  static final DynamicLibrary _lib =
      DynamicLibrary.open('kernel32.dll');

  static final _OpenProcessDart openProcess = _lib
      .lookupFunction<_OpenProcessNative, _OpenProcessDart>('OpenProcess');

  static final _QueryFullProcessImageNameWDart queryFullProcessImageNameW = _lib
      .lookupFunction<_QueryFullProcessImageNameWNative,
          _QueryFullProcessImageNameWDart>('QueryFullProcessImageNameW');

  static final _CloseHandleDart closeHandle =
      _lib.lookupFunction<_CloseHandleNative, _CloseHandleDart>('CloseHandle');
}

/// Returns the full executable path for the process identified by [pid], or
/// null when the process cannot be opened (terminated / access denied).
///
/// Uses OpenProcess (PROCESS_QUERY_LIMITED_INFORMATION | PROCESS_QUERY_INFORMATION)
/// + QueryFullProcessImageNameW — no PowerShell, no admin required.
String? getProcessImagePath(int pid) {
  if (!Platform.isWindows) return null;

  // PROCESS_QUERY_LIMITED_INFORMATION | PROCESS_QUERY_INFORMATION
  const desiredAccess = 0x1000 | 0x0400;

  final hProcess = _Kernel32.openProcess(desiredAccess, 0, pid);
  if (hProcess == 0) return null;

  try {
    const maxPath = 32768; // 32 KiB — covers UNC + long paths
    final raw = calloc<Uint16>(maxPath);
    final size = calloc<Uint32>()..value = maxPath;
    try {
      final rc = _Kernel32.queryFullProcessImageNameW(
        hProcess,
        0,
        raw.cast(),
        size,
      );
      if (rc == 0) return null;

      final charCount = size.value;
      if (charCount == 0) return null;
      final sb = StringBuffer();
      for (int i = 0; i < charCount; i++) {
        final unit = raw[i];
        if (unit == 0) break;
        sb.writeCharCode(unit);
      }
      return sb.toString();
    } finally {
      calloc.free(raw);
      calloc.free(size);
    }
  } finally {
    _Kernel32.closeHandle(hProcess);
  }
}

/// Opens [url] in the default browser on Windows.
///
/// Only allows HTTPS URLs — non-HTTPS or unparseable URLs return false
/// without touching the shell.  Must only be called when
/// [Platform.isWindows] is true.
bool shellExecuteUrl(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null || uri.scheme != 'https') return false;

  final op = 'open'.toNativeUtf16();
  final file = url.toNativeUtf16();
  try {
    // SW_SHOWNORMAL = 1
    final result = _shellExecuteW(0, op, file, nullptr, nullptr, 1);
    return result > 32;
  } finally {
    calloc.free(op);
    calloc.free(file);
  }
}
