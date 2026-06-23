import '../shared/models/app_models.dart';
import '../shared/services/singbox_config.dart';
import 'core_connection_request.dart';

abstract interface class CoreRuntime {
  bool get isRunning;
  String get lastError;

  Future<void> init();
  Future<void> stop();
  Future<bool> start(CoreRuntimeStartPlan plan);
  Future<String> version();
}

class CoreRuntimeStartPlan {
  const CoreRuntimeStartPlan({
    required this.request,
    this.overrideNetworkMode,
    this.apiPort,
  });

  final CoreConnectionRequest request;
  final NetworkMode? overrideNetworkMode;
  final int? apiPort;

  CoreRuntimeStartPlan copyWith({
    NetworkMode? overrideNetworkMode,
    int? apiPort,
  }) {
    return CoreRuntimeStartPlan(
      request: request,
      overrideNetworkMode: overrideNetworkMode ?? this.overrideNetworkMode,
      apiPort: apiPort ?? this.apiPort,
    );
  }

  Map<String, dynamic>? buildConfig() {
    return request.buildConfig(
      overrideNetworkMode: overrideNetworkMode,
      apiPort: apiPort ?? SingboxConfig.defaultApiPort,
    );
  }
}
