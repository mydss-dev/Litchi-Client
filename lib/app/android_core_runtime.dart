import '../shared/models/app_models.dart';
import '../shared/services/android_core_manager.dart';
import '../shared/services/singbox_config.dart';
import 'core_runtime.dart';

class AndroidCoreRuntime implements CoreRuntime {
  AndroidCoreRuntime({AndroidCoreManager? core})
    : _core = core ?? AndroidCoreManager();

  final AndroidCoreManager _core;
  String _lastError = '';

  @override
  bool get isRunning => _core.isRunning;

  @override
  String get lastError => _lastError.isNotEmpty ? _lastError : _core.lastError;

  @override
  Future<void> init() => _core.init();

  @override
  Future<bool> start(CoreRuntimeStartPlan plan) async {
    _lastError = '';
    final config = plan
        .copyWith(
          overrideNetworkMode: plan.overrideNetworkMode ?? NetworkMode.tun,
        )
        .buildConfig();
    if (config == null) {
      _lastError = '配置生成失败，请检查节点格式';
      return false;
    }
    final ok = await _core.start(SingboxConfig.encodeConfig(config));
    if (!ok) _lastError = _core.lastError;
    return ok;
  }

  @override
  Future<void> stop() => _core.stop();

  @override
  Future<String> version() => _core.version();
}
