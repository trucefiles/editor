import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../settings/device_settings_controller.dart';
import '../text_zoom.dart';
import '../text_zoom_target.dart';
import 'text_zoom_title.dart';

/// Settings row with how large the text of [target] shows: a slider over
/// the zooms there are.
class TextZoomTile extends ConsumerWidget {
  const TextZoomTile(this.target, {super.key});

  final TextZoomTarget target;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zoom = ref.watch(
      deviceSettingsProvider.select((s) => s.requireValue.textZoomOf(target)),
    );
    return ListTile(
      title: Text(textZoomTitle(target)),
      trailing: Text('$zoom'),
      subtitle: Slider(
        value: zoom.percent.toDouble(),
        min: TextZoom.min.toDouble(),
        max: TextZoom.max.toDouble(),
        divisions: (TextZoom.max - TextZoom.min) ~/ TextZoom.step,
        onChanged: (percent) => ref
            .read(deviceSettingsProvider.notifier)
            .change(
              (settings) =>
                  settings.withTextZoom(target, TextZoom.closestTo(percent)),
            ),
      ),
    );
  }
}
