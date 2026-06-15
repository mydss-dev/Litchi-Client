import 'core_controller.dart';

class CoreStateSyncEffect {
  const CoreStateSyncEffect({
    required this.wasConnected,
    this.runLatencyTest = false,
    this.clearLatency = false,
  });

  final bool? wasConnected;
  final bool runLatencyTest;
  final bool clearLatency;
}

abstract final class CoreStateSyncService {
  static CoreStateSyncEffect? effectFor({
    required ConnectionStatus status,
    required bool coreProcessRunning,
  }) {
    return switch (status) {
      ConnectionStatus.connected => const CoreStateSyncEffect(
        wasConnected: true,
        runLatencyTest: true,
      ),
      ConnectionStatus.disconnected => CoreStateSyncEffect(
        wasConnected: false,
        clearLatency: !coreProcessRunning,
      ),
      _ => null,
    };
  }
}
