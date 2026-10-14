import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../common/toggle_label.dart';
import '../close_to_tray_controller.dart';
import '../tray_wiring.dart';

/// App bar menu with the "keep running in tray" setting; nothing where the
/// platform has no tray.
class CloseToTrayMenu extends ConsumerWidget {
  const CloseToTrayMenu({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final setting = ref.watch(closeToTrayProvider).value;
    if (ref.watch(systemTrayProvider) == null || setting == null) {
      return const SizedBox.shrink();
    }
    return PopupMenuButton<bool>(
      onSelected: (enabled) =>
          ref.read(closeToTrayProvider.notifier).setEnabled(enabled: enabled),
      itemBuilder: (_) => [
        PopupMenuItem(
          value: !setting.enabled,
          child: ToggleLabel(
            'Keep running in tray',
            on: setting.enabled,
            hint: setting.enabled && !setting.trayVisible
                ? 'No tray on this desktop: closing quits'
                : null,
          ),
        ),
      ],
    );
  }
}
