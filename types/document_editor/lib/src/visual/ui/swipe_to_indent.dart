import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Lets the user swipe [child] right to indent or left to outdent, by
/// touch or mouse. The child follows the pointer by up to one [step], the
/// width of one indent level; a swipe that reaches it acts on release.
/// Where the item moved, its new indent takes the slide's place in the
/// same frame; else the child slides back.
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

  /// Indents the item; whether it moved.
  final bool Function() onIndent;

  /// Outdents the item; whether it moved.
  final bool Function() onOutdent;
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

  /// How long the child takes to its place once [_dx] changed: none while
  /// it follows the pointer or once the item moved to where it shows.
  Duration _back = Duration.zero;

  /// The mouse pointer that went down in a [SwipeToIndent.keepMouseDrags]
  /// child, if any.
  int? _kept;

  bool _allows(PointerDownEvent event) {
    final kept = event.pointer == _kept;
    _kept = null;
    return !kept;
  }

  void _follow(DragUpdateDetails details) => setState(() {
    _dx += details.primaryDelta!;
    _back = Duration.zero;
  });

  void _end(DragEndDetails _) {
    final moved = switch (_dx) {
      final dx when dx >= widget.step => widget.onIndent(),
      final dx when dx <= -widget.step => widget.onOutdent(),
      _ => false,
    };
    _settle(slides: !moved);
  }

  /// The child goes back to no offset: sliding, or at once where its row
  /// lands at the new indent in this frame.
  void _settle({required bool slides}) => setState(() {
    _dx = 0;
    _back = slides ? const Duration(milliseconds: 150) : Duration.zero;
  });

  void _slideBack() => _settle(slides: true);

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
      duration: _back,
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
