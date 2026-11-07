import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../common/choice_dialog.dart';
import '../../settings/device_settings_controller.dart';

/// Settings row with where a file's location and name picker sits: at the
/// top of its page, or in its menu; tapping it asks for the other place.
class PlaceAboveTextTile extends ConsumerWidget {
  const PlaceAboveTextTile({super.key});

  static const _title = 'File location and name picker';

  static String _label(bool above) =>
      above ? 'At the top of the page' : "In the file's menu";

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final above = ref.watch(
      deviceSettingsProvider.select((s) => s.requireValue.placeAboveText),
    );
    return ListTile(
      title: const Text(_title),
      subtitle: Text(_label(above)),
      onTap: () async {
        final chosen = await showChoiceDialog(
          context,
          title: _title,
          choices: const [true, false],
          labelOf: _label,
          current: above,
        );
        if (chosen case (final above,)) {
          await ref
              .read(deviceSettingsProvider.notifier)
              .change((settings) => settings.copyWith(placeAboveText: above));
        }
      },
    );
  }
}
