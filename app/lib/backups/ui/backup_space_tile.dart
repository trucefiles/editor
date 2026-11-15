import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_files/truce_files.dart';

import '../../common/choice_tile.dart';
import '../../settings/device_settings_controller.dart';

/// Settings row with how much space backups may take on this device.
class BackupSpaceTile extends ConsumerWidget {
  const BackupSpaceTile({super.key});

  static String _label(BackupSpace space) => switch (space.megabytes) {
    final megabytes? => '$megabytes MB',
    null => 'No limit',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final space = ref.watch(
      deviceSettingsProvider.select((s) => s.requireValue.backupSpace),
    );
    return ChoiceTile(
      title: 'Backup space',
      subtitle: _label(space),
      choices: BackupSpace.values,
      labelOf: _label,
      current: space,
      onChosen: (space) => ref
          .read(deviceSettingsProvider.notifier)
          .change((settings) => settings.copyWith(backupSpace: space)),
    );
  }
}
