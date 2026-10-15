import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'platform/app_log.dart';
import 'storage/app_storage.dart';
import 'storage/device_id.dart';
import 'theme/font_licenses.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  printLogs();
  registerFontLicenses();
  final storage = await AppStorage.resolve();
  final deviceId = await loadDeviceId(storage);
  runApp(
    ProviderScope(
      overrides: [
        appStorageProvider.overrideWithValue(storage),
        deviceIdProvider.overrideWithValue(deviceId),
      ],
      child: const TruceApp(),
    ),
  );
}
