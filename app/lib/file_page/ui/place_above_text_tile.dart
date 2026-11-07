import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../settings/device_settings_controller.dart';

/// Settings row with whether a file's location shows above its text, or
/// only in the file's menu.
class PlaceAboveTextTile extends ConsumerWidget {
  const PlaceAboveTextTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => SwitchListTile(
    title: const Text('Show location above the text'),
    subtitle: const Text("Off: it's in the file's menu"),
    value: ref.watch(
      deviceSettingsProvider.select((s) => s.requireValue.placeAboveText),
    ),
    onChanged: (above) => ref
        .read(deviceSettingsProvider.notifier)
        .change((settings) => settings.copyWith(placeAboveText: above)),
  );
}
