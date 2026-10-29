import 'dart:io';

import 'package:truce_core/truce_core.dart';

import 'device_settings.dart';

/// Keeps the [DeviceSettings] in one JSON file in app storage.
final class DeviceSettingsStore implements SettingStore<DeviceSettings> {
  DeviceSettingsStore(File file) : _file = JsonFile(file);

  final JsonFile _file;

  /// The saved settings; [DeviceSettings.standard] if none or unreadable.
  @override
  Future<DeviceSettings> load() async => switch (await _file.read()) {
    Ok(:final value) => DeviceSettings.fromJson(value),
    Err() => DeviceSettings.standard,
  };

  /// Replaces the saved settings; on failure they stay as they are for
  /// this run.
  @override
  Future<void> save(DeviceSettings settings) => _file.write(settings.toJson());
}
