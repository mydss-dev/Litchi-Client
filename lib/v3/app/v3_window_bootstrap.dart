import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

/// Where the last window frame is remembered, as "left,top,width,height".
/// main.dart reads it before the window shows; this file writes it.
const String kV3WindowBoundsPref = 'v3.window.bounds';

class V3WindowBootstrap extends StatefulWidget {
  const V3WindowBootstrap({super.key, required this.child});

  final Widget child;

  @override
  State<V3WindowBootstrap> createState() => _V3WindowBootstrapState();
}

class _V3WindowBootstrapState extends State<V3WindowBootstrap>
    with WindowListener {
  bool _synced = false;
  bool _maximized = false;
  Timer? _boundsSaveDebounce;

  bool get _desktop =>
      !kIsWeb &&
      switch (defaultTargetPlatform) {
        TargetPlatform.windows ||
        TargetPlatform.macOS ||
        TargetPlatform.linux => true,
        _ => false,
      };

  @override
  void initState() {
    super.initState();
    if (_desktop) windowManager.addListener(this);
  }

  @override
  void dispose() {
    if (_desktop) windowManager.removeListener(this);
    _boundsSaveDebounce?.cancel();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_synced || !_desktop) return;
    _synced = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncV3Window());
  }

  Future<void> _syncV3Window() async {
    try {
      // The 900x700 acceptance floor is also the minimum: the desktop rail
      // plus the page breakpoints are tuned to the pane this leaves. Size and
      // position come from the WindowOptions and the restored bounds in
      // main.dart; re-asserting them here would fight the user's own resize.
      await windowManager.setMinimumSize(const Size(900, 700));
    } catch (_) {
      // window_manager can be absent in widget tests.
    }
  }

  // Bounds memory: follow each move/resize with a short debounce and save the
  // last NORMAL frame. A maximized window's rect would restore as an
  // oversized window, so maximized sessions keep whatever was saved before
  // the maximize.
  @override
  void onWindowMove() => _scheduleBoundsSave();

  @override
  void onWindowResize() => _scheduleBoundsSave();

  @override
  void onWindowMaximize() => _maximized = true;

  @override
  void onWindowUnmaximize() => _maximized = false;

  void _scheduleBoundsSave() {
    if (!_desktop || _maximized) return;
    _boundsSaveDebounce?.cancel();
    _boundsSaveDebounce = Timer(const Duration(milliseconds: 600), _saveBounds);
  }

  Future<void> _saveBounds() async {
    try {
      if (await windowManager.isMaximized()) return;
      final bounds = await windowManager.getBounds();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        kV3WindowBoundsPref,
        '${bounds.left},${bounds.top},${bounds.width},${bounds.height}',
      );
    } catch (_) {
      // Bounds memory is a convenience; prefs or native APIs may be absent.
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
