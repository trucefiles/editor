import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../common/choice_tile.dart';
import '../../platform/platform_wiring.dart';
import '../../settings/device_settings_controller.dart';
import '../alert_style.dart';

/// Whether alerts may show now; asked again when the settings open.
final _mayNotifyProvider = FutureProvider.autoDispose<bool>(
  (ref) => ref.watch(alertPermissionsProvider).mayNotify(),
);

/// Settings rows with how calendar alerts ring on this device, and a line
/// to let them show while notifications are off; nothing where alerts
/// ring only one way.
class AlertStyleTile extends ConsumerWidget {
  const AlertStyleTile({super.key});

  static String _label(AlertStyle style) => switch (style) {
    AlertStyle.notification => 'Notification',
    AlertStyle.alarm => 'Alarm',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(choosesAlertStyleProvider)) return const SizedBox.shrink();
    final style = ref.watch(
      deviceSettingsProvider.select((s) => s.requireValue.alertStyle),
    );
    final permissions = ref.watch(alertPermissionsProvider);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ChoiceTile(
          title: 'Calendar alerts ring as',
          subtitle: _label(style),
          choices: AlertStyle.values,
          labelOf: _label,
          current: style,
          note: 'An alarm rings full screen until you stop it.',
          onChosen: (style) async {
            await ref
                .read(deviceSettingsProvider.notifier)
                .change((settings) => settings.copyWith(alertStyle: style));
            if (style == AlertStyle.alarm) {
              await permissions.askForFullScreen();
            }
          },
        ),
        if (ref.watch(_mayNotifyProvider).value == false)
          ListTile(
            title: const Text('Alerts are silent'),
            subtitle: const Text(
              'Notifications are off for this app. Tap to allow them.',
            ),
            onTap: () async {
              await permissions.askToNotify();
              ref.invalidate(_mayNotifyProvider);
            },
          ),
      ],
    );
  }
}
