import 'package:flutter/widgets.dart';

import '../../app/app_controller.dart';

/// Fine-grained subscription to a slice of [AppController].
///
/// Unlike `AppScope.of(context)` — which rebuilds the dependent on *every*
/// `notifyListeners()` — this widget listens to the controller directly and
/// rebuilds only when the [selector] output changes (compared with `==`).
///
/// This is the migration primitive away from the coarse whole-tree rebuild:
/// move hot, single-value consumers (connection status, a counter, a flag) to
/// `AppSelector` so unrelated state changes no longer rebuild them.
///
/// ```dart
/// AppSelector<ConnectionStatus>(
///   selector: (c) => c.connectionStatus,
///   builder: (context, status, _) => StatusBadge(status),
/// )
/// ```
class AppSelector<T> extends StatefulWidget {
  const AppSelector({
    super.key,
    required this.selector,
    required this.builder,
    this.child,
  });

  /// Extracts the slice this widget cares about. Should be cheap and pure.
  final T Function(AppController controller) selector;

  /// Builds the subtree from the selected [value]. [child] is the optional
  /// pre-built, rebuild-independent subtree passed through unchanged.
  final Widget Function(BuildContext context, T value, Widget? child) builder;

  /// A subtree that does not depend on [value]; built once and reused.
  final Widget? child;

  @override
  State<AppSelector<T>> createState() => _AppSelectorState<T>();
}

class _AppSelectorState<T> extends State<AppSelector<T>> {
  AppController? _controller;
  late T _value;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = AppScope.read(context);
    if (!identical(controller, _controller)) {
      _controller?.removeListener(_onControllerChanged);
      _controller = controller;
      _controller!.addListener(_onControllerChanged);
      _value = widget.selector(controller);
    }
  }

  @override
  void didUpdateWidget(covariant AppSelector<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    final controller = _controller;
    if (controller != null) _value = widget.selector(controller);
  }

  void _onControllerChanged() {
    final next = widget.selector(_controller!);
    if (next != _value) {
      setState(() => _value = next);
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_onControllerChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(context, _value, widget.child);
}
