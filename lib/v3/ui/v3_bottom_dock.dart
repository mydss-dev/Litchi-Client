import 'package:material_ui/material_ui.dart';

import '../../app/app_controller.dart';
import '../../shared/theme/app_icons.dart';
import '../app/v3_nav.dart';
import '../theme/v3_motion.dart';
import '../theme/v3_palette.dart';

/// The phone dock: a white capsule with four tabs, where the current tab is a
/// solid ink pill holding its own icon and label.
///
/// This is the reference layout — icon over a 10px label, 64dp tall, 30dp
/// radius, one hairline and a soft shadow. Selection is a filled pill rather
/// than a tint, so the current tab stays readable in both brightness modes
/// without a second icon weight.
class V3BottomDock extends StatelessWidget {
  const V3BottomDock({
    super.key,
    required this.controller,
    required this.items,
  });

  final AppController controller;
  final List<V3NavItem> items;

  static const double height = 64;
  static const double _radius = 30;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    final selectedIndex = selectedPrimaryIndex(controller.page) ?? 0;
    return SafeArea(
      top: false,
      left: false,
      right: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
        child: Container(
          height: height,
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(_radius),
            border: Border.all(color: p.line.withValues(alpha: .7)),
            boxShadow: p.shadows,
          ),
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: _DockTab(
                    key: ValueKey('v3-dock-${items[i].page.name}'),
                    icon: items[i].icon,
                    label: items[i].localizedLabel(context),
                    selected: i == selectedIndex,
                    onTap: () => controller.goToPage(items[i].page),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DockTab extends StatefulWidget {
  const _DockTab({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_DockTab> createState() => _DockTabState();
}

class _DockTabState extends State<_DockTab> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    // Ink pill in light mode, near-white pill in dark mode: onInk is whatever
    // the pill's own fill is not.
    final pill = p.ink;
    final onPill = p.surface;
    final idle = _pressed ? p.ink : p.inkMuted;
    final duration = v3ReducedMotion(context)
        ? Duration.zero
        : const Duration(milliseconds: 220);

    return Semantics(
      button: true,
      selected: widget.selected,
      label: widget.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: duration,
          curve: V3Motion.ease,
          decoration: BoxDecoration(
            color: widget.selected ? pill : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                widget.icon,
                size: AppIconSize.lg,
                color: widget.selected ? onPill : idle,
              ),
              const SizedBox(height: 3),
              Text(
                widget.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  height: 1.1,
                  letterSpacing: .1,
                  fontWeight: widget.selected ? FontWeight.w700 : FontWeight.w500,
                  color: widget.selected ? onPill : idle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
