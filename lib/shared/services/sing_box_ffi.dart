import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

import 'app_paths.dart';

typedef _StartNative = Int32 Function(Pointer<Utf8>, Pointer<Utf8>);
typedef _StartDart = int Function(Pointer<Utf8>, Pointer<Utf8>);
typedef _NoArgsIntNative = Int32 Function();
typedef _NoArgsIntDart = int Function();
typedef _NoArgsStringNative = Pointer<Utf8> Function();
typedef _NoArgsStringDart = Pointer<Utf8> Function();
typedef _FreeStringNative = Void Function(Pointer<Utf8>);
typedef _FreeStringDart = void Function(Pointer<Utf8>);

/// Stable Dart FFI facade for the Litchi-owned sing-box C ABI.
///
/// No sing-box implementation type crosses this boundary. The native bridge
/// can therefore track upstream API changes without changing the Flutter app.
final class SingBoxFfi {
  SingBoxFfi._(DynamicLibrary library)
    : _checkConfig = library.lookupFunction<_StartNative, _StartDart>(
        'litchi_core_check_config',
      ),
      _start = library.lookupFunction<_StartNative, _StartDart>(
        'litchi_core_start',
      ),
      _stop = library.lookupFunction<_NoArgsIntNative, _NoArgsIntDart>(
        'litchi_core_stop',
      ),
      _isRunning = library.lookupFunction<_NoArgsIntNative, _NoArgsIntDart>(
        'litchi_core_is_running',
      ),
      _version = library.lookupFunction<_NoArgsStringNative, _NoArgsStringDart>(
        'litchi_core_version',
      ),
      _lastError = library
          .lookupFunction<_NoArgsStringNative, _NoArgsStringDart>(
            'litchi_core_last_error',
          ),
      _freeString = library.lookupFunction<_FreeStringNative, _FreeStringDart>(
        'litchi_core_free_string',
      );

  final _StartDart _checkConfig;
  final _StartDart _start;
  final _NoArgsIntDart _stop;
  final _NoArgsIntDart _isRunning;
  final _NoArgsStringDart _version;
  final _NoArgsStringDart _lastError;
  final _FreeStringDart _freeString;

  static SingBoxFfi? _instance;
  static String _loadError = '';

  static bool get isSupported => Platform.isMacOS || Platform.isLinux;

  static String get loadError => _loadError;

  static SingBoxFfi? tryLoad() {
    final existing = _instance;
    if (existing != null) return existing;
    if (!isSupported) {
      _loadError = 'sing-box desktop library is unsupported on this platform';
      return null;
    }
    final candidates = libraryCandidates();
    for (final path in candidates) {
      if (!File(path).existsSync()) continue;
      try {
        return _instance = SingBoxFfi._(DynamicLibrary.open(path));
      } catch (error) {
        _loadError = 'Unable to load $path: $error';
      }
    }
    if (_loadError.isEmpty) {
      _loadError = 'Missing sing-box library (${candidates.join(', ')})';
    }
    return null;
  }

  static List<String> libraryCandidates() {
    if (!isSupported) return const [];
    final separator = Platform.pathSeparator;
    final executableDirectory = File(Platform.resolvedExecutable).parent.path;
    if (Platform.isMacOS) {
      return [
        '$executableDirectory$separator..${separator}Frameworks'
            '${separator}liblitchi_singbox.dylib',
        '$executableDirectory$separator..${separator}Resources'
            '${separator}liblitchi_singbox.dylib',
      ];
    }
    return [
      '$executableDirectory${separator}liblitchi_singbox.so',
      '$executableDirectory${separator}lib${separator}liblitchi_singbox.so',
    ];
  }

  bool get isRunning => _isRunning() == 1;

  bool checkConfig(String config, {String? workingDirectory}) {
    return _callWithStrings(
          _checkConfig,
          config,
          workingDirectory ?? AppPaths.dataDirectory,
        ) ==
        0;
  }

  bool start(String config, {String? workingDirectory}) {
    return _callWithStrings(
          _start,
          config,
          workingDirectory ?? AppPaths.dataDirectory,
        ) ==
        0;
  }

  bool stop() => _stop() == 0;

  String version() => _takeString(_version());

  String lastError() => _takeString(_lastError());

  int _callWithStrings(_StartDart operation, String first, String second) {
    final firstPointer = first.toNativeUtf8();
    final secondPointer = second.toNativeUtf8();
    try {
      return operation(firstPointer, secondPointer);
    } finally {
      malloc.free(firstPointer);
      malloc.free(secondPointer);
    }
  }

  String _takeString(Pointer<Utf8> pointer) {
    if (pointer == nullptr) return '';
    try {
      return pointer.toDartString();
    } finally {
      _freeString(pointer);
    }
  }
}
