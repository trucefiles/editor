import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'device_settings.dart';
import 'device_settings_controller.dart';

/// The device setting [pick] reads, as it is now: followed by the provider
/// that calls this, so units below providers read it at their own time
/// without holding a `Ref`. Until the settings are there, the standard
/// value.
T Function() followedSetting<T>(Ref ref, T Function(DeviceSettings) pick) {
  var now = pick(DeviceSettings.standard);
  ref.listen(
    deviceSettingsProvider.select(
      (s) => switch (s.value) {
        final settings? => pick(settings),
        null => null,
      },
    ),
    (_, picked) => now = picked ?? now,
    fireImmediately: true,
  );
  return () => now;
}
