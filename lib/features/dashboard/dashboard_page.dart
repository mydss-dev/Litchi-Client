import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../app/core_controller.dart' show ConnectionStatus;
import '../../app/core_error_message_service.dart';
import '../../l10n/l10n.dart';
import '../../shared/layout/app_platform.dart';
import '../../shared/layout/app_shell_spec.dart';
import '../../shared/models/app_models.dart';
import '../../shared/theme/app_spacing.dart';
import '../../shared/widgets/app_page_scaffold.dart';
import '../../shared/widgets/app_toast.dart';
import '../../shared/widgets/notice_carousel.dart';
import '../../shared/widgets/update_banner.dart';
import '../nodes/node_picker.dart';
import 'widgets/error_banner.dart';
import 'widgets/greenfield_dashboard_home.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  Timer? _tickTimer;
  final ValueNotifier<int> _tick = ValueNotifier<int>(0);
  bool _showingPopups = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncTimer();
    _scheduleNoticePopups();
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    _tick.dispose();
    super.dispose();
  }

  void _syncTimer() {
    final ctrl = AppScope.of(context);
    final shouldRun = ctrl.page == AppPage.dashboard && ctrl.coreRunning;
    if (shouldRun && _tickTimer == null) {
      _tickTimer = Timer.periodic(
        const Duration(seconds: 1),
        (_) => _tick.value++,
      );
    } else if (!shouldRun && _tickTimer != null) {
      _tickTimer!.cancel();
      _tickTimer = null;
    }
  }

  Future<void> _toggleConnection() async {
    final ctrl = AppScope.of(context);
    if (ctrl.coreConnecting) return;

    final error = await ctrl.toggleConnection();
    _syncTimer();
    if (!mounted) return;

    if ((error == null || error.isEmpty) && ctrl.coreRunning) {
      AppToast.show(
        context,
        context.l10n.connectionSuccess,
        type: AppToastType.success,
      );
    }
  }

  Future<void> _changeMode(BuildContext context, ProxyMode mode) async {
    final ctrl = AppScope.of(context);
    if (mode == ctrl.proxyMode) return;

    final error = await ctrl.setProxyMode(mode);
    if (!context.mounted) return;
    if (error != null) {
      AppToast.show(context, error, type: AppToastType.error);
    } else {
      AppToast.show(context, mode.switchToast, type: AppToastType.success);
    }
  }

  Future<void> _handlePullRefresh() async {
    final ctrl = AppScope.of(context);
    await ctrl.refreshData();
    if (!mounted || ctrl.dataLoadError != null) return;
    AppToast.show(context, context.l10n.refreshed, type: AppToastType.success);
  }

  void _scheduleNoticePopups() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _showingPopups) return;
      final ctrl = AppScope.of(context);
      if (ctrl.pendingNoticePopups.isEmpty) return;
      _showingPopups = true;
      _showNoticePopups(ctrl).whenComplete(() => _showingPopups = false);
    });
  }

  Future<void> _showNoticePopups(AppController ctrl) async {
    final pending = ctrl.pendingNoticePopups.toList();
    for (final notice in pending) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => NoticePopupDialog(notice: notice),
      );
      if (!mounted) return;
      ctrl.markNoticePopupSeen(notice.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final navigation = AppShellSpec.navigationFor(AppPlatform.current);
    return navigation == AppNavigationMode.sidebar
        ? _buildDesktop(context)
        : _buildCompact(context);
  }

  Widget _buildDesktop(BuildContext context) {
    final ctrl = AppScope.of(context);
    return AppPageScaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DashboardAlerts(
            ctrl: ctrl,
            onConnectionRetry: _toggleConnection,
            onDataRetry: _handlePullRefresh,
          ),
          GreenfieldDashboardHome(
            ctrl: ctrl,
            tick: _tick,
            onToggleConnection: _toggleConnection,
            onProxyModeChanged: (mode) => _changeMode(context, mode),
            onNodeTap: () => showNodePicker(context),
          ),
        ],
      ),
    );
  }

  Widget _buildCompact(BuildContext context) {
    final ctrl = AppScope.of(context);
    return RefreshIndicator(
      onRefresh: _handlePullRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        children: [
          _DashboardAlerts(
            ctrl: ctrl,
            onConnectionRetry: _toggleConnection,
            onDataRetry: _handlePullRefresh,
          ),
          GreenfieldDashboardHome(
            ctrl: ctrl,
            tick: _tick,
            onToggleConnection: _toggleConnection,
            onProxyModeChanged: (mode) => _changeMode(context, mode),
            onNodeTap: () => showNodePicker(context),
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}

class _DashboardAlerts extends StatelessWidget {
  const _DashboardAlerts({
    required this.ctrl,
    required this.onConnectionRetry,
    required this.onDataRetry,
  });

  final AppController ctrl;
  final VoidCallback onConnectionRetry;
  final VoidCallback onDataRetry;

  @override
  Widget build(BuildContext context) {
    final alerts = <Widget>[
      if (ctrl.updateInfo != null)
        UpdateBanner(info: ctrl.updateInfo!, onDismiss: ctrl.dismissUpdate),
      if (ctrl.connectionStatus == ConnectionStatus.error &&
          ctrl.coreError.isNotEmpty)
        ErrorBanner(
          message: CoreErrorMessageService.userFacing(
            ctrl.coreError,
            l10n: context.l10n,
          ),
          onRetry: onConnectionRetry,
        ),
      if (ctrl.dataLoadError != null)
        ErrorBanner(
          message: ctrl.nodes.isNotEmpty
              ? context.l10n.cachedModeActive
              : context.l10n.serverUnavailableNoCache,
          onRetry: onDataRetry,
          warning: true,
        ),
    ];

    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: alerts.isEmpty
          ? const SizedBox.shrink()
          : Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.lg),
              child: Column(
                children: [
                  for (var i = 0; i < alerts.length; i++) ...[
                    if (i > 0) const SizedBox(height: AppSpacing.sm),
                    alerts[i],
                  ],
                ],
              ),
            ),
    );
  }
}
