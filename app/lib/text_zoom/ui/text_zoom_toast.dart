import 'package:flutter/material.dart';

import '../text_zoom.dart';

/// A small panel naming the zoom ([title]) with [zoom] as percent
/// and as a bar from the smallest zoom to the largest, so a zoom by a
/// gesture or keys tells what it changed. Only shows: it takes no taps.
class TextZoomToast extends StatelessWidget {
  const TextZoomToast({required this.title, required this.zoom, super.key});

  final String title;
  final TextZoom zoom;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    // Read out when it shows or changes.
    return Semantics(
      liveRegion: true,
      child: IgnorePointer(
        child: Material(
          color: colors.inverseSurface,
          elevation: 6,
          borderRadius: BorderRadius.circular(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: DefaultTextStyle(
                style: theme.textTheme.titleSmall!.copyWith(
                  color: colors.onInverseSurface,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 12,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [Text(title), Text('$zoom')],
                    ),
                    LinearProgressIndicator(
                      value:
                          (zoom.percent - TextZoom.min) /
                          (TextZoom.max - TextZoom.min),
                      color: colors.inversePrimary,
                      backgroundColor: colors.onInverseSurface.withValues(
                        alpha: 0.3,
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
