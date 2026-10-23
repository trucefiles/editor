import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../text_zoom_controller.dart';
import 'text_zoom_slider.dart';

/// Settings row with how large all text in the app shows.
class TextZoomTile extends ConsumerWidget {
  const TextZoomTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zoom = ref.watch(textZoomProvider).value;
    return ListTile(
      title: const Text(textZoomTitle),
      trailing: Text(zoom?.toString() ?? ''),
      subtitle: TextZoomSlider(
        zoom: zoom,
        onChanged: ref.read(textZoomProvider.notifier).set,
      ),
    );
  }
}
