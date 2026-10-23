import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'platform/app_log.dart';
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
  final deviceId = await loadDeviceId(storage);
  runApp(
    ProviderScope(
      overrides: [
        appStorageProvider.overrideWithValue(storage),
        deviceIdProvider.overrideWithValue(deviceId),
        startInBackgroundProvider.overrideWithValue(
          args.contains(backgroundFlag),
        ),
      ],
      child: const TruceApp(),
    ),
  );
}
