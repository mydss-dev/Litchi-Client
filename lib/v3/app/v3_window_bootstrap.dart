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
  // F34: last frame this state actually wrote to prefs; the reconciliation
  // poll compares against it so an unchanged frame is never re-written.
  Rect? _lastSavedBounds;
  // F34: reconciliation poll, running only while the window is focused.
  Timer? _boundsPollTimer;
  static const Duration _boundsPollInterval = Duration(milliseconds: 600);

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
    _stopBoundsPoll();
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
      // The launch focus lands before this widget exists, so its focus event
      // is never delivered to this listener; start the reconciliation poll
      // here when the window is already focused. In widget tests
      // window_manager is absent and this throws before any timer exists.
      if (await windowManager.isFocused()) _startBoundsPoll();
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

  // F34: keyboard Snap (Win+arrow) and other programmatic moves resize the
  // window through WM_SIZE only. window_manager emits onWindowMove /
  // onWindowResize from WM_MOVING / WM_SIZING, which the OS sends solely
  // inside the interactive mouse-drag loop, so snapped frames never fire the
  // event-driven saves above and were silently forgotten. Reconcile with a
  // low-frequency poll that runs while the window is focused: each tick
  // compares the live frame with the last saved one and writes only real
  // changes. Moves made while unfocused (display reconfiguration) surface in
  // the immediate check on the next focus.
  @override
  void onWindowFocus() => _startBoundsPoll();

  @override
  void onWindowBlur() => _stopBoundsPoll();

  void _startBoundsPoll() {
    if (!_desktop) return;
    _boundsPollTimer ??= Timer.periodic(
      _boundsPollInterval,
      (_) => unawaited(_saveBounds()),
    );
    // Check now, not one interval in.
    unawaited(_saveBounds());
  }

  void _stopBoundsPoll() {
    _boundsPollTimer?.cancel();
    _boundsPollTimer = null;
  }

  void _scheduleBoundsSave() {
    if (!_desktop || _maximized) return;
    _boundsSaveDebounce?.cancel();
    _boundsSaveDebounce = Timer(const Duration(milliseconds: 600), _saveBounds);
  }

  Future<void> _saveBounds() async {
    try {
      if (await windowManager.isMaximized()) return;
      // A minimized window reports a phantom frame (around -32000 on
      // Windows); the poll could tick inside the focus-loss gap, so skip it
      // here rather than trusting the blur event to have stopped the poll.
      if (await windowManager.isMinimized()) return;
      final bounds = await windowManager.getBounds();
      // The poll re-reads the same frame every tick; persist only real
      // changes. The first check always writes once, establishing the
      // baseline (and healing a stale or now-off-screen entry from an older
      // session).
      final last = _lastSavedBounds;
      if (last != null &&
          last.left == bounds.left &&
          last.top == bounds.top &&
          last.width == bounds.width &&
          last.height == bounds.height) {
        return;
      }
      _lastSavedBounds = bounds;
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
