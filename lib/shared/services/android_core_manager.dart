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
  bool _isCoreRunning = false;
  bool _isVpnRunning = false;
  int _controllerPort = 9090;
  String _controllerSecret = '';
  String _lastError = '';
  StreamSubscription<AndroidCoreStatusEvent>? _statusSub;

  bool get isRunning => _isRunning;
  bool get isCoreRunning => _isCoreRunning;
  bool get isVpnRunning => _isVpnRunning;
  int get controllerPort => _controllerPort;
  String get controllerSecret => _controllerSecret;
  String get lastError => _lastError;

  Future<void> init() async {
    _statusSub ??= statusStream.listen(_applyStatus);
    _isCoreRunning = await _invokeBool('isCoreRunning');
    _isVpnRunning = await _invokeBool('isVpnRunning');
    _controllerPort = await _invokeInt('controllerPort', fallback: 9090);
    _controllerSecret = await _invokeString('controllerSecret');
    _isRunning = _isCoreRunning || _isVpnRunning;
  }

  Future<bool> prepareVpn() => _invokeBool('prepareVpn');

  /// Starts the mihomo core without VPN — no permission prompt, no TUN.
  /// Used for latency tests, node switching, and mode changes before
  /// the user explicitly connects.
  Future<bool> startCoreOnly(String configJson) async {
    final launched = await _invokeBool('startCoreOnly', {'config': configJson});
    if (!launched) {
      _lastError = await _invokeString('lastError');
      return false;
    }

    _isCoreRunning = true;
    _isRunning = true;
    return true;
  }

  /// Starts the VPN layer on top of an already-running core.  Only call
  /// after [startCoreOnly] succeeded.  Triggers the VPN permission prompt
  /// if needed.
  Future<bool> startVpn(String configJson) async {
    final prepared = await prepareVpn();
    if (!prepared) {
      _lastError = '需要允许 VPN 权限后才能连接，请重新点击连接并授权';
      return false;
    }
    final launched = await _invokeBool('startVpn', {'config': configJson});
    if (!launched) {
      _lastError = await _invokeString('lastError');
      return false;
    }

    _isVpnRunning = true;
    _isRunning = true;
    return true;
  }

  /// Legacy start that does both core-only + VPN in one call.
  /// Prefer [startCoreOnly] + [startVpn] for new code.
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
    await stopCore();
    return false;
  }

  /// Stops the VPN layer only.  Core stays running — native stopVpn
  /// tears down TUN and socket protection but keeps listeners alive.
  Future<void> stopVpn() async {
    await _invokeBool('stopVpn');
    _isVpnRunning = false;
    _isRunning = _isCoreRunning;
  }

  /// Stops everything — core + VPN.
  Future<void> stopCore() async {
    await _invokeBool('stopCore');
    _isCoreRunning = false;
    _isVpnRunning = false;
    _isRunning = false;
  }

  /// Legacy stop (stops everything). Prefer [stopVpn] or [stopCore].
  Future<void> stop() async {
    await stopCore();
  }

  Future<bool> switchProxy(String group, String proxy) =>
      _invokeBool('switchProxy', {'group': group, 'proxy': proxy});

  Future<bool> setMode(String mode) => _invokeBool('setMode', {'mode': mode});

  Future<bool> closeConnections() => _invokeBool('closeConnections');

  Future<bool> reloadConfig(String config) =>
      _invokeBool('reloadConfig', {'config': config});

  Future<String> version() => _invokeString('version');

  Future<void> dispose() async {
    await _statusSub?.cancel();
    _statusSub = null;
  }

  void _applyStatus(AndroidCoreStatusEvent event) {
    final isVpn = event.layer == AndroidCoreLayer.vpn;
    switch (event.status) {
      case AndroidCoreNativeStatus.starting:
        _lastError = '';
      case AndroidCoreNativeStatus.running:
        if (isVpn) {
          _isVpnRunning = true;
          _isCoreRunning = true; // VPN implies core is also running.
        } else {
          _isCoreRunning = true;
        }
        _isRunning = _isCoreRunning || _isVpnRunning;
        _lastError = '';
      case AndroidCoreNativeStatus.stopping:
        _lastError = '';
      case AndroidCoreNativeStatus.stopped:
        if (isVpn) {
          _isVpnRunning = false;
        } else {
          _isCoreRunning = false;
        }
        _isRunning = _isCoreRunning || _isVpnRunning;
      case AndroidCoreNativeStatus.error:
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

  Future<int> _invokeInt(String method, {required int fallback}) async {
    try {
      return await _channel.invokeMethod<int>(method) ?? fallback;
    } on PlatformException catch (e) {
      _lastError = e.message ?? 'Android 核心调用失败';
      return fallback;
    }
  }
}

enum AndroidCoreNativeStatus { starting, running, stopping, stopped, error }

enum AndroidCoreLayer { core, vpn }

class AndroidCoreStatusEvent {
  const AndroidCoreStatusEvent({
    required this.status,
    required this.layer,
    this.error = '',
  });

  final AndroidCoreNativeStatus status;
  final AndroidCoreLayer layer;
  final String error;

  static AndroidCoreStatusEvent fromEvent(Object? event) {
    final data = event is Map ? event : const <Object?, Object?>{};
    final rawStatus = data['status']?.toString() ?? 'stopped';
    final rawLayer = data['layer']?.toString() ?? 'core';

    final status = switch (rawStatus) {
      'starting' => AndroidCoreNativeStatus.starting,
      'running' => AndroidCoreNativeStatus.running,
      'stopping' => AndroidCoreNativeStatus.stopping,
      'error' => AndroidCoreNativeStatus.error,
      _ => AndroidCoreNativeStatus.stopped,
    };

    final layer = switch (rawLayer) {
      'vpn' => AndroidCoreLayer.vpn,
      _ => AndroidCoreLayer.core,
    };

    return AndroidCoreStatusEvent(
      status: status,
      layer: layer,
      error: data['error']?.toString() ?? '',
    );
  }
}
