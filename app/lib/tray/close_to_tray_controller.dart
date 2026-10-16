import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pool/pool.dart';

import '../platform/platform_wiring.dart';
import '../storage/app_storage.dart';
import 'close_to_tray_store.dart';

final closeToTrayStoreProvider = Provider<CloseToTrayStore>(
  (ref) => CloseToTrayStore(
    File('${ref.watch(appStorageProvider).settingsPath}/tray.json'),
  ),
);

final closeToTrayProvider =
    AsyncNotifierProvider<CloseToTrayController, CloseToTray>(
      CloseToTrayController.new,
    );

/// What closing the window does on this device.
final class CloseToTray {
  const CloseToTray({required this.enabled, required this.trayVisible});

  /// The user's setting: keep running in the tray on close.
  final bool enabled;

  /// Whether a tray shows the app's icon right now.
  final bool trayVisible;

  /// Closing only hides the window. Never without a visible tray icon, or
  /// the app would run on with no way back.
  bool get hidesOnClose => enabled && trayVisible;
}

/// Keeps the app in the system tray on close, as the user's setting says.
/// Inert where the platform has no tray.
class CloseToTrayController extends AsyncNotifier<CloseToTray> {
  /// Changes of the setting, one at a time.
  final _changes = Pool(1);

  @override
  Future<CloseToTray> build() async {
    final tray = ref.watch(systemTrayProvider);
    if (tray == null) {
      return const CloseToTray(enabled: false, trayVisible: false);
    }
    tray.visible.addListener(_apply);
    ref.onDispose(() {
      tray.visible.removeListener(_apply);
      unawaited(tray.hide());
    });
    final enabled = await ref.watch(closeToTrayStoreProvider).load();
    await _showTray(enabled: enabled);
    return _passOn(enabled: enabled);
  }

  /// Takes the setting right away, so the menu shows it; saving it and
  /// showing or hiding the tray follow, one change at a time.
  Future<void> setEnabled({required bool enabled}) {
    if (state.value case final current?) {
      state = AsyncData(
        CloseToTray(enabled: enabled, trayVisible: current.trayVisible),
      );
    }
    return _changes.withResource(() async {
      await ref.read(closeToTrayStoreProvider).save(enabled: enabled);
      await _showTray(enabled: enabled);
      final settled = await _passOn(enabled: enabled);
      if (ref.mounted) state = AsyncData(settled);
    });
  }

  Future<void> _showTray({required bool enabled}) async {
    final tray = ref.read(systemTrayProvider)!;
    final window = ref.read(appWindowProvider);
    if (enabled) {
      await tray.show(
        onOpen: () => unawaited(window.show()),
        onQuit: () => unawaited(window.quit()),
      );
    } else {
      await tray.hide();
    }
  }

  /// Follows the tray coming and going.
  void _apply() {
    if (state.value case final current?) {
      unawaited(
        _passOn(enabled: current.enabled).then((settled) {
          if (ref.mounted) state = AsyncData(settled);
        }),
      );
    }
  }

  /// The current state, passed on to the window.
  Future<CloseToTray> _passOn({required bool enabled}) async {
    final settled = CloseToTray(
      enabled: enabled,
      trayVisible: ref.read(systemTrayProvider)!.visible.value,
    );
    await ref
        .read(appWindowProvider)
        .setHideOnClose(hide: settled.hidesOnClose);
    return settled;
  }
}
