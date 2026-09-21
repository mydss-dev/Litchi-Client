import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme/v3_palette.dart';

/// Short-lived feedback for user actions, not server announcements.
///
/// Restores the pre-V3 top-center floating toast without importing the retired
/// greenfield theme. Successful actions use the Litchi brand color; errors and
/// warnings retain their distinct icons and semantic colors.
enum V3ToastType { success, error, warning, info }

class V3Toast {
  V3Toast._();

  static OverlayEntry? _current;
  static Timer? _timer;
  static const defaultDuration = Duration(milliseconds: 2500);

  static void show(
    BuildContext context,
    String message, {
    V3ToastType type = V3ToastType.info,
    Duration duration = defaultDuration,
  }) {
    showInOverlay(
      Overlay.of(context, rootOverlay: true),
      message,
      type: type,
      duration: duration,
    );
  }

  /// Capture the root overlay before an await or a dialog pop, then call this
  /// method after the action finishes so the toast survives the closed sheet.
  static void showInOverlay(
    OverlayState overlay,
    String message, {
    V3ToastType type = V3ToastType.info,
    Duration duration = defaultDuration,
  }) {
    _clear();
    final entry = OverlayEntry(
      builder: (_) => _V3ToastView(
        message: message,
        type: type,
        duration: duration,
      ),
    );
    _current = entry;
    overlay.insert(entry);
    _timer = Timer(duration, _clear);
  }

  static void _clear() {
    _timer?.cancel();
    _timer = null;
    final entry = _current;
    _current = null;
    entry?.remove();
    entry?.dispose();
  }
}

class _V3ToastView extends StatefulWidget {
  const _V3ToastView({
    required this.message,
    required this.type,
    required this.duration,
  });

  final String message;
  final V3ToastType type;
  final Duration duration;

  @override
  State<_V3ToastView> createState() => _V3ToastViewState();
}

class _V3ToastViewState extends State<_V3ToastView>
    with TickerProviderStateMixin {
  late final AnimationController _entryController;
  late final AnimationController _progressController;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _fade = CurvedAnimation(
      parent: _entryController,
      curve: Curves.easeOutCubic,
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, -0.12),
      end: Offset.zero,
    ).animate(_fade);
    _progressController = AnimationController(
      vsync: this,
      duration: widget.duration,
      value: 1,
    );
    _entryController.forward();
    _progressController.animateTo(0, curve: Curves.linear);
  }

  @override
  void dispose() {
    _entryController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    final (icon, accent) = switch (widget.type) {
      V3ToastType.success => (Icons.check_circle_outline_rounded, p.lychee),
      V3ToastType.error => (Icons.error_outline_rounded, p.danger),
      V3ToastType.warning => (Icons.warning_amber_rounded, p.warning),
      V3ToastType.info => (Icons.info_outline_rounded, p.lychee),
    };
    final platform = Theme.of(context).platform;
    final mobile = !kIsWeb &&
        (platform == TargetPlatform.android || platform == TargetPlatform.iOS);
    final card = Semantics(
      liveRegion: true,
      label: widget.message,
      child: Material(
        color: Colors.transparent,
        child: IntrinsicWidth(
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 160, maxWidth: 360),
            child: Container(
              decoration: BoxDecoration(
                color: p.surface,
                borderRadius: BorderRadius.circular(V3Radius.field),
                border: Border.all(color: p.line),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: .16),
                    blurRadius: 20,
                    offset: const Offset(0, 7),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: .12),
                            borderRadius: BorderRadius.circular(V3Radius.control),
                          ),
                          child: Icon(icon, size: 16, color: accent),
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            widget.message,
                            style: TextStyle(
                              color: p.ink,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedBuilder(
                    animation: _progressController,
                    builder: (context, _) => LinearProgressIndicator(
                      value: _progressController.value,
                      minHeight: 3,
                      backgroundColor: Colors.transparent,
                      color: accent.withValues(alpha: .65),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return Align(
      alignment: Alignment.topCenter,
      child: SafeArea(
        minimum: EdgeInsets.only(top: mobile ? 16 : 48),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: reduceMotion
              ? card
              : FadeTransition(
                  opacity: _fade,
                  child: SlideTransition(position: _slide, child: card),
                ),
        ),
      ),
    );
  }
}
