import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../common/toggle_label.dart';
import '../../platform/platform_wiring.dart';
import '../close_to_tray_controller.dart';

/// Menu entries with the "keep running in tray" setting; none where the
/// platform has no tray.
List<PopupMenuItem<VoidCallback>> closeToTrayMenuItems(WidgetRef ref) {
  final setting = ref.watch(closeToTrayProvider).value;
  if (ref.watch(systemTrayProvider) == null || setting == null) {
    return const [];
  }
  return [
    PopupMenuItem(
      value: () => ref
          .read(closeToTrayProvider.notifier)
          .setEnabled(enabled: !setting.enabled),
      child: ToggleLabel(
        'Keep running in tray',
        on: setting.enabled,
        hint: setting.enabled && !setting.trayVisible
            ? 'No tray on this desktop: closing quits'
            : null,
      ),
    ),
  ];
}
