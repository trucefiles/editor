import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../common/snack.dart';
import '../../settings/device_settings_controller.dart';
import '../start_at_login.dart';

/// Settings row that starts the app in the tray at login, so calendar
/// alerts ring from then on. Nothing where the app has no tray.
class StartAtLoginTile extends ConsumerWidget {
  const StartAtLoginTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final startAtLogin = ref.watch(startAtLoginProvider);
    if (startAtLogin == null) return const SizedBox.shrink();
    final start = ref.watch(
      deviceSettingsProvider.select((s) => s.requireValue.startAtLogin),
    );
    return SwitchListTile(
      title: const Text('Start in tray at login'),
      subtitle: const Text('Calendar alerts ring only while the app runs.'),
      value: start,
      onChanged: (start) async {
        if (!await startAtLogin.set(start: start) && context.mounted) {
          showSnack(context, "The desktop didn't allow it.");
        }
      },
    );
  }
}
