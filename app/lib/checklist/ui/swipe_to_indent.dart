import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Lets the user swipe [child] right to indent or left to outdent, by
/// touch. The child follows the finger a little and slides back on
/// release.
///
/// Watches raw pointer moves rather than joining the gesture arena, so a
/// swipe that starts on the item's text field still counts. Mouse drags
/// are left to text selection; keyboards have Tab.
class SwipeToIndent extends StatefulWidget {
  const SwipeToIndent({
    required this.onIndent,
    required this.onOutdent,
    required this.child,
    super.key,
  });

  final VoidCallback onIndent;
  final VoidCallback onOutdent;
  final Widget child;

  /// How far to swipe for an action.
  static const threshold = 48.0;

  /// How far the child follows the finger.
  static const _maxShift = 64.0;

  @override
  State<SwipeToIndent> createState() => _SwipeToIndentState();
}

class _SwipeToIndentState extends State<SwipeToIndent> {
  Offset? _start;
  double _dx = 0;

  void _onDown(PointerDownEvent event) {
    final touch =
        event.kind == PointerDeviceKind.touch ||
        event.kind == PointerDeviceKind.stylus;
    _start = touch ? event.position : null;
  }

  void _onMove(PointerMoveEvent event) {
    final start = _start;
    if (start == null) return;
    final delta = event.position - start;
    // Mostly vertical: a scroll, not a swipe.
    if (delta.dy.abs() > delta.dx.abs() && delta.dy.abs() > kTouchSlop) {
      _reset();
      return;
    }
    setState(() => _dx = delta.dx);
  }

  void _onUp(PointerUpEvent _) {
    if (_dx >= SwipeToIndent.threshold) widget.onIndent();
    if (_dx <= -SwipeToIndent.threshold) widget.onOutdent();
    _reset();
  }

  void _reset() {
    _start = null;
    if (_dx != 0) setState(() => _dx = 0);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _onDown,
      onPointerMove: _onMove,
      onPointerUp: _onUp,
      onPointerCancel: (_) => _reset(),
      child: AnimatedContainer(
        // Follows the finger at once; slides back after release.
        duration: _dx == 0 ? const Duration(milliseconds: 150) : Duration.zero,
        transform: Matrix4.translationValues(
          _dx.clamp(-SwipeToIndent._maxShift, SwipeToIndent._maxShift),
          0,
          0,
        ),
        child: widget.child,
      ),
    );
  }
}
