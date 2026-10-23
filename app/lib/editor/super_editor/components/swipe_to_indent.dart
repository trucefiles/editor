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
/// selection). A swipe is one finger: a second one on the row ends it,
/// e.g. a pinch.
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
    // pointer events first. Hit anywhere on the child: text may not take
    // hits itself.
    behavior: HitTestBehavior.translucent,
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
  /// The pointer that may swipe, if one is down.
  int? _pointer;
  Offset? _start;
  Duration _downAt = Duration.zero;

  /// The pointer passed the touch slop in time: the row follows it.
  bool _swiping = false;
  double _dx = 0;

  /// The mouse pointer that went down in a [SwipeToIndent.keepMouseDrags]
  /// child, if any.
  int? _kept;

  void _onDown(PointerDownEvent event) {
    if (_pointer != null) {
      _reset();
      return;
    }
    final kept = event.pointer == _kept;
    _kept = null;
    _pointer = event.pointer;
    _start = kept ? null : event.position;
    _downAt = event.timeStamp;
  }

  void _onMove(PointerMoveEvent event) {
    final start = _start;
    if (start == null || event.pointer != _pointer) return;
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

  void _onUp(PointerUpEvent event) {
    if (event.pointer != _pointer) return;
    _pointer = null;
    if (_dx >= widget.step) widget.onIndent();
    if (_dx <= -widget.step) widget.onOutdent();
    _reset();
  }

  void _onCancel(PointerCancelEvent event) {
    if (event.pointer != _pointer) return;
    _pointer = null;
    _reset();
  }

  /// Ends the swipe; the row slides back.
  void _reset() {
    _start = null;
    _swiping = false;
    if (_dx != 0) setState(() => _dx = 0);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      // Hit anywhere on the row: text may not take hits itself.
      behavior: HitTestBehavior.translucent,
      onPointerDown: _onDown,
      onPointerMove: _onMove,
      onPointerUp: _onUp,
      onPointerCancel: _onCancel,
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
