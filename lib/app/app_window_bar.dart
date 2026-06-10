import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:window_manager/window_manager.dart';

import '../shared/theme/app_colors.dart';
import '../shared/theme/app_radius.dart';

/// Slim top strip hosting the window controls (§7, reconciled with the design
/// screenshots): the brand lives in the sidebar, so there is no brand text
/// here. Controls match the design: minimize, maximize/restore, close. The
/// empty area is draggable to move the window.
class WindowControlsBar extends StatefulWidget {
  const WindowControlsBar({super.key, this.height = 46});

  final double height;

  @override
  State<WindowControlsBar> createState() => _WindowControlsBarState();
}

class _WindowControlsBarState extends State<WindowControlsBar>
    with WindowListener {
  bool _maximized = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _sync();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  Future<void> _sync() async {
    final m = await windowManager.isMaximized();
    if (mounted) setState(() => _maximized = m);
  }

  @override
  void onWindowMaximize() => setState(() => _maximized = true);

  @override
  void onWindowUnmaximize() => setState(() => _maximized = false);

  Future<void> _toggleMaximize() async {
    if (await windowManager.isMaximized()) {
      windowManager.unmaximize();
    } else {
      windowManager.maximize();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: Row(
        children: [
          // Draggable region fills all space left of the buttons; double-click
          // toggles maximize like a normal title bar.
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onPanStart: (_) => windowManager.startDragging(),
              onDoubleTap: _toggleMaximize,
              child: const SizedBox.expand(),
            ),
          ),
          _WindowButton(
            icon: LucideIcons.minus,
            onTap: () => windowManager.minimize(),
          ),
          _WindowButton(
            icon: _maximized ? LucideIcons.copy : LucideIcons.square,
            iconSize: _maximized ? 12 : 13,
            onTap: _toggleMaximize,
          ),
          _WindowButton(
            icon: LucideIcons.x,
            isClose: true,
            onTap: () => windowManager.close(),
          ),
          const SizedBox(width: 12),
        ],
      ),
    );
  }
}

class _WindowButton extends StatefulWidget {
  const _WindowButton({
    required this.icon,
    required this.onTap,
    this.isClose = false,
    this.iconSize = 14,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool isClose;
  final double iconSize;

  @override
  State<_WindowButton> createState() => _WindowButtonState();
}

class _WindowButtonState extends State<_WindowButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final Color bg;
    final Color iconColor;
    if (_hover) {
      bg = widget.isClose ? c.dangerSoft : c.surfaceMuted;
      iconColor = widget.isClose ? c.danger : c.textPrimary;
    } else {
      bg = Colors.transparent;
      iconColor = c.iconDefault;
    }

    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(AppRadius.xs),
            ),
            child: Icon(widget.icon, size: widget.iconSize, color: iconColor),
          ),
        ),
      ),
    );
  }
}
