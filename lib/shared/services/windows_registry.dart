import 'dart:ffi';

import 'package:ffi/ffi.dart';

// ── Native typedefs ──────────────────────────────────────────────────────────

typedef _RegOpenKeyExWNative = Int32 Function(
  IntPtr hKey,
  Pointer<Utf16> lpSubKey,
  Uint32 ulOptions,
  Uint32 samDesired,
  Pointer<IntPtr> phkResult,
);

typedef _RegQueryValueExWNative = Int32 Function(
  IntPtr hKey,
  Pointer<Utf16> lpValueName,
  Pointer<Uint32> lpreserved,
  Pointer<Uint32> lpType,
  Pointer<Uint8> lpData,
  Pointer<Uint32> lpcbData,
);

typedef _RegSetValueExWNative = Int32 Function(
  IntPtr hKey,
  Pointer<Utf16> lpValueName,
  Uint32 reserved,
  Uint32 dwType,
  Pointer<Uint8> lpData,
  Uint32 cbData,
);

typedef _RegDeleteValueWNative = Int32 Function(
  IntPtr hKey,
  Pointer<Utf16> lpValueName,
);

typedef _RegCloseKeyNative = Int32 Function(IntPtr hKey);

// ── Dart typedefs ────────────────────────────────────────────────────────────

typedef _RegOpenKeyExWDart = int Function(
  int hKey,
  Pointer<Utf16> lpSubKey,
  int ulOptions,
  int samDesired,
  Pointer<IntPtr> phkResult,
);

typedef _RegQueryValueExWDart = int Function(
  int hKey,
  Pointer<Utf16> lpValueName,
  Pointer<Uint32> lpreserved,
  Pointer<Uint32> lpType,
  Pointer<Uint8> lpData,
  Pointer<Uint32> lpcbData,
);

typedef _RegSetValueExWDart = int Function(
  int hKey,
  Pointer<Utf16> lpValueName,
  int reserved,
  int dwType,
  Pointer<Uint8> lpData,
  int cbData,
);

typedef _RegDeleteValueWDart = int Function(
  int hKey,
  Pointer<Utf16> lpValueName,
);

typedef _RegCloseKeyDart = int Function(int hKey);

// ── Constants ────────────────────────────────────────────────────────────────

const _hkeyCurrentUser = 0x80000001;

const _keyRead = 0x20019; // KEY_READ
const _keyWrite = 0x20006; // KEY_WRITE

const _regSz = 1; // REG_SZ
const _regDword = 4; // REG_DWORD

const _errorSuccess = 0;
const _errorFileNotFound = 2;
const _errorMoreData = 234;

// ── DLL bindings ─────────────────────────────────────────────────────────────

final class _Advapi32 {
  _Advapi32._();
  static final DynamicLibrary _lib = DynamicLibrary.open('advapi32.dll');

  static final _RegOpenKeyExWDart regOpenKeyExW = _lib
      .lookupFunction<_RegOpenKeyExWNative, _RegOpenKeyExWDart>('RegOpenKeyExW');

  static final _RegQueryValueExWDart regQueryValueExW = _lib
      .lookupFunction<_RegQueryValueExWNative, _RegQueryValueExWDart>(
    'RegQueryValueExW',
  );

  static final _RegSetValueExWDart regSetValueExW = _lib
      .lookupFunction<_RegSetValueExWNative, _RegSetValueExWDart>(
    'RegSetValueExW',
  );

  static final _RegDeleteValueWDart regDeleteValueW = _lib
      .lookupFunction<_RegDeleteValueWNative, _RegDeleteValueWDart>(
    'RegDeleteValueW',
  );

  static final _RegCloseKeyDart regCloseKey =
      _lib.lookupFunction<_RegCloseKeyNative, _RegCloseKeyDart>('RegCloseKey');
}

// ── Public API ───────────────────────────────────────────────────────────────

/// Thin FFI wrapper for HKCU registry operations used by the proxy setter and
/// auto-start services.  All keys are relative to HKEY_CURRENT_USER; pass
/// `r'Software\...\KeyName'` as [keyPath].
abstract final class WindowsRegistry {
  static int? _open(String keyPath, int access) {
    final subKey = keyPath.toNativeUtf16();
    final result = calloc<IntPtr>();
    try {
      final rc = _Advapi32.regOpenKeyExW(
        _hkeyCurrentUser,
        subKey,
        0,
        access,
        result,
      );
      if (rc != _errorSuccess) return null;
      return result.value;
    } finally {
      calloc.free(subKey);
      calloc.free(result);
    }
  }

  static void _close(int hKey) {
    _Advapi32.regCloseKey(hKey);
  }

  /// Reads a REG_DWORD value, or returns null when the value is missing.
  static int? readDword(String keyPath, String valueName) {
    final hKey = _open(keyPath, _keyRead);
    if (hKey == null) return null;
    try {
      final name = valueName.toNativeUtf16();
      final type = calloc<Uint32>();
      final data = calloc<Uint32>();
      final size = calloc<Uint32>()..value = 4;
      try {
        final rc = _Advapi32.regQueryValueExW(
          hKey,
          name,
          nullptr,
          type,
          data.cast(),
          size,
        );
        if (rc != _errorSuccess || type.value != _regDword) return null;
        return data.value;
      } finally {
        calloc.free(name);
        calloc.free(type);
        calloc.free(data);
        calloc.free(size);
      }
    } finally {
      _close(hKey);
    }
  }

  /// Reads a REG_SZ (or REG_EXPAND_SZ) value, or returns null when missing.
  static String? readString(String keyPath, String valueName) {
    final hKey = _open(keyPath, _keyRead);
    if (hKey == null) return null;
    try {
      final name = valueName.toNativeUtf16();
      final type = calloc<Uint32>();
      final size = calloc<Uint32>();
      try {
        // First call: get required buffer size.
        int rc = _Advapi32.regQueryValueExW(
          hKey,
          name,
          nullptr,
          type,
          nullptr,
          size,
        );
        if (rc != _errorSuccess && rc != _errorMoreData) return null;
        if (size.value == 0) return '';

        final raw = calloc<Uint16>(size.value ~/ 2);
        try {
          rc = _Advapi32.regQueryValueExW(
            hKey,
            name,
            nullptr,
            nullptr,
            raw.cast(),
            size,
          );
          if (rc != _errorSuccess) return null;
          // Build string from UTF-16 code units, stopping at the first null.
          final charCount = size.value ~/ 2;
          if (charCount == 0) return '';
          final sb = StringBuffer();
          for (int i = 0; i < charCount; i++) {
            final unit = raw[i];
            if (unit == 0) break;
            sb.writeCharCode(unit);
          }
          return sb.toString();
        } finally {
          calloc.free(raw);
        }
      } finally {
        calloc.free(name);
        calloc.free(type);
        calloc.free(size);
      }
    } finally {
      _close(hKey);
    }
  }

  /// Writes a REG_DWORD value (0 or 1 for boolean-like flags).
  static void writeDword(String keyPath, String valueName, int value) {
    final hKey = _open(keyPath, _keyWrite);
    if (hKey == null) {
      throw Exception('无法打开注册表项: $keyPath');
    }
    try {
      final name = valueName.toNativeUtf16();
      final data = calloc<Uint32>()..value = value;
      try {
        final rc = _Advapi32.regSetValueExW(
          hKey,
          name,
          0,
          _regDword,
          data.cast(),
          4,
        );
        if (rc != _errorSuccess) {
          throw Exception('注册表写入失败 ($rc): $keyPath\\$valueName');
        }
      } finally {
        calloc.free(name);
        calloc.free(data);
      }
    } finally {
      _close(hKey);
    }
  }

  /// Writes a REG_SZ value.
  static void writeString(String keyPath, String valueName, String value) {
    final hKey = _open(keyPath, _keyWrite);
    if (hKey == null) {
      throw Exception('无法打开注册表项: $keyPath');
    }
    try {
      final name = valueName.toNativeUtf16();
      final data = value.toNativeUtf16();
      // Byte count includes the null terminator.
      final cb = (value.length + 1) * 2;
      try {
        final rc = _Advapi32.regSetValueExW(
          hKey,
          name,
          0,
          _regSz,
          data.cast(),
          cb,
        );
        if (rc != _errorSuccess) {
          throw Exception('注册表写入失败 ($rc): $keyPath\\$valueName');
        }
      } finally {
        calloc.free(name);
        calloc.free(data);
      }
    } finally {
      _close(hKey);
    }
  }

  /// Deletes a value.  Missing values are silently ignored.
  static void deleteValue(String keyPath, String valueName) {
    final hKey = _open(keyPath, _keyWrite);
    if (hKey == null) return; // key missing, nothing to delete
    try {
      final name = valueName.toNativeUtf16();
      try {
        final rc = _Advapi32.regDeleteValueW(hKey, name);
        if (rc != _errorSuccess && rc != _errorFileNotFound) {
          throw Exception('注册表删除失败 ($rc): $keyPath\\$valueName');
        }
      } finally {
        calloc.free(name);
      }
    } finally {
      _close(hKey);
    }
  }
}
