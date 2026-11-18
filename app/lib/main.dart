import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'platform/app_log.dart';
import 'storage/app_start.dart';
import 'theme/font_licenses.dart';
import 'tray/start_in_background.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  printLogs();
  registerFontLicenses();
  runApp(
    ProviderScope(
      overrides: [
        ...await loadAppStart(),
        startInBackgroundProvider.overrideWithValue(
          args.contains(backgroundFlag),
        ),
      ],
      child: const TruceApp(),
    ),
  );
}
