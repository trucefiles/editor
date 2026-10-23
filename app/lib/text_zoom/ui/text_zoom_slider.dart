import 'package:flutter/material.dart';

import '../text_zoom.dart';

/// The zoom setting's name, wherever it shows: it zooms all text in the
/// app, not only the screen it is changed on.
const textZoomTitle = 'Global text zoom';

/// A slider over the zooms there are, at [zoom]; [onChanged] as it moves.
/// Disabled while [zoom] is unknown.
class TextZoomSlider extends StatelessWidget {
  const TextZoomSlider({
    required this.zoom,
    required this.onChanged,
    this.onChangeStart,
    this.onChangeEnd,
    super.key,
  });

  final TextZoom? zoom;
  final ValueChanged<TextZoom> onChanged;

  /// The user started or stopped moving it.
  final VoidCallback? onChangeStart;
  final VoidCallback? onChangeEnd;

  @override
  Widget build(BuildContext context) => Slider(
    value: (zoom ?? TextZoom.normal).percent.toDouble(),
    min: TextZoom.min.toDouble(),
    max: TextZoom.max.toDouble(),
    divisions: (TextZoom.max - TextZoom.min) ~/ TextZoom.step,
    onChanged: zoom == null
        ? null
        : (percent) => onChanged(TextZoom.closestTo(percent)),
    onChangeStart: (_) => onChangeStart?.call(),
    onChangeEnd: (_) => onChangeEnd?.call(),
  );
}
