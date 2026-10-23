import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import '../note_text_size.dart';

/// Pinching [child] with two fingers asks for notes' text larger or
/// smaller than [size] as the fingers spread or close ([onSize]), step by
/// step while they move. Every touch still reaches [child] as well, so it
/// scrolls and edits as before.
class PinchToZoom extends StatefulWidget {
  const PinchToZoom({
    required this.size,
    required this.onSize,
    required this.child,
    super.key,
  });

  final NoteTextSize size;
  final ValueChanged<NoteTextSize> onSize;
  final Widget child;

  @override
  State<PinchToZoom> createState() => _PinchToZoomState();
}

class _PinchToZoomState extends State<PinchToZoom> {
  /// Where each finger on [PinchToZoom.child] is.
  final _fingers = <int, Offset>{};

  /// The pinch going on: the size and the fingers' distance it started
  /// at.
  ({NoteTextSize size, double span})? _pinch;

  double get _span {
    final [a, b] = _fingers.values.toList();
    return (a - b).distance;
  }

  void _down(PointerDownEvent event) {
    if (event.kind != PointerDeviceKind.touch) return;
    _fingers[event.pointer] = event.position;
    _pinch = _fingers.length == 2 && _span > 0
        ? (size: widget.size, span: _span)
        : null;
  }

  void _move(PointerMoveEvent event) {
    if (!_fingers.containsKey(event.pointer)) return;
    _fingers[event.pointer] = event.position;
    if (_pinch case (:final size, :final span)?) {
      final next = NoteTextSize.closestTo(size.percent * _span / span);
      if (next != widget.size) widget.onSize(next);
    }
  }

  void _up(PointerEvent event) {
    _fingers.remove(event.pointer);
    _pinch = null;
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: _down,
    onPointerMove: _move,
    onPointerUp: _up,
    onPointerCancel: _up,
    child: widget.child,
  );
}
