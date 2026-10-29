import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../settings/device_settings_controller.dart';
import '../add_item_place.dart';

/// Settings row with where a list's add buttons sit: above its items, or
/// below them.
class AddItemPlaceTile extends ConsumerWidget {
  const AddItemPlaceTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final place = ref.watch(
      deviceSettingsProvider.select((s) => s.requireValue.addItemPlace),
    );
    return SwitchListTile(
      title: const Text('Show "Add item" below lists'),
      subtitle: const Text('Off: above each list'),
      value: place == AddItemPlace.bottom,
      onChanged: (bottom) => ref
          .read(deviceSettingsProvider.notifier)
          .change(
            (settings) => settings.copyWith(
              addItemPlace: bottom ? AddItemPlace.bottom : AddItemPlace.top,
            ),
          ),
    );
  }
}
