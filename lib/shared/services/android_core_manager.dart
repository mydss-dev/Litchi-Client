import 'dart:async';

import 'package:flutter/services.dart';

class AndroidCoreException implements Exception {
  const AndroidCoreException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AndroidCoreManager {
  static const _channel = MethodChannel('litchi/android_core');
  static const _statusChannel = EventChannel('litchi/android_core/status');

  final Stream<AndroidCoreStatusEvent> statusStream = _statusChannel
      .receiveBroadcastStream()
      .map(AndroidCoreStatusEvent.fromEvent)
      .asBroadcastStream();

  bool _isRunning = false;
  String _lastError = '';
  StreamSubscription<AndroidCoreStatusEvent>? _statusSub;

  bool get isRunning => _isRunning;
  String get lastError => _lastError;

  Future<void> init() async {
    _statusSub ??= statusStream.listen(_applyStatus);
    _isRunning = await _invokeBool('isRunning');
  }

  Future<bool> prepareVpn() => _invokeBool('prepareVpn');

  Future<bool> start(String configJson) async {
    final prepared = await prepareVpn();
    if (!prepared) {
      _lastError = '需要允许 VPN 权限后才能连接，请重新点击连接并授权';
      return false;
    }
    final launched = await _invokeBool('start', {'config': configJson});
    if (!launched) {
      _lastError = await _invokeString('lastError');
      return false;
    }

    for (var i = 0; i < 20; i++) {
      await Future.delayed(const Duration(milliseconds: 150));
      if (_lastError.isNotEmpty && !_isRunning) return false;
      _isRunning = await _invokeBool('isRunning');
      if (_isRunning) return true;
    }

    _lastError = await _invokeString('lastError');
    if (_lastError.isEmpty) _lastError = 'Android 核心启动超时，请稍后重试';
    await stop();
    return false;
  }

  Future<void> stop() async {
    await _invokeBool('stop');
    _isRunning = false;
  }

  Future<String> version() => _invokeString('version');

  Future<void> dispose() async {
    await _statusSub?.cancel();
    _statusSub = null;
  }

  void _applyStatus(AndroidCoreStatusEvent event) {
    switch (event.status) {
      case AndroidCoreNativeStatus.starting:
        _lastError = '';
      case AndroidCoreNativeStatus.running:
        _isRunning = true;
        _lastError = '';
      case AndroidCoreNativeStatus.stopping:
        _lastError = '';
      case AndroidCoreNativeStatus.stopped:
        _isRunning = false;
      case AndroidCoreNativeStatus.error:
        _isRunning = false;
        _lastError = event.error;
    }
  }

  Future<bool> _invokeBool(String method, [Object? arguments]) async {
    try {
      return await _channel.invokeMethod<bool>(method, arguments) ?? false;
    } on PlatformException catch (e) {
      _lastError = e.message ?? 'Android 核心调用失败';
      throw AndroidCoreException(_lastError);
    }
  }

  Future<String> _invokeString(String method, [Object? arguments]) async {
    try {
      return await _channel.invokeMethod<String>(method, arguments) ?? '';
    } on PlatformException catch (e) {
      _lastError = e.message ?? 'Android 核心调用失败';
      throw AndroidCoreException(_lastError);
    }
  }
}

enum AndroidCoreNativeStatus { starting, running, stopping, stopped, error }

class AndroidCoreStatusEvent {
  const AndroidCoreStatusEvent({required this.status, this.error = ''});

  final AndroidCoreNativeStatus status;
  final String error;

  static AndroidCoreStatusEvent fromEvent(Object? event) {
    final data = event is Map ? event : const <Object?, Object?>{};
    final raw = data['status']?.toString() ?? 'stopped';
    final status = switch (raw) {
      'starting' => AndroidCoreNativeStatus.starting,
      'running' => AndroidCoreNativeStatus.running,
      'stopping' => AndroidCoreNativeStatus.stopping,
      'error' => AndroidCoreNativeStatus.error,
      _ => AndroidCoreNativeStatus.stopped,
    };
    return AndroidCoreStatusEvent(
      status: status,
      error: data['error']?.toString() ?? '',
    );
  }
}
