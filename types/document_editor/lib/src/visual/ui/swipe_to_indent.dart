import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Lets the user swipe [child] right to indent or left to outdent, by
/// touch or mouse. The child follows the pointer by up to one [step], the
/// width of one indent level; a swipe that reaches it acts on release.
/// The child slides back either way.
///
/// A horizontal drag in the gesture arena: the gesture that claims the
/// pointer first wins, so a scroll, a pinch or a long press that selects
/// text takes it from the swipe, and a swipe that starts on the item's
/// text still counts. A mouse drag that starts inside
/// [SwipeToIndent.keepMouseDrags] is left alone, e.g. to select text.
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
  /// How far the pointer moved sideways since the swipe started.
  double _dx = 0;

  /// The mouse pointer that went down in a [SwipeToIndent.keepMouseDrags]
  /// child, if any.
  int? _kept;

  bool _allows(PointerDownEvent event) {
    final kept = event.pointer == _kept;
    _kept = null;
    return !kept;
  }

  void _follow(DragUpdateDetails details) =>
      setState(() => _dx += details.primaryDelta!);

  void _end(DragEndDetails _) {
    if (_dx >= widget.step) widget.onIndent();
    if (_dx <= -widget.step) widget.onOutdent();
    _slideBack();
  }

  void _slideBack() => setState(() => _dx = 0);

  @override
  Widget build(BuildContext context) => RawGestureDetector(
    // Hit anywhere on the row: text may not take hits itself.
    behavior: HitTestBehavior.translucent,
    gestures: {
      _SwipeRecognizer: GestureRecognizerFactoryWithHandlers<_SwipeRecognizer>(
        () => _SwipeRecognizer(_allows),
        (recognizer) => recognizer
          ..onUpdate = _follow
          ..onEnd = _end
          ..onCancel = _slideBack,
      ),
    },
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

/// A horizontal drag of the pointers [allows] lets it follow.
class _SwipeRecognizer extends HorizontalDragGestureRecognizer {
  _SwipeRecognizer(this.allows);

  final bool Function(PointerDownEvent event) allows;

  @override
  bool isPointerAllowed(PointerEvent event) =>
      (event is! PointerDownEvent || allows(event)) &&
      super.isPointerAllowed(event);
}
