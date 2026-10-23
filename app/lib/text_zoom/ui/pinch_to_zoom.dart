import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import '../text_zoom.dart';

/// Pinching [child] with two fingers asks for text larger or smaller than
/// [zoom] as the fingers spread or close ([onZoom]), step by step while
/// they move. A pinch is a gesture of its own: once the fingers spread or
/// close, it takes them from what else they started (scrolling, a pull to
/// refresh, dragging); until then every touch reaches [child] as before.
class PinchToZoom extends StatefulWidget {
  const PinchToZoom({
    required this.zoom,
    required this.onZoom,
    required this.child,
    super.key,
  });

  final TextZoom zoom;
  final ValueChanged<TextZoom> onZoom;
  final Widget child;

  @override
  State<PinchToZoom> createState() => _PinchToZoomState();
}

class _PinchToZoomState extends State<PinchToZoom> {
  /// The zoom the pinch going on started at, and the last it asked for.
  TextZoom _start = TextZoom.normal;
  TextZoom _asked = TextZoom.normal;

  void _begin() => _start = _asked = widget.zoom;

  void _update(double spread) {
    final next = TextZoom.closestTo(_start.percent * spread);
    if (next == _asked) return;
    _asked = next;
    widget.onZoom(next);
  }

  @override
  Widget build(BuildContext context) => RawGestureDetector(
    gestures: {
      PinchGestureRecognizer:
          GestureRecognizerFactoryWithHandlers<PinchGestureRecognizer>(
            PinchGestureRecognizer.new,
            (recognizer) => recognizer
              ..onStart = _begin
              ..onUpdate = _update,
          ),
    },
    child: widget.child,
  );
}

/// Recognizes two fingers spreading or closing on a touchscreen. It
/// claims both fingers in the gesture arena once their distance changed
/// by the scale slop, before a drag of either one is decided; a pinch
/// starts only if it gets both, and then reports how many times their
/// distance at the start they are apart ([onUpdate]).
class PinchGestureRecognizer extends OneSequenceGestureRecognizer {
  PinchGestureRecognizer({super.debugOwner})
    : super(supportedDevices: {PointerDeviceKind.touch});

  /// A pinch started.
  VoidCallback? onStart;

  /// The fingers are this many times their distance at the start apart.
  ValueChanged<double>? onUpdate;

  /// Where each of the (at most two) fingers is.
  final _fingers = <int, Offset>{};

  /// The fingers the arena gave this recognizer.
  final _won = <int>{};

  /// The fingers' distance when the second came down, or when the pinch
  /// started.
  double? _startSpan;

  bool get _pinching => _won.length == 2;

  double get _span {
    final [a, b] = _fingers.values.toList();
    return (a - b).distance;
  }

  @override
  bool isPointerAllowed(PointerDownEvent event) =>
      _fingers.length < 2 && super.isPointerAllowed(event);

  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    _fingers[event.pointer] = event.position;
    if (_fingers.length == 2) _startSpan = _span;
  }

  @override
  void handleEvent(PointerEvent event) {
    switch (event) {
      case PointerMoveEvent(:final pointer, :final position):
        _fingers[pointer] = position;
        _moved(event.kind);
      case PointerUpEvent(:final pointer) || PointerCancelEvent(:final pointer):
        if (!_pinching) resolvePointer(pointer, GestureDisposition.rejected);
        _drop(pointer);
      case _:
    }
  }

  void _moved(PointerDeviceKind kind) {
    final start = _startSpan;
    if (start == null || start == 0) return;
    if (_pinching) {
      onUpdate?.call(_span / start);
    } else if ((_span - start).abs() > computeScaleSlop(kind)) {
      resolve(GestureDisposition.accepted);
    }
  }

  @override
  void acceptGesture(int pointer) {
    _won.add(pointer);
    if (!_pinching) return;
    // Spreads from here, not from where the fingers came down.
    _startSpan = _span;
    onStart?.call();
  }

  @override
  void rejectGesture(int pointer) => _drop(pointer);

  /// Stops following [pointer]: a pinch needs two fingers again.
  void _drop(int pointer) {
    _fingers.remove(pointer);
    _won.remove(pointer);
    _startSpan = null;
    stopTrackingPointer(pointer);
  }

  @override
  void didStopTrackingLastPointer(int pointer) {
    _fingers.clear();
    _won.clear();
    _startSpan = null;
  }

  @override
  String get debugDescription => 'pinch';
}
