import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';

import '../add_item_place_controller.dart';

/// Settings row with where a list's add buttons sit: above its items, or
/// below them.
class AddItemPlaceTile extends ConsumerWidget {
  const AddItemPlaceTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final place = ref.watch(addItemPlaceProvider).value;
    return SwitchListTile(
      title: const Text('Add buttons below lists'),
      subtitle: const Text('Off: above each list'),
      value: place == AddItemPlace.bottom,
      onChanged: place == null
          ? null
          : (bottom) => ref
                .read(addItemPlaceProvider.notifier)
                .set(bottom ? AddItemPlace.bottom : AddItemPlace.top),
    );
  }
}
