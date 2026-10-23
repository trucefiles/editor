import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import '../text_zoom.dart';

/// Pinching [child] with two fingers, or on a touchpad, asks for text
/// larger or smaller than [zoom] as the fingers spread or close
/// ([onZoom]), step by step while they move. A pinch is a gesture of its
/// own: once the fingers spread or close, it takes them from what else
/// they started (scrolling, a pull to refresh, swiping an item); until
/// then every touch reaches [child] as before.
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
      ScaleGestureRecognizer:
          GestureRecognizerFactoryWithHandlers<ScaleGestureRecognizer>(
            () => ScaleGestureRecognizer(
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
