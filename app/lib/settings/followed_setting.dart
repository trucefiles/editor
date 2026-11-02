import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'device_settings.dart';
import 'device_settings_controller.dart';

/// The device setting [pick] reads, kept current by the provider that
/// calls this, so units below providers read or follow it without holding
/// a `Ref`. Until the settings are there, the standard value.
ValueListenable<T> followedSetting<T>(
  Ref ref,
  T Function(DeviceSettings) pick,
) {
  final setting = ValueNotifier(pick(DeviceSettings.standard));
  ref
    ..listen(
      deviceSettingsProvider.select(
        (s) => switch (s.value) {
          final settings? => pick(settings),
          null => null,
        },
      ),
      (_, picked) => setting.value = picked ?? setting.value,
      fireImmediately: true,
    )
    ..onDispose(setting.dispose);
  return setting;
}
