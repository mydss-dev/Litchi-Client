import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'secure_logger.dart';

/// Windows DPAPI (CryptProtectData / CryptUnprotectData) via FFI.
///
/// Current-user scope, no extra entropy. The plaintext never leaves process
/// memory — this replaces the previous PowerShell `ConvertTo-SecureString`
/// path that exposed secrets through the process command line and temp files.
///
/// Output is hex-encoded so the storage format is byte-compatible with the
/// legacy PowerShell `ConvertFrom-SecureString` blobs (DPAPI over UTF-16LE),
/// allowing existing remembered credentials to decrypt without re-login.
final class WindowsDpapi {
  WindowsDpapi._();

  // CRYPTPROTECT_UI_FORBIDDEN — never show a UI prompt (we run headless).
  static const int _uiForbidden = 0x1;

  static final DynamicLibrary _crypt32 = DynamicLibrary.open('Crypt32.dll');
  static final DynamicLibrary _kernel32 = DynamicLibrary.open('Kernel32.dll');

  static final _cryptProtect = _crypt32.lookupFunction<
      Int32 Function(Pointer<_DataBlob>, Pointer<Utf16>, Pointer<_DataBlob>,
          Pointer<Void>, Pointer<Void>, Uint32, Pointer<_DataBlob>),
      int Function(Pointer<_DataBlob>, Pointer<Utf16>, Pointer<_DataBlob>,
          Pointer<Void>, Pointer<Void>, int,
          Pointer<_DataBlob>)>('CryptProtectData');

  static final _cryptUnprotect = _crypt32.lookupFunction<
      Int32 Function(Pointer<_DataBlob>, Pointer<Pointer<Utf16>>,
          Pointer<_DataBlob>, Pointer<Void>, Pointer<Void>, Uint32,
          Pointer<_DataBlob>),
      int Function(Pointer<_DataBlob>, Pointer<Pointer<Utf16>>,
          Pointer<_DataBlob>, Pointer<Void>, Pointer<Void>, int,
          Pointer<_DataBlob>)>('CryptUnprotectData');

  static final _localFree = _kernel32.lookupFunction<
      Pointer<Void> Function(Pointer<Void>),
      Pointer<Void> Function(Pointer<Void>)>('LocalFree');

  /// Encrypts [plaintext] with DPAPI; returns a lowercase hex string, or null
  /// on failure / non-Windows.
  static String? protect(String plaintext) {
    if (!Platform.isWindows) return null;
    final inBytes = _utf16leEncode(plaintext);
    final inPtr = calloc<Uint8>(inBytes.isEmpty ? 1 : inBytes.length);
    final inBlob = calloc<_DataBlob>();
    final outBlob = calloc<_DataBlob>();
    try {
      if (inBytes.isNotEmpty) {
        inPtr.asTypedList(inBytes.length).setAll(0, inBytes);
      }
      inBlob.ref.cbData = inBytes.length;
      inBlob.ref.pbData = inPtr;
      final ok = _cryptProtect(
        inBlob, nullptr, nullptr, nullptr, nullptr, _uiForbidden, outBlob,
      );
      if (ok == 0) return null;
      final out = _copyBlob(outBlob);
      return _hexEncode(out);
    } catch (e) {
      SecureLogger.debug('DPAPI protect failed', e);
      return null;
    } finally {
      if (outBlob.ref.pbData != nullptr) _localFree(outBlob.ref.pbData.cast());
      calloc.free(inPtr);
      calloc.free(inBlob);
      calloc.free(outBlob);
    }
  }

  /// Decrypts a hex string produced by [protect] (or the legacy PowerShell
  /// path). Returns null on failure / non-Windows.
  static String? unprotect(String hex) {
    if (!Platform.isWindows) return null;
    final inBytes = _hexDecode(hex);
    if (inBytes == null) return null;
    final inPtr = calloc<Uint8>(inBytes.isEmpty ? 1 : inBytes.length);
    final inBlob = calloc<_DataBlob>();
    final outBlob = calloc<_DataBlob>();
    try {
      if (inBytes.isNotEmpty) {
        inPtr.asTypedList(inBytes.length).setAll(0, inBytes);
      }
      inBlob.ref.cbData = inBytes.length;
      inBlob.ref.pbData = inPtr;
      final ok = _cryptUnprotect(
        inBlob, nullptr, nullptr, nullptr, nullptr, _uiForbidden, outBlob,
      );
      if (ok == 0) return null;
      final out = _copyBlob(outBlob);
      return _utf16leDecode(out);
    } catch (e) {
      SecureLogger.debug('DPAPI unprotect failed', e);
      return null;
    } finally {
      if (outBlob.ref.pbData != nullptr) _localFree(outBlob.ref.pbData.cast());
      calloc.free(inPtr);
      calloc.free(inBlob);
      calloc.free(outBlob);
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  static Uint8List _copyBlob(Pointer<_DataBlob> blob) {
    final len = blob.ref.cbData;
    if (len <= 0 || blob.ref.pbData == nullptr) return Uint8List(0);
    // Copy out of native memory before LocalFree runs in the finally block.
    return Uint8List.fromList(blob.ref.pbData.asTypedList(len));
  }

  static Uint8List _utf16leEncode(String s) {
    final units = s.codeUnits;
    final bytes = Uint8List(units.length * 2);
    for (var i = 0; i < units.length; i++) {
      bytes[i * 2] = units[i] & 0xFF;
      bytes[i * 2 + 1] = (units[i] >> 8) & 0xFF;
    }
    return bytes;
  }

  static String _utf16leDecode(Uint8List bytes) {
    final n = bytes.length ~/ 2;
    final units = List<int>.filled(n, 0);
    for (var i = 0; i < n; i++) {
      units[i] = bytes[i * 2] | (bytes[i * 2 + 1] << 8);
    }
    return String.fromCharCodes(units);
  }

  static String _hexEncode(Uint8List b) {
    final sb = StringBuffer();
    for (final x in b) {
      sb.write(x.toRadixString(16).padLeft(2, '0'));
    }
    return sb.toString();
  }

  static Uint8List? _hexDecode(String hex) {
    final s = hex.trim();
    if (s.isEmpty || s.length.isOdd) return null;
    final out = Uint8List(s.length ~/ 2);
    for (var i = 0; i < out.length; i++) {
      final byte = int.tryParse(s.substring(i * 2, i * 2 + 2), radix: 16);
      if (byte == null) return null;
      out[i] = byte;
    }
    return out;
  }
}

final class _DataBlob extends Struct {
  @Uint32()
  external int cbData;
  external Pointer<Uint8> pbData;
}
