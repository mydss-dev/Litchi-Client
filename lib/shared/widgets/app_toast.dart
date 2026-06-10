import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_shadows.dart';
import '../theme/app_text_styles.dart';

enum AppToastType { success, error, warning, info }

class AppToast {
  AppToast._();

  static OverlayEntry? _current;
  static Timer? _timer;

  static const _defaultDuration = Duration(milliseconds: 2500);

  static void show(
    BuildContext context,
    String message, {
    AppToastType type = AppToastType.info,
    Duration duration = _defaultDuration,
  }) {
    showInOverlay(
      Overlay.of(context, rootOverlay: true),
      message,
      type: type,
      duration: duration,
    );
  }

  static void showInOverlay(
    OverlayState overlay,
    String message, {
    AppToastType type = AppToastType.info,
    Duration duration = _defaultDuration,
  }) {
    _clear();
    final entry = OverlayEntry(
      builder: (_) =>
          _ToastWidget(message: message, type: type, duration: duration),
    );
    _current = entry;
    overlay.insert(entry);
    _timer = Timer(duration, _clear);
  }

  static void _clear() {
    _timer?.cancel();
    _timer = null;
    _current?.remove();
    _current = null;
  }
}

class _ToastWidget extends StatefulWidget {
  const _ToastWidget({
    required this.message,
    required this.type,
    required this.duration,
  });

  final String message;
  final AppToastType type;
  final Duration duration;

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget>
    with TickerProviderStateMixin {
  late final AnimationController _entryCtrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  late final AnimationController _progressCtrl;

  @override
  void initState() {
    super.initState();

    // Entry animation: 200ms slide-in + fade-in
    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _fade = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, -0.25),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut));
    _entryCtrl.forward();

    // Progress bar: counts down from 1.0 → 0.0 over the full duration
    _progressCtrl = AnimationController(
      vsync: this,
      duration: widget.duration,
      value: 1.0,
    );
    _progressCtrl.animateTo(0.0, curve: Curves.linear);
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _progressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    final (IconData icon, Color color) = switch (widget.type) {
      AppToastType.success => (LucideIcons.circleCheck, c.success),
      AppToastType.error => (LucideIcons.circleX, c.danger),
      AppToastType.warning => (LucideIcons.alertTriangle, c.warning),
      AppToastType.info => (LucideIcons.info, c.primary),
    };

    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.only(top: 56),
        child: FadeTransition(
          opacity: _fade,
          child: SlideTransition(
            position: _slide,
            child: Material(
              color: Colors.transparent,
              child: IntrinsicWidth(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minWidth: 160,
                    maxWidth: 360,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: c.cardBg,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: c.softBorder),
                      boxShadow: AppShadows.soft(c),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.md - 1),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 11,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 28,
                                  height: 28,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.xs,
                                    ),
                                  ),
                                  child: Icon(icon, size: 15, color: color),
                                ),
                                const SizedBox(width: 10),
                                Flexible(
                                  child: Text(
                                    widget.message,
                                    style: AppTextStyles.body.copyWith(
                                      color: c.textPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          AnimatedBuilder(
                            animation: _progressCtrl,
                            builder: (_, child) => LinearProgressIndicator(
                              value: _progressCtrl.value,
                              minHeight: 3,
                              backgroundColor: Colors.transparent,
                              color: color.withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
