import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'platform/app_log.dart';
import 'settings/device_settings_controller.dart';
import 'storage/app_storage.dart';
import 'storage/device_id.dart';
import 'theme/font_licenses.dart';
import 'tray/start_in_background.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  printLogs();
  registerFontLicenses();
  await initializeDateFormatting();
  final storage = await AppStorage.resolve();
  // One store for the file, so its writes stay one at a time.
  final settingsStore = deviceSettingsStoreIn(storage);
  final (deviceId, settings) = await (
    loadDeviceId(storage),
    settingsStore.load(),
  ).wait;
  runApp(
    ProviderScope(
      overrides: [
        appStorageProvider.overrideWithValue(storage),
        deviceIdProvider.overrideWithValue(deviceId),
        deviceSettingsStoreProvider.overrideWithValue(settingsStore),
        loadedDeviceSettingsProvider.overrideWithValue(settings),
        startInBackgroundProvider.overrideWithValue(
          args.contains(backgroundFlag),
        ),
      ],
      child: const TruceApp(),
    ),
  );
}
