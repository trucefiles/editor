import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_document_editor/truce_document_editor.dart';

import '../../common/choice_tile.dart';
import '../device_settings_controller.dart';

/// Settings row with where a list's "Add item" button sits: at the top of
/// the list, or at its bottom.
class AddItemPlaceTile extends ConsumerWidget {
  const AddItemPlaceTile({super.key});

  static String _label(AddItemPlace place) => switch (place) {
    AddItemPlace.top => 'At the top of each list',
    AddItemPlace.bottom => 'At the bottom of each list',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final place = ref.watch(
      deviceSettingsProvider.select((s) => s.requireValue.addItemPlace),
    );
    return ChoiceTile(
      title: 'Add item button',
      subtitle: _label(place),
      choices: AddItemPlace.values,
      labelOf: _label,
      current: place,
      onChosen: (place) => ref
          .read(deviceSettingsProvider.notifier)
          .change((settings) => settings.copyWith(addItemPlace: place)),
    );
  }
}
