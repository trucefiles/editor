import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../platform/platform_wiring.dart';
import 'close_to_tray_controller.dart';

/// The command-line flag that starts the app in the background, in the
/// tray. The Linux runner reads it too, to keep the window hidden at start
/// (`linux/runner/my_application.cc`).
const backgroundFlag = '--background';

/// Whether the app was started with [backgroundFlag]; set at start.
final startInBackgroundProvider = Provider<bool>((ref) => false);

/// How long a start in the background waits for a tray that is still
/// starting, e.g. at login.
final trayStartWaitProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 10),
);

/// Started in the background, the window stays hidden while the app keeps
/// running in the tray. It shows if the tray setting is off, or if no tray
/// shows the icon in time, so the app never runs out of reach.
final backgroundStartProvider = FutureProvider<void>((ref) async {
  if (!ref.watch(startInBackgroundProvider)) return;
  final setting = await ref.read(closeToTrayProvider.future);
  final tray = ref.read(systemTrayProvider);
  if (setting.enabled &&
      tray != null &&
      await _becomesTrue(tray.visible, ref.read(trayStartWaitProvider))) {
    return;
  }
  await ref.read(appWindowProvider).show();
});

/// Whether [value] is true now or turns true within [wait].
Future<bool> _becomesTrue(ValueListenable<bool> value, Duration wait) async {
  if (value.value) return true;
  final turned = Completer<bool>();
  void follow() {
    if (value.value && !turned.isCompleted) turned.complete(true);
  }

  value.addListener(follow);
  try {
    return await turned.future.timeout(wait, onTimeout: () => false);
  } finally {
    value.removeListener(follow);
  }
}
