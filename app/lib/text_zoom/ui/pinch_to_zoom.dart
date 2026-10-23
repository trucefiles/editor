import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import '../text_zoom.dart';

/// Pinching [child] with two fingers, or on a touchpad, asks for text
/// larger or smaller than [zoom] as the fingers spread or close
/// ([onZoom]), step by step while they move. Two fingers on the screen
/// are a pinch: the second finger takes both from what the first started
/// (scrolling, a pull to refresh, swiping an item); one finger reaches
/// [child] as before.
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

  void _begin(ScaleStartDetails _) => _start = _asked = widget.zoom;

  /// A drag of one finger has a scale of 1: it zooms nothing.
  void _update(ScaleUpdateDetails details) {
    final next = TextZoom.closestTo(_start.percent * details.scale);
    if (next == _asked) return;
    _asked = next;
    widget.onZoom(next);
  }

  @override
  Widget build(BuildContext context) => RawGestureDetector(
    gestures: {
      _PinchRecognizer: GestureRecognizerFactoryWithHandlers<_PinchRecognizer>(
        () => _PinchRecognizer(
          supportedDevices: {
            PointerDeviceKind.touch,
            PointerDeviceKind.trackpad,
          },
        ),
        (recognizer) => recognizer
          ..onStart = _begin
          ..onUpdate = _update,
      ),
    },
    child: widget.child,
  );
}

/// A [ScaleGestureRecognizer] that wins as soon as a second finger
/// touches. The built-in one waits until the fingers spread or close by
/// a touch slop, while a scroll or a swipe wins once one finger moves by
/// it, so most pinches started a drag instead.
class _PinchRecognizer extends ScaleGestureRecognizer {
  _PinchRecognizer({super.supportedDevices});

  /// The fingers on the screen this recognizer follows.
  final _fingers = <int>{};

  @override
  void handleEvent(PointerEvent event) {
    super.handleEvent(event);
    switch (event) {
      case PointerDownEvent():
        _fingers.add(event.pointer);
        if (_fingers.length > 1) resolve(GestureDisposition.accepted);
      case PointerUpEvent() || PointerCancelEvent():
        _fingers.remove(event.pointer);
    }
  }

  @override
  void rejectGesture(int pointer) {
    _fingers.remove(pointer);
    super.rejectGesture(pointer);
  }
}
