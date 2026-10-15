import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Lets the user swipe [child] right to indent or left to outdent, by
/// touch or mouse. The child follows the pointer by up to one [step], the
/// width of one indent level; a swipe that reaches it acts on release.
/// The child slides back either way.
///
/// Watches raw pointer moves rather than joining the gesture arena, so a
/// swipe that starts on the item's text field still counts. A mouse drag
/// that starts inside [SwipeToIndent.keepMouseDrags] is left alone, e.g.
/// to select text, and so is a long press that then moves (touch text
/// selection) and a touch drag that child asks to keep (e.g. to scroll
/// its text).
class SwipeToIndent extends StatefulWidget {
  const SwipeToIndent({
    required this.step,
    required this.onIndent,
    required this.onOutdent,
    required this.child,
    super.key,
  });

  /// Width of one indent level on screen.
  final double step;

  final VoidCallback onIndent;
  final VoidCallback onOutdent;
  final Widget child;

  /// Leaves mouse drags that start on [child] to it, e.g. text selection
  /// or reordering; touch drags too while [keepTouch] says so.
  static Widget keepMouseDrags(Widget child, {bool Function()? keepTouch}) =>
      _KeepMouseDrags(child, keepTouch: keepTouch);

  @override
  State<SwipeToIndent> createState() => _SwipeToIndentState();
}

/// Tells the enclosing swipe that a press it should leave alone landed on
/// [child].
class _KeepMouseDrags extends StatelessWidget {
  const _KeepMouseDrags(this.child, {this.keepTouch});

  final Widget child;
  final bool Function()? keepTouch;

  bool _keeps(PointerDownEvent event) => switch (event.kind) {
    PointerDeviceKind.mouse => true,
    PointerDeviceKind.touch => keepTouch?.call() ?? false,
    _ => false,
  };

  @override
  Widget build(BuildContext context) => Listener(
    // Runs before the enclosing swipe's listener: deeper widgets get
    // pointer events first.
    onPointerDown: (event) {
      if (_keeps(event)) {
        context.findAncestorStateOfType<_SwipeToIndentState>()?._kept =
            event.pointer;
      }
    },
    child: child,
  );
}

class _SwipeToIndentState extends State<SwipeToIndent> {
  Offset? _start;
  Duration _downAt = Duration.zero;

  /// The pointer passed the touch slop in time: the row follows it.
  bool _swiping = false;
  double _dx = 0;

  /// The pointer that went down in a [SwipeToIndent.keepMouseDrags] child
  /// that keeps its drag, if any.
  int? _kept;

  void _onDown(PointerDownEvent event) {
    final kept = event.pointer == _kept;
    _kept = null;
    _start = kept ? null : event.position;
    _downAt = event.timeStamp;
  }

  void _onMove(PointerMoveEvent event) {
    final start = _start;
    if (start == null) return;
    final delta = event.position - start;
    if (!_swiping) {
      // Decided once, when the pointer first moves beyond the slop: held
      // still that long first, it is a long press (e.g. to select text).
      if (delta.distance <= kTouchSlop) return;
      if (event.timeStamp - _downAt > kLongPressTimeout) {
        _reset();
        return;
      }
      _swiping = true;
    }
    // Mostly vertical: a scroll, not a swipe.
    if (delta.dy.abs() > delta.dx.abs() && delta.dy.abs() > kTouchSlop) {
      _reset();
      return;
    }
    setState(() => _dx = delta.dx);
  }

  void _onUp(PointerUpEvent _) {
    if (_dx >= widget.step) widget.onIndent();
    if (_dx <= -widget.step) widget.onOutdent();
    _reset();
  }

  void _reset() {
    _start = null;
    _swiping = false;
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
          _dx.clamp(-widget.step, widget.step),
          0,
          0,
        ),
        child: widget.child,
      ),
    );
  }
}
