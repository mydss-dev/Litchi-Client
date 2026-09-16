import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

class V3WindowBootstrap extends StatefulWidget {
  const V3WindowBootstrap({super.key, required this.child});

  final Widget child;

  @override
  State<V3WindowBootstrap> createState() => _V3WindowBootstrapState();
}

class _V3WindowBootstrapState extends State<V3WindowBootstrap> {
  bool _synced = false;

  bool get _desktop =>
      !kIsWeb &&
      switch (defaultTargetPlatform) {
        TargetPlatform.windows ||
        TargetPlatform.macOS ||
        TargetPlatform.linux => true,
        _ => false,
      };

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_synced || !_desktop) return;
    _synced = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncV3Window());
  }

  Future<void> _syncV3Window() async {
    try {
      await windowManager.setMinimumSize(const Size(760, 600));
      await windowManager.setSize(const Size(900, 700));
      await windowManager.center();
    } catch (_) {
      // window_manager can be absent in widget tests.
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
