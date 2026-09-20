from pathlib import Path


def replace(path, old, new, expected=1):
    p = Path(path)
    source = p.read_text(encoding='utf-8')
    count = source.count(old)
    if count != expected:
        raise SystemExit(f'{path}: expected {expected}, found {count}: {old[:90]!r}')
    p.write_text(source.replace(old, new), encoding='utf-8')


ctl = 'lib/app/app_controller.dart'
replace(ctl, '  bool _hasAccountSummary = false;',
        '  bool _hasAccountSummary = false;\n  // Only two successful negative API responses can confirm no plan.\n  bool _confirmedNoPlan = false;')
replace(ctl, '  bool get hasAccountSummary => _hasAccountSummary;',
        '  bool get hasAccountSummary => _hasAccountSummary;\n  bool get hasConfirmedNoPlan => _confirmedNoPlan && !hasPlan;')
replace(ctl, '    final confirmedNoPlan = snap.hasPlan == false;',
        '    // Failure or incomplete data is unknown, never a confirmed no-plan.\n    _confirmedNoPlan = snap.hasPlan == false;\n    final confirmedNoPlan = _confirmedNoPlan;')
replace(ctl, '    _hasAccountSummary = false;',
        '    _hasAccountSummary = false;\n    _confirmedNoPlan = false;', expected=2)
replace(ctl, '    _authData = authData;\n    await Future.wait([',
        '    _authData = authData;\n    _confirmedNoPlan = false;\n    await Future.wait([', expected=2)

dash = 'lib/v3/pages/v3_dashboard_page.dart'
replace(dash, "import 'package:flutter/material.dart';", "import 'package:flutter/material.dart';\nimport 'package:flutter/foundation.dart';")
replace(dash, '    final confirmedNoPlan = controller.hasAccountSummary &&\n        !controller.isInitialLoading && !controller.hasPlan;',
        '    final confirmedNoPlan = !controller.isInitialLoading &&\n        controller.hasConfirmedNoPlan;')
replace(dash, '''                                  Text(
                                    _duration(controller.connectedDuration),
                                    style: TextStyle(
                                      color: p.inkMuted,
                                      fontSize: 11,
                                    ),
                                  ),''',
        '                                  _ConnectionDuration(controller: controller),')
replace(dash, 'class _ModeRail extends StatelessWidget {', '''// Tick only the elapsed-time label, not the whole dashboard.
class _ConnectionDuration extends StatefulWidget {
  const _ConnectionDuration({required this.controller});
  final AppController controller;

  @override
  State<_ConnectionDuration> createState() => _ConnectionDurationState();
}

class _ConnectionDurationState extends State<_ConnectionDuration> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _syncTicker();
  }

  @override
  void didUpdateWidget(covariant _ConnectionDuration oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncTicker();
  }

  void _syncTicker() {
    if (widget.controller.connectionStatus == ConnectionStatus.connected) {
      _ticker ??= Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else {
      _ticker?.cancel();
      _ticker = null;
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Text(
    _duration(widget.controller.connectedDuration),
    key: const Key('v3-connection-duration'),
    style: TextStyle(color: V3Palette.of(context).inkMuted, fontSize: 11),
  );
}

/// Hide unsupported system-proxy status from Android and Linux Home.
bool v3ShowsNetworkMode(TargetPlatform platform, NetworkMode mode) =>
    mode == NetworkMode.tun ||
    platform == TargetPlatform.windows || platform == TargetPlatform.macOS;

class _ModeRail extends StatelessWidget {''')
replace(dash, '            for (final mode in NetworkMode.values)\n              Expanded(',
        '            for (final mode in NetworkMode.values)\n              if (v3ShowsNetworkMode(defaultTargetPlatform, mode)) Expanded(', expected=1)

account = 'lib/v3/pages/v3_account_page.dart'
replace(account, '''        const SizedBox(height: 16),
        _PreferencesPanel(controller: controller,
          busy: _updatingPreferences,
          onExpireChanged: (v) => _updatePreferences(remindExpire: v),
          onTrafficChanged: (v) => _updatePreferences(remindTraffic: v),
          onAutoRenewalChanged: (v) => _updatePreferences(autoRenewal: v)),''', '''        if (controller.hasPlan) ...[
          const SizedBox(height: 16),
          _PreferencesPanel(controller: controller,
            busy: _updatingPreferences,
            onExpireChanged: (v) => _updatePreferences(remindExpire: v),
            onTrafficChanged: (v) => _updatePreferences(remindTraffic: v),
            onAutoRenewalChanged: (v) => _updatePreferences(autoRenewal: v)),
        ],''')
traffic = 'lib/v3/pages/v3_traffic_page.dart'
replace(traffic, 'if (!controller.hasPlan && controller.hasAccountSummary) {',
        'if (controller.hasConfirmedNoPlan && !controller.isInitialLoading) {')

test = Path('test/v3_four_followup_fixes_test.dart')
test.write_text('''import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/shared/models/app_models.dart';
import 'package:litchi_client/v3/pages/v3_dashboard_page.dart';

void main() {
  test('only desktop platforms display system proxy', () {
    for (final platform in [TargetPlatform.windows, TargetPlatform.macOS]) {
      expect(v3ShowsNetworkMode(platform, NetworkMode.system), isTrue);
      expect(v3ShowsNetworkMode(platform, NetworkMode.tun), isTrue);
    }
    for (final platform in [TargetPlatform.android, TargetPlatform.linux]) {
      expect(v3ShowsNetworkMode(platform, NetworkMode.system), isFalse);
      expect(v3ShowsNetworkMode(platform, NetworkMode.tun), isTrue);
    }
  });
}
''', encoding='utf-8')
