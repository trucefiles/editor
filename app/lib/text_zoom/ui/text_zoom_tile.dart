import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../text_zoom.dart';
import '../text_zoom_controller.dart';
import 'text_zoom_title.dart';

/// Settings row with how large all text in the app shows: a slider over
/// the zooms there are.
class TextZoomTile extends ConsumerWidget {
  const TextZoomTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zoom = ref.watch(textZoomProvider).value;
    return ListTile(
      title: const Text(textZoomTitle),
      trailing: Text(zoom?.toString() ?? ''),
      subtitle: Slider(
        value: (zoom ?? TextZoom.normal).percent.toDouble(),
        min: TextZoom.min.toDouble(),
        max: TextZoom.max.toDouble(),
        divisions: (TextZoom.max - TextZoom.min) ~/ TextZoom.step,
        onChanged: zoom == null
            ? null
            : (percent) => ref
                  .read(textZoomProvider.notifier)
                  .set(TextZoom.closestTo(percent)),
      ),
    );
  }
}
