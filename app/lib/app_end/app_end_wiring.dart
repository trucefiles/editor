import 'dart:ui' show AppExitResponse, AppExitType;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../files/files_wiring.dart';
import '../platform/platform_wiring.dart';
import 'app_end.dart';

/// The app's end, heard from this platform's sources and from the user's
/// quit; kept for as long as the app runs.
final appEndProvider = Provider<AppEnd>((ref) {
  final end = AppEnd(
    keepAll: ref.watch(openFilesProvider).secureForExit,
    quit: () async {
      await ServicesBinding.instance.exitApplication(AppExitType.required);
    },
  );
  final stops = [
    for (final source in ref.watch(appEndSourcesProvider))
      source.listen(end.ended),
  ];
  // The user quits: the open pages ask what they must first.
  final quit = AppLifecycleListener(
    onExitRequested: () async {
      await end.keep();
      return AppExitResponse.exit;
    },
  );
  ref.onDispose(() {
    quit.dispose();
    for (final stop in stops) {
      stop();
    }
  });
  return end;
});
