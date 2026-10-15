import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/v3_motion.dart';
import '../theme/v3_palette.dart';

/// V3's single selection control. One dropdown spec serves both the settings
/// rows and the title-bar language switch: a raised field that opens a menu
/// extending straight down from its bottom edge — the list lines up with the
/// field and never covers it (a real combobox, not a detachable floating card).
///
/// Built on [MenuAnchor] instead of [PopupMenuButton]: the menu surface is
/// drawn by hand (hairline outline plus the palette's soft shadows, the same
/// layering recipe as every other V3 floating panel), item hover is an inset
/// rounded pill instead of a full-bleed rectangle, the field gets a real hover
/// state, and the entrance runs at the app's own tempo (fade plus a 4px slide
/// at [V3Motion.fast]) rather than the framework's fixed 500ms.
class V3Dropdown<T> extends StatefulWidget {
  const V3Dropdown({
    super.key,
    required this.value,
    required this.items,
    required this.label,
    required this.onChanged,
    this.face,
    this.width,
    this.menuWidth,
    this.dense = false,
    this.tooltip,
  });

  final T value;
  final List<T> items;

  /// Menu label for every value.
  final String Function(T) label;

  /// Trigger text; defaults to [label] of the selected value. The title bar
  /// overrides this with a two-letter code so the trigger stays compact.
  final String Function(T)? face;

  final ValueChanged<T> onChanged;

  /// Fixed width for rows whose controls align down the page; null
  /// shrink-wraps the widest label.
  final double? width;

  /// Width of the open menu; defaults to [width]. A compact title-bar trigger
  /// (a CN/TW/EN code) must widen the menu so long labels are not clipped.
  final double? menuWidth;

  /// Compact sizing for the title-bar switch (smaller type, tighter padding).
  final bool dense;

  final String? tooltip;

  @override
  State<V3Dropdown<T>> createState() => _V3DropdownState<T>();
}

class _V3DropdownState<T> extends State<V3Dropdown<T>> {
  final MenuController _controller = MenuController();

  // A tap on the field while the menu is open arrives here as an outside-tap
  // close (pointer down) followed by this tap (pointer up) — by then the menu
  // is already closed, so "isOpen ? close : open" would re-open it instantly.
  // MenuAnchor.close() flips the controller's status to [AnimationStatus.reverse]
  // synchronously, so the status as of the tap separates the two cases: a
  // reverse still in flight means this very gesture closed it, and the tap
  // must not undo that.
  AnimationStatus _status = AnimationStatus.dismissed;
  bool _hovered = false;

  // Only keyboard navigation focuses the trigger (a pointer tap opens the
  // menu without a focus request), so this is the focus-visible state the
  // field paints for.
  bool _focused = false;

  // One focus handle per menu item, kept across rebuilds: the keyboard path
  // parks focus on an entry right after opening the menu (pointer taps never
  // do), and once focus is inside an item the framework's own menu traversal
  // shortcuts take over — arrows cycle, Escape closes, and when the overlay
  // unmounts focus falls back to the previously focused trigger.
  List<FocusNode> _itemNodes = <FocusNode>[];

  @override
  void initState() {
    super.initState();
    _syncItemNodes();
  }

  @override
  void didUpdateWidget(V3Dropdown<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncItemNodes();
  }

  // The nodes are pure focus handles (no per-item state), so they only need to
  // track the item count; relabeled or reordered entries reuse them.
  void _syncItemNodes() {
    final int count = widget.items.length;
    if (_itemNodes.length == count) return;
    for (final node in _itemNodes) {
      node.dispose();
    }
    _itemNodes = List<FocusNode>.generate(
      count,
      (int index) => FocusNode(debugLabel: 'V3Dropdown.menuItem#$index'),
    );
  }

  @override
  void dispose() {
    for (final node in _itemNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _toggle() {
    if (_status == AnimationStatus.reverse) return;
    if (_controller.isOpen) {
      _controller.close();
      return;
    }
    _controller.open();
  }

  // Keyboard open: arrow down starts at the selected entry when there is one
  // (the APG combobox start point), falling back to the first entry for down
  // and the last for up. The overlay mounts a frame after [MenuController.open]
  // fires, but a requestFocus on a not-yet-attached node is deferred by the
  // framework until the node enters the tree, so no post-frame dance is needed.
  void _openAndFocusItem({required bool fallbackToFirst}) {
    if (_status == AnimationStatus.reverse) return;
    if (_itemNodes.isEmpty) return;
    if (!_controller.isOpen) _controller.open();
    final int selectedIndex = widget.items.indexOf(widget.value);
    final FocusNode node =
        selectedIndex >= 0 && selectedIndex < _itemNodes.length
            ? _itemNodes[selectedIndex]
            : (fallbackToFirst ? _itemNodes.first : _itemNodes.last);
    node.requestFocus();
  }

  // Shared by the pointer tap, the semantics tap action and the ink well: a
  // selection always closes the menu before handing the value back.
  void _select(T item) {
    _controller.close();
    widget.onChanged(item);
  }

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    final dense = widget.dense;
    final fontSize = dense ? 12.0 : 13.0;
    final itemWidth = widget.menuWidth ?? widget.width;

    // The closed trigger is always the neutral ink colour; the pink selection
    // stays inside the open menu.
    final triggerText = widget.face != null
        ? widget.face!(widget.value)
        : widget.label(widget.value);

    final trigger = Container(
      width: widget.width,
      padding: EdgeInsets.only(left: dense ? 10 : 12, right: dense ? 6 : 8),
      decoration: BoxDecoration(
        // Keyboard focus raises the theme's 12% ink state layer on the fill —
        // the same wash an InkWell paints — composited onto the field fill so
        // the color is identical wherever the dropdown sits.
        color: _focused
            ? Color.alphaBlend(p.ink.withValues(alpha: 0.12), p.surfaceRaised)
            : p.surfaceRaised,
        // Hover deepens the outline one step (the Fluent ComboBox affordance);
        // the fill stays put so the field does not flicker under the pointer.
        border: Border.all(color: _hovered ? p.line : p.hairline),
        borderRadius:
            BorderRadius.circular(dense ? V3Radius.control : V3Radius.field),
      ),
      child: SizedBox(
        // 44 clears the design system's touch-target floor (WCAG 2.5.5) on
        // the settings rows and lands next to the ~50px text fields on the
        // same page; the dense title-bar switch keeps its compact 32.
        height: dense ? 32 : 44,
        child: Row(
          mainAxisSize: widget.width == null ? MainAxisSize.min : MainAxisSize.max,
          children: [
            if (widget.width != null)
              Expanded(
                  child: _text(triggerText, p.ink, fontSize, FontWeight.w600))
            else
              _text(triggerText, p.ink, fontSize, FontWeight.w700),
            SizedBox(width: dense ? 6 : 8),
            Icon(Icons.keyboard_arrow_down_rounded,
                size: dense ? 16 : 18, color: p.inkMuted),
          ],
        ),
      ),
    );

    final anchor = MenuAnchor(
      controller: _controller,
      // The framework's own open animation is a fixed 500ms — far past the
      // app's tempo. Instant mount here; the entrance lives in [_menuSurface].
      animated: false,
      clipBehavior: Clip.none,
      onAnimationStatusChanged: (status) {
        _status = status;
      },
      // Every fill/elevation/shadow is nullified so the framework's Material
      // paints nothing; [_menuSurface] is the whole visual.
      style: const MenuStyle(
        backgroundColor: WidgetStatePropertyAll(Colors.transparent),
        elevation: WidgetStatePropertyAll(0),
        shadowColor: WidgetStatePropertyAll(Colors.transparent),
        surfaceTintColor: WidgetStatePropertyAll(Colors.transparent),
        padding: WidgetStatePropertyAll(EdgeInsets.zero),
        shape: WidgetStatePropertyAll(RoundedRectangleBorder()),
        minimumSize: WidgetStatePropertyAll(Size(0, 0)),
      ),
      menuChildren: [_menuSurface(p, fontSize, itemWidth)],
      builder: (context, controller, child) => FocusableActionDetector(
        // The trigger is focusable and keyboard-activatable: Tab reaches it,
        // Enter/Space reuse the pointer's [_toggle], and the framework's own
        // hover/focus-highlight callbacks (no-op in touch mode) drive the
        // field's states. A MouseRegion supplies only the pointer cursor —
        // hover paint stays with the framework callbacks.
        //
        // Arrow keys open the menu straight onto an entry, so keyboard users
        // are never stranded on the trigger; from there the framework's own
        // menu traversal shortcuts cycle arrows and close on Escape, and the
        // overlay unmount hands focus back to the trigger. Escape is also
        // mapped on the trigger itself for a menu opened by pointer, where
        // focus never moved into the overlay — the action is disabled while
        // the menu is closed, so the key still bubbles to enclosing dialogs.
        onShowHoverHighlight: (value) => setState(() => _hovered = value),
        onShowFocusHighlight: (value) => setState(() => _focused = value),
        shortcuts: const <ShortcutActivator, Intent>{
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.numpadEnter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.arrowDown):
              _MenuArrowIntent(fallbackToFirst: true),
          SingleActivator(LogicalKeyboardKey.arrowUp):
              _MenuArrowIntent(fallbackToFirst: false),
          SingleActivator(LogicalKeyboardKey.escape): DismissIntent(),
        },
        actions: <Type, Action<Intent>>{
          ActivateIntent:
              CallbackAction<ActivateIntent>(onInvoke: (_) => _toggle()),
          _MenuArrowIntent: CallbackAction<_MenuArrowIntent>(
              onInvoke: (intent) =>
                  _openAndFocusItem(fallbackToFirst: intent.fallbackToFirst)),
          DismissIntent: _CloseMenuAction(_controller),
        },
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: _toggle,
            child: Semantics(
              button: true,
              onTap: _toggle,
              child: child,
            ),
          ),
        ),
      ),
      child: trigger,
    );

    // A hover bubble on the settings rows is noise (they label themselves) —
    // callers opt in by passing a real tooltip, and only then does one show.
    if (widget.tooltip == null) return anchor;
    return Tooltip(
      message: widget.tooltip,
      waitDuration: const Duration(milliseconds: 400),
      child: anchor,
    );
  }

  /// The menu panel: V3's floating-surface recipe (raised fill, hairline
  /// outline, soft contact shadows), 6px breathing room, and items whose hover
  /// highlight is an inset rounded pill. The entrance is a [V3Motion.fast]
  /// fade with a 4px drop into place — settled, not popped — and reduced-motion
  /// settings land on the final state directly.
  Widget _menuSurface(V3Palette p, double fontSize, double? itemWidth) {
    final entrance = TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: v3ReducedMotion(context) ? Duration.zero : V3Motion.fast,
      curve: V3Motion.ease,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, -4 * (1 - t)),
          child: child,
        ),
      ),
      child: Container(
        width: itemWidth,
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: p.surfaceRaised,
          borderRadius: BorderRadius.circular(V3Radius.control),
          border: Border.all(color: p.hairline),
          boxShadow: p.shadows,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (index, item) in widget.items.indexed)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: SizedBox(
                  height: widget.dense ? 36 : 40,
                  child: Semantics(
                    container: true,
                    button: true,
                    selected: item == widget.value,
                    onTap: () => _select(item),
                    child: InkWell(
                      focusNode: _itemNodes[index],
                      borderRadius: BorderRadius.circular(V3Radius.control),
                      onTap: () => _select(item),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _text(
                              widget.label(item),
                              item == widget.value ? p.lycheeInk : p.ink,
                              fontSize,
                              item == widget.value
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                            if (item == widget.value)
                              Icon(Icons.check_rounded,
                                  size: 16, color: p.lycheeInk),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
    return entrance;
  }

  Widget _text(String text, Color color, double size, FontWeight weight) =>
      Text(text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: color, fontSize: size, fontWeight: weight));
}

/// Arrow-key intent for the dropdown trigger: opens the menu and parks focus
/// on an entry so the framework's menu traversal takes over from there.
class _MenuArrowIntent extends Intent {
  const _MenuArrowIntent({required this.fallbackToFirst});

  /// Where to start when no entry matches the current value: down wants the
  /// first entry, up the last.
  final bool fallbackToFirst;
}

/// Escape on the trigger while the menu is open — the fallback for a pointer
/// open, where focus never moved into the overlay. Disabled while the menu is
/// closed so the key bubbles to whatever else handles Escape above us.
class _CloseMenuAction extends Action<DismissIntent> {
  _CloseMenuAction(this._controller);

  final MenuController _controller;

  @override
  bool get isActionEnabled => _controller.isOpen;

  @override
  void invoke(DismissIntent intent) => _controller.close();
}
