import '../shared/models/app_models.dart';
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
  const CoreRuntimeStartPlan({required this.request, this.overrideNetworkMode});

  final CoreConnectionRequest request;
  final NetworkMode? overrideNetworkMode;

  CoreRuntimeStartPlan copyWith({NetworkMode? overrideNetworkMode}) {
    return CoreRuntimeStartPlan(
      request: request,
      overrideNetworkMode: overrideNetworkMode ?? this.overrideNetworkMode,
    );
  }

  Map<String, dynamic>? buildConfig() {
    return request.buildConfig(overrideNetworkMode: overrideNetworkMode);
  }
}
