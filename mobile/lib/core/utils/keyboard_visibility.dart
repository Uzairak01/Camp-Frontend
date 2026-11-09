import 'dart:ui';
import 'package:flutter/widgets.dart';

/// Helper to inspect soft keyboard visibility by reading the physical
/// window view insets [View.of(context).viewInsets.bottom > 0], bypassing
/// Scaffold-adjusted [MediaQueryData.viewInsets] which is consumed when
/// `resizeToAvoidBottomInset` is true.
class KeyboardVisibility {
  /// Returns `true` if the software keyboard is currently visible.
  static bool isVisible(BuildContext context) {
    try {
      return View.of(context).viewInsets.bottom > 0;
    } catch (_) {
      return false;
    }
  }
}

/// A reactive widget that rebuilds whenever the soft keyboard opens or closes.
///
/// Uses [WidgetsBindingObserver.didChangeMetrics] to detect when the view insets
/// change, reading [View.of(context).viewInsets.bottom > 0].
class KeyboardVisibilityBuilder extends StatefulWidget {
  const KeyboardVisibilityBuilder({
    required this.builder,
    super.key,
    this.child,
  });

  final Widget Function(BuildContext context, bool isKeyboardVisible, Widget? child) builder;
  final Widget? child;

  @override
  State<KeyboardVisibilityBuilder> createState() => _KeyboardVisibilityBuilderState();
}

class _KeyboardVisibilityBuilderState extends State<KeyboardVisibilityBuilder>
    with WidgetsBindingObserver {
  bool _isKeyboardVisible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateVisibility();
  }

  @override
  void didChangeMetrics() {
    _updateVisibility();
  }

  void _updateVisibility() {
    final visible = KeyboardVisibility.isVisible(context);
    if (visible != _isKeyboardVisible) {
      if (mounted) {
        setState(() {
          _isKeyboardVisible = visible;
        });
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, _isKeyboardVisible, widget.child);
  }
}

/// A [ValueNotifier] that tracks soft keyboard visibility using [WidgetsBindingObserver].
class KeyboardVisibilityNotifier extends ValueNotifier<bool> with WidgetsBindingObserver {
  KeyboardVisibilityNotifier(this._view) : super(_view.viewInsets.bottom > 0) {
    WidgetsBinding.instance.addObserver(this);
  }

  final FlutterView _view;

  @override
  void didChangeMetrics() {
    final isVisible = _view.viewInsets.bottom > 0;
    if (value != isVisible) {
      value = isVisible;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
