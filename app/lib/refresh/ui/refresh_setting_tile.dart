import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../refresh_settings.dart';
import '../refresh_settings_controller.dart';
import 'refresh_dialog.dart';

/// Settings row that shows the refresh setting and opens its dialog.
class RefreshSettingTile extends ConsumerWidget {
  const RefreshSettingTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(refreshSettingsProvider).value;
    return ListTile(
      enabled: settings != null,
      title: const Text('Refresh changes in folders'),
      subtitle: Text(_modeName(settings?.mode)),
      onTap: () => _change(context, ref, settings!),
    );
  }
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
