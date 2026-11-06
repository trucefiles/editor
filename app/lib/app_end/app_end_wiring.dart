import 'dart:ui' show AppExitType;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../files/files_wiring.dart';
import '../platform/platform_wiring.dart';
import 'app_end.dart';

/// How long the app's end waits at most for the open files' edits to
/// reach their files, for an end from outside and for the user's quit
/// alike: a folder that hangs never holds the app. What isn't in its
/// file by then waits on the device for the next start.
const appEndWait = Duration(seconds: 2);

/// The app's end from outside, heard from this platform's sources; kept
/// for as long as the app runs.
final appEndProvider = Provider<AppEnd>((ref) {
  final end = AppEnd(
    keepAll: () =>
        ref.read(openFilesProvider).secureForExit(within: appEndWait),
    quit: () async {
      await ServicesBinding.instance.exitApplication(AppExitType.required);
    },
  );
  final stops = [
    for (final source in ref.watch(appEndSourcesProvider))
      source.listen(end.ended),
  ];
  ref.onDispose(() {
    for (final stop in stops) {
      stop();
    }
  });
  return end;
});
