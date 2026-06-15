import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/app/core_controller.dart';
import 'package:litchi_client/app/core_state_sync_service.dart';

void main() {
  test('connected marks session as connected and requests latency test', () {
    final effect = CoreStateSyncService.effectFor(
      status: ConnectionStatus.connected,
      coreProcessRunning: true,
    );

    expect(effect, isNotNull);
    expect(effect!.wasConnected, isTrue);
    expect(effect.runLatencyTest, isTrue);
    expect(effect.clearLatency, isFalse);
  });

  test('disconnected keeps latency when background core still runs', () {
    final effect = CoreStateSyncService.effectFor(
      status: ConnectionStatus.disconnected,
      coreProcessRunning: true,
    );

    expect(effect, isNotNull);
    expect(effect!.wasConnected, isFalse);
    expect(effect.clearLatency, isFalse);
  });

  test('disconnected clears latency when core process stopped', () {
    final effect = CoreStateSyncService.effectFor(
      status: ConnectionStatus.disconnected,
      coreProcessRunning: false,
    );

    expect(effect, isNotNull);
    expect(effect!.wasConnected, isFalse);
    expect(effect.clearLatency, isTrue);
  });

  test('non-terminal transition statuses have no app-level sync effect', () {
    expect(
      CoreStateSyncService.effectFor(
        status: ConnectionStatus.connecting,
        coreProcessRunning: true,
      ),
      isNull,
    );
    expect(
      CoreStateSyncService.effectFor(
        status: ConnectionStatus.error,
        coreProcessRunning: false,
      ),
      isNull,
    );
  });
}
