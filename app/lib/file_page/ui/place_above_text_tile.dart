import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../common/choice_tile.dart';
import '../../settings/device_settings_controller.dart';

/// Settings row with where a file's location and name picker sits: at the
/// top of its page, or in its menu.
class PlaceAboveTextTile extends ConsumerWidget {
  const PlaceAboveTextTile({super.key});

  static String _label(bool above) =>
      above ? 'At the top of the page' : "In the file's menu";

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final above = ref.watch(
      deviceSettingsProvider.select((s) => s.requireValue.placeAboveText),
    );
    return ChoiceTile(
      title: 'File location and name picker',
      subtitle: _label(above),
      choices: const [true, false],
      labelOf: _label,
      current: above,
      onChosen: (above) => ref
          .read(deviceSettingsProvider.notifier)
          .change((settings) => settings.copyWith(placeAboveText: above)),
    );
  }
}
