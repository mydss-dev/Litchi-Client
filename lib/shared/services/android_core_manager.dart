import 'package:flutter/services.dart';

class AndroidCoreException implements Exception {
  const AndroidCoreException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AndroidCoreManager {
  static const _channel = MethodChannel('litchi/android_core');

  bool _isRunning = false;
  String _lastError = '';

  bool get isRunning => _isRunning;
  String get lastError => _lastError;

  Future<void> init() async {
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
