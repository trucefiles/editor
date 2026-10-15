import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../refresh_settings.dart';
import '../refresh_settings_controller.dart';
import 'refresh_dialog.dart';

/// Menu entry that shows the refresh setting and opens its dialog.
PopupMenuItem<VoidCallback> refreshMenuItem(
  BuildContext context,
  WidgetRef ref,
) {
  final settings = ref.watch(refreshSettingsProvider).value;
  return PopupMenuItem(
    enabled: settings != null,
    value: () => _change(context, ref, settings!),
    child: Text('Refresh: ${_modeName(settings?.mode)}'),
  );
}

Future<void> _change(
  BuildContext context,
  WidgetRef ref,
  RefreshSettings current,
) async {
  final chosen = await showRefreshDialog(
    context,
    current: current,
    liveAvailable: ref.read(liveRefreshAvailableProvider),
  );
  if (chosen != null && chosen != current) {
    await ref.read(refreshSettingsProvider.notifier).set(chosen);
  }
}

String _modeName(RefreshMode? mode) => switch (mode) {
  RefreshMode.live => 'Live',
  RefreshMode.periodic => 'Periodic',
  RefreshMode.manual => 'Manual',
  null => '…',
};
