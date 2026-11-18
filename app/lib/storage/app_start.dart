import 'dart:io';

import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:intl/date_symbol_data_local.dart';
import 'package:truce_core/truce_core.dart';

import '../settings/device_settings_controller.dart';
import 'app_storage.dart';

/// What every start of the app's wiring loads first, with the screens or
/// without (the background check): app storage, this device's id and its
/// settings, and the date formats; as the overrides of the providers
/// that hold them.
Future<List<Override>> loadAppStart() async {
  await initializeDateFormatting();
  final storage = await AppStorage.resolve();
  // One store for the file, so its writes stay one at a time.
  final settingsStore = deviceSettingsStoreIn(storage);
  final (deviceId, settings) = await (
    loadDeviceId(File(storage.deviceIdPath)),
    settingsStore.load(),
  ).wait;
  return [
    appStorageProvider.overrideWithValue(storage),
    deviceIdProvider.overrideWithValue(deviceId),
    deviceSettingsStoreProvider.overrideWithValue(settingsStore),
    loadedDeviceSettingsProvider.overrideWithValue(settings),
  ];
}
