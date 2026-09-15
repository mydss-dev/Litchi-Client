import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../app/app_controller.dart';
import '../../../shared/layout/app_layout.dart';
import '../../../shared/models/app_models.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/widgets/notice_bar.dart';
import 'greenfield_connection_workspace.dart';
import 'greenfield_dashboard_surfaces.dart';

class GreenfieldDashboardHome extends StatelessWidget {
  const GreenfieldDashboardHome({
    super.key,
    required this.ctrl,
    required this.tick,
    required this.onToggleConnection,
    required this.onProxyModeChanged,
    required this.onNodeTap,
  });

  final AppController ctrl;
  final ValueListenable<int> tick;
  final VoidCallback onToggleConnection;
  final ValueChanged<ProxyMode> onProxyModeChanged;
  final VoidCallback onNodeTap;

  @override
  Widget build(BuildContext context) {
    final noPlan =
        ctrl.hasAccountSummary && !ctrl.isInitialLoading && !ctrl.hasPlan;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact =
            AppLayoutMetrics.classify(constraints.maxWidth) ==
            AppLayoutClass.compact;

        return Column(
          key: const ValueKey('greenfield-dashboard-home'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            NoticeBar(notices: ctrl.notices, isLoading: ctrl.noticesLoading),
            const SizedBox(height: AppSpacing.md),
            if (noPlan)
              GreenfieldNoPlanSurface(ctrl: ctrl, compact: compact)
            else ...[
              GreenfieldConnectionWorkspace(
                ctrl: ctrl,
                tick: tick,
                compact: compact,
                onToggleConnection: onToggleConnection,
                onProxyModeChanged: onProxyModeChanged,
                onNodeTap: onNodeTap,
              ),
              const SizedBox(height: AppSpacing.md),
              GreenfieldRealtimeSurface(
                ctrl: ctrl,
                tick: tick,
                compact: compact,
              ),
              const SizedBox(height: AppSpacing.md),
              GreenfieldSubscriptionSurface(ctrl: ctrl, compact: compact),
            ],
          ],
        );
      },
    );
  }
}
