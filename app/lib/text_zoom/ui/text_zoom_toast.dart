import 'package:flutter/material.dart';

import '../text_zoom.dart';
import 'text_zoom_slider.dart';

/// A small panel naming the zoom ([textZoomTitle]) with a slider at
/// [zoom] and its percent, so a zoom by a gesture or keys tells what it
/// changed; the slider moves it further ([onZoom]) and tells when the
/// user holds it ([onSliding]).
class TextZoomToast extends StatelessWidget {
  const TextZoomToast({
    required this.zoom,
    required this.onZoom,
    required this.onSliding,
    super.key,
  });

  final TextZoom zoom;
  final ValueChanged<TextZoom> onZoom;
  final ValueChanged<bool> onSliding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.inverseSurface,
      elevation: 6,
      borderRadius: BorderRadius.circular(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(20, 12, 20, 4),
          child: DefaultTextStyle(
            style: theme.textTheme.titleSmall!.copyWith(
              color: theme.colorScheme.onInverseSurface,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [const Text(textZoomTitle), Text('$zoom')],
                ),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: theme.colorScheme.inversePrimary,
                    thumbColor: theme.colorScheme.inversePrimary,
                  ),
                  child: TextZoomSlider(
                    zoom: zoom,
                    onChanged: onZoom,
                    onChangeStart: () => onSliding(true),
                    onChangeEnd: () => onSliding(false),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
