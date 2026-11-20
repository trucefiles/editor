import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_images/truce_images.dart';

import '../../settings/device_settings_controller.dart';

/// Settings rows for pictures the user adds, to a document or as a file
/// of their own: take out where a photo was taken, and make large ones
/// smaller.
class ImageSettingTiles extends ConsumerWidget {
  const ImageSettingTiles({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final images = ref.watch(
      deviceSettingsProvider.select((s) => s.requireValue.images),
    );
    void change(ImageSettings Function(ImageSettings images) change) => ref
        .read(deviceSettingsProvider.notifier)
        .change((settings) => settings.copyWith(images: change(images)));
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SwitchListTile(
          title: const Text('Remove location from photos'),
          subtitle: const Text('When you add one'),
          value: images.removeLocation,
          onChanged: (remove) =>
              change((images) => images.copyWith(removeLocation: remove)),
        ),
        SwitchListTile(
          title: const Text('Make large images smaller'),
          subtitle: const Text(
            'When you add one: about ${ImageSettings.longestSide} pixels on '
            'the longest side',
          ),
          value: images.makeSmaller,
          onChanged: (smaller) =>
              change((images) => images.copyWith(makeSmaller: smaller)),
        ),
      ],
    );
  }
}
