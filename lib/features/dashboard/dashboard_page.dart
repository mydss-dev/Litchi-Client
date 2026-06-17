import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../app/core_controller.dart' show ConnectionStatus;
import '../../shared/widgets/app_toast.dart';
import '../../shared/widgets/page_header.dart';
import 'widgets/connection_hero_card.dart';
import 'widgets/connection_stats_row.dart';
import 'widgets/error_banner.dart';
import 'widgets/expiry_banner.dart';
import 'widgets/network_settings_card.dart';
import 'widgets/proxy_mode_card.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  Timer? _tickTimer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncTimer();
  }

  void _syncTimer() {
    final ctrl = AppScope.of(context);
    if (ctrl.coreRunning && _tickTimer == null) {
      _tickTimer = Timer.periodic(
        const Duration(seconds: 1),
        (_) => setState(() {}),
      );
    } else if (!ctrl.coreRunning && _tickTimer != null) {
      _tickTimer!.cancel();
      _tickTimer = null;
    }
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    super.dispose();
  }

  Future<void> _onToggle() async {
    final ctrl = AppScope.of(context);
    if (ctrl.coreConnecting) return;

    final error = await ctrl.toggleConnection();
    _syncTimer();

    if (mounted && error != null) {
      AppToast.show(context, error, type: AppToastType.error);
    } else if (mounted && ctrl.coreRunning) {
      AppToast.show(context, '连接成功', type: AppToastType.success);
    }
  }

  Future<void> _onRefreshData() async {
    await AppScope.of(context).refreshData();
  }

  String _formatDuration(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = AppScope.of(context);
    final status = ctrl.connectionStatus;
    final elapsed = _formatDuration(ctrl.connectedDuration);

    final hero = ConnectionHeroCard(
      status: status,
      elapsedLabel: elapsed,
      onToggle: _onToggle,
    );

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHeader(title: '首页', subtitle: '查看当前连接、节点与流量状态'),
          const SizedBox(height: 14),
          ExpiryBanner(user: ctrl.user),
          if (ctrl.dataLoadError != null) ...[
            ErrorBanner(
              message: ctrl.dataLoadError!,
              onRetry: _onRefreshData,
              warning: true,
            ),
            const SizedBox(height: 12),
          ],
          LayoutBuilder(
            builder: (context, constraints) {
              // Wide desktop: connection hero on the left, settings on the
              // right, using the full width. Narrow: stack them.
              if (constraints.maxWidth >= 640) {
                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(flex: 5, child: hero),
                      const SizedBox(width: 14),
                      const Expanded(
                        flex: 4,
                        child: Column(
                          children: [
                            ProxyModeCard(),
                            SizedBox(height: 14),
                            Expanded(child: NetworkSettingsCard()),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  hero,
                  const SizedBox(height: 14),
                  const ProxyModeCard(),
                  const SizedBox(height: 14),
                  const NetworkSettingsCard(),
                ],
              );
            },
          ),
          if (status == ConnectionStatus.error && ctrl.coreError.isNotEmpty) ...[
            const SizedBox(height: 8),
            ErrorBanner(message: ctrl.coreError, onRetry: _onToggle),
          ],
          const SizedBox(height: 14),
          const ConnectionStatsRow(),
        ],
      ),
    );
  }
}
