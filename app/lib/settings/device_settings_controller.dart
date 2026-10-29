import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';

import '../storage/app_storage.dart';
import 'device_settings.dart';
import 'device_settings_store.dart';
import 'setting_controller.dart';

/// The file of the [DeviceSettings] in [storage].
DeviceSettingsStore deviceSettingsStoreIn(AppStorage storage) =>
    DeviceSettingsStore(File('${storage.settingsPath}/device_settings.json'));

final deviceSettingsStoreProvider = Provider<SettingStore<DeviceSettings>>(
  (ref) => deviceSettingsStoreIn(ref.watch(appStorageProvider)),
);

/// The settings as `main` loads them before the first frame, so text never
/// shows at another size first. Set in `main`.
final loadedDeviceSettingsProvider = Provider<DeviceSettings>(
  (ref) =>
      throw UnimplementedError('loadedDeviceSettingsProvider is set in main'),
);

final deviceSettingsProvider =
    AsyncNotifierProvider<DeviceSettingsController, DeviceSettings>(
      DeviceSettingsController.new,
    );

/// The settings of this device. Always loaded: it starts from what `main`
/// loaded, so its value is there from the first frame on.
class DeviceSettingsController extends SettingController<DeviceSettings> {
  @override
  Provider<SettingStore<DeviceSettings>> get store =>
      deviceSettingsStoreProvider;

  @override
  FutureOr<DeviceSettings> initial() => ref.watch(loadedDeviceSettingsProvider);
}
