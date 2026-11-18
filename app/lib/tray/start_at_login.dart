import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../platform/platform_wiring.dart';
import '../settings/device_settings_controller.dart';
import 'login_start.dart';
import 'start_in_background.dart' show backgroundStartProvider;

/// Starting the app at login, as the user turns it on or off: the desktop
/// is asked first, then the setting is kept. Whether it starts hidden in
/// the tray is the tray setting's own choice, made at the start
/// ([backgroundStartProvider]).
final class StartAtLogin {
  StartAtLogin({required this._desktop, required this._keep});

  final LoginStart _desktop;
  final Future<void> Function({required bool start}) _keep;

  /// Turns it on or off as [start] says; whether the desktop agreed.
  Future<bool> set({required bool start}) async {
    if (!await _desktop.set(start: start)) return false;
    await _keep(start: start);
    return true;
  }
}

/// Starting the app at login; `null` where the app has no tray or the
/// desktop can't start it.
final startAtLoginProvider = Provider<StartAtLogin?>((ref) {
  final desktop = ref.watch(loginStartProvider);
  if (desktop == null || ref.watch(systemTrayProvider) == null) return null;
  return StartAtLogin(
    desktop: desktop,
    keep: ({required start}) => ref
        .read(deviceSettingsProvider.notifier)
        .change((settings) => settings.copyWith(startAtLogin: start)),
  );
});
