import 'dart:ui' show AppExitResponse, AppExitType;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show AppLifecycleListener;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../alerts/alerts_wiring.dart';
import '../files/files_wiring.dart';
import '../platform/platform_wiring.dart';
import 'app_end.dart';

/// How long the app's end waits at most for the open files' edits to
/// reach their files, for an end from outside and for the user's quit
/// alike: a folder that hangs never holds the app. What isn't in its
/// file by then waits on the device for the next start.
const appEndWait = Duration(seconds: 2);

/// What the app keeps before it quits, however it ends: the alerts' stop
/// (alerts until now weren't missed), within [appEndWait].
Future<void> _keepAlertsStop(Ref ref) =>
    ref.read(alertsProvider).stopping().timeout(appEndWait, onTimeout: () {});

/// The app's end, kept for as long as the app runs: from outside, heard
/// from this platform's sources, the open files' edits and the alerts'
/// stop are kept before it quits; at the user's own quit the alerts' stop
/// is kept (the open pages keep their files').
final appEndProvider = Provider<AppEnd>((ref) {
  final userQuit = AppLifecycleListener(
    onExitRequested: () async {
      await _keepAlertsStop(ref);
      return AppExitResponse.exit;
    },
  );
  ref.onDispose(userQuit.dispose);
  final end = AppEnd(
    keepAll: () => Future.wait([
      ref.read(openEditsProvider).secureForExit(within: appEndWait),
      _keepAlertsStop(ref),
    ]),
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
