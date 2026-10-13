import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Lets the user swipe [child] right to indent or left to outdent, by
/// touch or mouse. The child follows the pointer a little and slides back
/// on release.
///
/// Watches raw pointer moves rather than joining the gesture arena, so a
/// swipe that starts on the item's text field still counts. A mouse drag
/// that starts inside [SwipeToIndent.keepMouseDrags] is left alone, e.g.
/// to select text.
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

  /// How far the child follows the pointer.
  static const _maxShift = 64.0;

  /// Leaves mouse drags that start on [child] to it, e.g. text selection
  /// or reordering.
  static Widget keepMouseDrags(Widget child) => _KeepMouseDrags(child);

  @override
  State<SwipeToIndent> createState() => _SwipeToIndentState();
}

/// Tells the enclosing swipe that a mouse press landed on [child].
class _KeepMouseDrags extends StatelessWidget {
  const _KeepMouseDrags(this.child);

  final Widget child;

  @override
  Widget build(BuildContext context) => Listener(
    // Runs before the enclosing swipe's listener: deeper widgets get
    // pointer events first.
    onPointerDown: (event) {
      if (event.kind == PointerDeviceKind.mouse) {
        context.findAncestorStateOfType<_SwipeToIndentState>()?._kept =
            event.pointer;
      }
    },
    child: child,
  );
}

class _SwipeToIndentState extends State<SwipeToIndent> {
  Offset? _start;
  double _dx = 0;

  /// The mouse pointer that went down in a [SwipeToIndent.keepMouseDrags]
  /// child, if any.
  int? _kept;

  void _onDown(PointerDownEvent event) {
    final kept = event.pointer == _kept;
    _kept = null;
    _start = kept ? null : event.position;
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
        // Follows the pointer at once; slides back after release.
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
