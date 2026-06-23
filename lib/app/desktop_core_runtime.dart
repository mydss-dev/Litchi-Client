import 'dart:async';
import 'dart:io';

import '../shared/services/core_manager.dart';
import '../shared/services/proxy_setter.dart';
import '../shared/services/singbox_config.dart';
import 'core_runtime.dart';

/// Desktop (Windows / macOS) core runtime: manages the bundled sing-box
/// subprocess via [CoreManager] and the system proxy via [ProxySetter].
class DesktopCoreRuntime implements CoreRuntime {
  DesktopCoreRuntime({CoreManager? core}) : _core = core ?? CoreManager();

  final CoreManager _core;
  String _lastError = '';

  Stream<CoreState> get stateStream => _core.stateStream;
  Stream<String> get logStream => _core.logStream;

  @override
  bool get isRunning => _core.isRunning;

  @override
  String get lastError => _lastError.isNotEmpty ? _lastError : _core.lastError;

  @override
  Future<void> init() async {
    if (!_core.isRunning) {
      await CoreManager.cleanupOnStartup();
      await ProxySetter.disableIfStale();
    }
  }

  @override
  Future<bool> start(CoreRuntimeStartPlan plan) async {
    _lastError = '';
    final config = plan.buildConfig();
    if (config == null) {
      _lastError = '配置生成失败，请检查节点格式';
      return false;
    }
    final configPath = await SingboxConfig.writeConfig(config);
    await _core.start(
      configPath,
      apiPort: plan.apiPort ?? SingboxConfig.defaultApiPort,
    );
    if (!_core.isRunning) _lastError = _core.lastError;
    return _core.isRunning;
  }

  @override
  Future<void> stop() => _core.stop();

  void dispose() => _core.dispose();

  @override
  Future<String> version() => versionString();

  static Future<String> versionString() async {
    final exe = CoreManager.findExecutable();
    if (exe == null) return '未找到 sing-box 核心';
    try {
      final r = await Process.run(exe, ['version']).timeout(
        const Duration(seconds: 3),
        onTimeout: () => ProcessResult(0, 1, '', ''),
      );
      final out = '${r.stdout}'.trim();
      final m = RegExp(r'sing-box version ([\d.]+\S*)').firstMatch(out);
      return m?.group(1) ?? out.split('\n').first.trim();
    } catch (_) {
      return '获取失败';
    }
  }
}
