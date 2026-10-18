import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../platform/platform_wiring.dart';
import '../close_to_tray_controller.dart';

/// Settings row with the "keep running in tray" setting; nothing where the
/// platform has no tray.
class CloseToTrayTile extends ConsumerWidget {
  const CloseToTrayTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final setting = ref.watch(closeToTrayProvider).value;
    if (ref.watch(systemTrayProvider) == null || setting == null) {
      return const SizedBox.shrink();
    }
    return SwitchListTile(
      title: const Text('Keep running in tray'),
      subtitle: setting.enabled && !setting.trayVisible
          ? const Text('No tray on this desktop: closing quits')
          : null,
      value: setting.enabled,
      onChanged: (enabled) =>
          ref.read(closeToTrayProvider.notifier).setEnabled(enabled: enabled),
    );
  }
}
