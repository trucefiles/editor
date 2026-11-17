import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../platform/platform_wiring.dart';
import '../settings/device_settings_controller.dart';
import 'close_to_tray_controller.dart';
import 'login_start.dart';

/// Starting the app in the tray at login, as the user turns it on or off:
/// the desktop is asked first, then the setting is kept; turning it on
/// keeps the app in the tray on close too.
final class StartAtLogin {
  StartAtLogin({
    required this._desktop,
    required this._keep,
    required this._keepInTray,
  });

  final LoginStart _desktop;
  final Future<void> Function({required bool start}) _keep;
  final Future<void> Function() _keepInTray;

  /// Turns it on or off as [start] says; whether the desktop agreed.
  Future<bool> set({required bool start}) async {
    if (!await _desktop.set(start: start)) return false;
    await _keep(start: start);
    if (start) await _keepInTray();
    return true;
  }
}

/// Starting the app in the tray at login; `null` where the app has no
/// tray or the desktop can't start it.
final startAtLoginProvider = Provider<StartAtLogin?>((ref) {
  final desktop = ref.watch(loginStartProvider);
  if (desktop == null || ref.watch(systemTrayProvider) == null) return null;
  return StartAtLogin(
    desktop: desktop,
    keep: ({required start}) => ref
        .read(deviceSettingsProvider.notifier)
        .change((settings) => settings.copyWith(startAtLogin: start)),
    keepInTray: () =>
        ref.read(closeToTrayProvider.notifier).setEnabled(enabled: true),
  );
});
