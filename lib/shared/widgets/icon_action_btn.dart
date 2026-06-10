import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Small square icon button with hover highlight, used in dialogs.
class IconActionBtn extends StatefulWidget {
  const IconActionBtn({
    super.key,
    required this.icon,
    required this.onTap,
    required this.c,
  });
  final IconData icon;
  final VoidCallback onTap;
  final AppColors c;

  @override
  State<IconActionBtn> createState() => _IconActionBtnState();
}

class _IconActionBtnState extends State<IconActionBtn> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: _hover ? widget.c.surfaceMuted : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(widget.icon, size: 16, color: widget.c.iconDefault),
        ),
      ),
    );
  }
}
